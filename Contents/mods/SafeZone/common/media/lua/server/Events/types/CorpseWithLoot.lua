local function log(msg)
    print("[CorpseWithLoot] " .. tostring(msg))
end

local CorpseWithLoot = {}

--- Спавн: труп с лутом + зомби-охранники
function CorpseWithLoot.spawn(x, y, z, eventId)
    local sq = EventUtils.findSafeSquare(x, y, z, EventConfig.SAFE_SQUARE_RADIUS)
    if not sq then
        return nil, "No safe square found"
    end

    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()

    -- Выбираем аутфит
    local outfits = EventConfig.Corpse.outfits
    local outfit = outfits[ZombRand(#outfits) + 1]
    local isFemale = ZombRand(1000) < EventConfig.Corpse.femaleChance * 1000

    local count = 0

    -- Спавним одетого зомби с лутом, через 3 сек Kill
    local ok, err = pcall(function()
        local zombies = addZombiesInOutfit(cx, cy, cz, 1, outfit, 0)
        if not zombies or zombies:size() == 0 then
            log("addZombiesInOutfit returned no zombies")
            return
        end
        local zombie = zombies:get(0)
        zombie:getModData().SZEventId = eventId

        -- Лут в инвентарь зомби — при смерти перейдёт в труп
        local lootTable = EventConfig.Loot["corpswithloot"]
        if lootTable then
            local inv = zombie:getInventory()
            for _, entry in ipairs(lootTable) do
                if ZombRand(1000) < entry.chance * 1000 then
                    local qty = ZombRand(entry.min, entry.max + 1)
                    for _ = 1, qty do
                        local item = inv:AddItem(entry.item)
                        if item then
                            item:getModData().SZEventId = eventId
                            count = count + 1
                        end
                    end
                end
            end
            if count == 0 then
                local fallback = lootTable[ZombRand(#lootTable) + 1]
                local item = inv:AddItem(fallback.item)
                if item then
                    item:getModData().SZEventId = eventId
                    count = 1
                end
            end
        end
        log("CHECKPOINT 1: Zombie spawned, outfit=" .. outfit .. ", loot=" .. count)

        -- Через ~3 секунды убиваем (все 3 способа — рабочая комбинация)
        local tickCount = 0
        local function waitAndKill()
            tickCount = tickCount + 1
            if tickCount < 180 then return end
            Events.OnTick.Remove(waitAndKill)
            if zombie then
                zombie:setHealth(0)
                pcall(function()
                    zombie:Kill(getCell():getFakeZombieForHit())
                end)
                pcall(function()
                    zombie:setAttackedBy(getCell():getFakeZombieForHit())
                    zombie:becomeCorpse()
                end)
                pcall(function()
                    zombie:knockDown(true)
                end)
                log("CHECKPOINT 2: Zombie kill attempted (3 methods)")
            end
        end
        Events.OnTick.Add(waitAndKill)
    end)
    if not ok then
        log("Corpse creation failed: " .. tostring(err))
    end

    return {
        x = cx,
        y = cy,
        z = cz,
        itemCount = count,
    }
end

--- Cleanup: удаляем труп и предметы по eventId
function CorpseWithLoot.cleanup(spawnData, eventId)
    if not spawnData then return end
    -- Удаляем трупы
    local cell = getCell()
    local radius = 5
    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = cell:getGridSquare(spawnData.x + dx, spawnData.y + dy, spawnData.z or 0)
            if sq then
                local bodies = sq:getDeadBodys()
                if bodies then
                    for i = bodies:size() - 1, 0, -1 do
                        local body = bodies:get(i)
                        if body and body:getModData().SZEventId == eventId then
                            sq:removeCorpse(body, false)
                            log("Removed corpse for eventId=" .. eventId)
                        end
                    end
                end
            end
        end
    end
    -- Удаляем предметы на земле (fallback)
    EventUtils.cleanupByEventId(
        spawnData.x, spawnData.y, spawnData.z,
        eventId,
        { radius = 3, removeItems = true, removeObjects = false }
    )
end

--- Описание
function CorpseWithLoot.getDescription(x, y, z)
    return "Body found near " .. x .. ", " .. y
end

-- ---------------------------------------------------------------------------
-- Регистрация
-- ---------------------------------------------------------------------------
EventRegistry.register("corpswithloot", CorpseWithLoot)
