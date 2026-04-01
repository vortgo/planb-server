if not isServer() then return end

-- =========================================================================
-- Audit Log — server-side logging of player actions (map/item changes)
--
-- Fixes Build 42 bug where map/item logs are not created because
-- GameServer.RemoveItemFromMap() passes null connection to
-- RemoveItemFromSquarePacket.removeItemFromMap(), skipping all logging.
--
-- Uses Lua events + action hooks to log with player attribution.
-- Writes to ~/Zomboid/Logs/ via LoggerManager (standard PZ log rotation).
-- =========================================================================

local LOG_MAP = "sz_map"
local LOG_ITEM = "sz_item"

local function getLogger(name)
    return LoggerManager.getLogger(name)
end

local function ts()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function coords(x, y, z)
    return math.floor(x) .. "," .. math.floor(y) .. "," .. math.floor(z)
end

local function playerStr(player)
    if not player then return "unknown" end
    local name = player:getUsername() or "?"
    local steamID = player:getSteamID() and tostring(player:getSteamID()) or ""
    if steamID ~= "" then
        return steamID .. ' "' .. name .. '"'
    end
    return '"' .. name .. '"'
end

local function logMap(msg)
    getLogger(LOG_MAP):write(msg)
end

local function logItem(msg)
    getLogger(LOG_ITEM):write(msg)
end

-- =========================================================================
-- 1. OnProcessTransaction — catches drops, moveable pick/place/scrap
-- =========================================================================
-- Params: action(string), player(IsoPlayer), item(InventoryItem|nil),
--         sourceId(ContainerID), destId(ContainerID), extra(KahluaTable|nil)

local function onProcessTransaction(action, player, item, sourceId, destId, extra)
    local who = playerStr(player)
    local px, py, pz = 0, 0, 0
    if player then
        px, py, pz = player:getX(), player:getY(), player:getZ()
    end
    local pos = coords(px, py, pz)

    if action == "dropOnFloor" then
        local itemType = item and item:getFullType() or "?"
        local sq = extra and extra.square
        local dropPos = pos
        if sq then
            dropPos = coords(sq:getX(), sq:getY(), sq:getZ())
        end
        logItem(who .. " drop " .. dropPos .. " [" .. itemType .. "]")

    elseif action == "pickUpMoveable" then
        local srcX, srcY, srcZ = 0, 0, 0
        if sourceId and sourceId.getObject and sourceId:getObject() then
            local obj = sourceId:getObject()
            srcX, srcY, srcZ = obj:getX(), obj:getY(), obj:getZ()
        end
        logMap(who .. " pickup_moveable " .. coords(srcX, srcY, srcZ))

    elseif action == "placeMoveable" then
        local dstX, dstY, dstZ = 0, 0, 0
        if destId and destId.getObject and destId:getObject() then
            local obj = destId:getObject()
            dstX, dstY, dstZ = obj:getX(), obj:getY(), obj:getZ()
        end
        local dir = extra and extra.direction or "?"
        logMap(who .. " place_moveable " .. coords(dstX, dstY, dstZ) .. " dir=" .. tostring(dir))

    elseif action == "scrapMoveable" then
        logMap(who .. " scrap_moveable @ " .. pos)

    elseif action == "rotateMoveable" then
        -- low importance, skip logging
    end
end

Events.OnProcessTransaction.Add(onProcessTransaction)

-- =========================================================================
-- 2. ISDestroyStuffAction hook — sledgehammer with player attribution
-- =========================================================================
-- ISDestroyStuffAction:complete() is called server-side via NetTimedAction.
-- We wrap it to log BEFORE the object is destroyed.

local _origDestroyComplete

local function hookDestroyAction()
    if not ISDestroyStuffAction then return end
    if _origDestroyComplete then return end

    _origDestroyComplete = ISDestroyStuffAction.complete

    ISDestroyStuffAction.complete = function(self)
        -- log before destruction
        local player = self.character
        local obj = self.item
        if player and obj and obj:getSquare() then
            local who = playerStr(player)
            local sq = obj:getSquare()
            local pos = coords(sq:getX(), sq:getY(), sq:getZ())
            local name = obj:getName() or obj:getObjectName() or "?"
            local sprite = ""
            if obj:getSprite() and obj:getSprite():getName() then
                sprite = " (" .. obj:getSprite():getName() .. ")"
            end
            logMap(who .. " sledgehammer " .. name .. sprite .. " at " .. pos)
        end

        return _origDestroyComplete(self)
    end

    print("[AuditLog] Hooked ISDestroyStuffAction:complete()")
end

-- =========================================================================
-- 3. OnObjectAboutToBeRemoved — fallback for non-sledgehammer destruction
-- =========================================================================
-- No player info, but logs the object and coords for correlation.

local function onObjectAboutToBeRemoved(obj)
    if not obj or not obj:getSquare() then return end
    -- skip world items (IsoWorldInventoryObject) — too noisy
    if instanceof(obj, "IsoWorldInventoryObject") then return end

    local sq = obj:getSquare()
    local pos = coords(sq:getX(), sq:getY(), sq:getZ())
    local name = obj:getName() or obj:getObjectName() or "?"
    local sprite = ""
    if obj:getSprite() and obj:getSprite():getName() then
        sprite = " (" .. obj:getSprite():getName() .. ")"
    end

    -- try to find nearest player for attribution
    local nearestPlayer = nil
    local nearestDist = 5 -- max 5 tiles away
    local players = getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do
            local p = players:get(i)
            if p then
                local dx = math.abs(p:getX() - sq:getX())
                local dy = math.abs(p:getY() - sq:getY())
                local dist = math.max(dx, dy)
                if dist < nearestDist then
                    nearestDist = dist
                    nearestPlayer = p
                end
            end
        end
    end

    local who = nearestPlayer and playerStr(nearestPlayer) or "\"unknown\""
    logMap(who .. " destroyed " .. name .. sprite .. " at " .. pos)
end

Events.OnObjectAboutToBeRemoved.Add(onObjectAboutToBeRemoved)

-- =========================================================================
-- 4. Player hit object (thump) — doors, windows, barricades
-- =========================================================================
-- WeaponHit events go through PlayerHitObjectPacket which does log,
-- but only when objectIndex == -1 (fully destroyed). We add logging
-- for all hits to track who is attacking what.

local function onWeaponHitXp(player, weapon, hitObject, damage, hitCount)
    if not player or not hitObject then return end
    if not hitObject:getSquare() then return end
    -- only log hits on thumpable objects (doors, walls, windows, barricades)
    if not (instanceof(hitObject, "IsoThumpable") or instanceof(hitObject, "IsoDoor")
        or instanceof(hitObject, "IsoWindow") or instanceof(hitObject, "IsoBarricade")) then
        return
    end

    local who = playerStr(player)
    local sq = hitObject:getSquare()
    local pos = coords(sq:getX(), sq:getY(), sq:getZ())
    local name = hitObject:getName() or hitObject:getObjectName() or "?"
    local weaponName = weapon and weapon:getName() or "?"
    local dmg = damage and string.format("%.1f", damage) or "?"

    logMap(who .. " hit " .. name .. " with " .. weaponName .. " dmg=" .. dmg .. " at " .. pos)
end

Events.OnWeaponHitXp.Add(onWeaponHitXp)

-- =========================================================================
-- 5. Player death — log with coords and killer info
-- =========================================================================

local function onPlayerDeath(player)
    if not player then return end
    local who = playerStr(player)
    local pos = coords(player:getX(), player:getY(), player:getZ())
    logItem(who .. " died at " .. pos)
end

Events.OnPlayerDeath.Add(onPlayerDeath)

-- =========================================================================
-- Init — hook timed actions after they're loaded
-- =========================================================================

local hooked = false
local function tryHook()
    if hooked then return end
    if ISDestroyStuffAction then
        hookDestroyAction()
        hooked = true
    end
end

Events.OnGameStart.Add(tryHook)
Events.OnTick.Add(function()
    if not hooked then tryHook() end
end)

print("[AuditLog] Audit logging module loaded")
print("[AuditLog] Logs: " .. LOG_MAP .. ", " .. LOG_ITEM)
