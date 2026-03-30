if not isServer() then return end

StarterKitServer = StarterKitServer or {}

-- Состав набора (правильные ID для B42)
local KIT_ITEMS = {
    { item = "Base.Bag_Schoolbag",       count = 1 },
    { item = "Base.BeerBottle",       count = 1 },
    { item = "Base.BaseballBat_Crafted",       count = 1 },
    { item = "Base.Apple",       count = 2 },
    { item = "Base.Lighter",       count = 1 },
    { item = "Base.Hammer",              count = 1, container = "bag" },
    { item = "Base.Saw",              count = 1, container = "bag" },
    { item = "Base.TinnedBeans",         count = 2, container = "bag" },
    { item = "Base.HuntingKnife",        count = 1, container = "bag" },
    { item = "Base.Trousers_CamoGreen",  count = 1 },
    { item = "Base.Tshirt_CamoGreen",    count = 1 },
    { item = "Base.Hat_Army",            count = 1 },
}

local COOLDOWN_HOURS = 24

local function getClaimsData()
    local modData = getGameTime():getModData()
    if not modData.StarterKit_Claims then
        modData.StarterKit_Claims = {}
    end
    return modData.StarterKit_Claims
end

local function canClaimKit(player)
    -- Server-side cooldown only — don't trust client ModData
    local steamID = tostring(player:getSteamID())
    local claims = getClaimsData()
    local lastClaim = claims[steamID]

    if lastClaim then
        local elapsed = os.time() - lastClaim
        local cooldownSec = COOLDOWN_HOURS * 3600
        if elapsed < cooldownSec then
            local remainingHours = math.ceil((cooldownSec - elapsed) / 3600)
            return false, "Cooldown", remainingHours
        end
    end

    return true
end

local function giveKit(player)
    local inv = player:getInventory()
    local bag = nil

    for _, entry in ipairs(KIT_ITEMS) do
        for i = 1, (entry.count or 1) do
            local targetInv = inv
            if entry.container == "bag" and bag then
                local bagInv = bag:getInventory()
                if bagInv then
                    targetInv = bagInv
                end
            end

            local item = targetInv:AddItem(entry.item)

            if item then
                -- Синхронизировать предмет клиенту
                sendAddItemToContainer(targetInv, item)

                if not bag and instanceof(item, "InventoryContainer") then
                    bag = item
                end
            end
        end
    end

    player:getModData().StarterKit_Received = true

    local steamID = tostring(player:getSteamID())
    local claims = getClaimsData()
    claims[steamID] = os.time()
end

-------------------------------------------------
-- Консольная команда: StarterKitServer.resetKit("ник")
-------------------------------------------------

function StarterKitServer.resetKit(username)
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p:getUsername():lower() == username:lower() then
            p:getModData().StarterKit_Received = nil

            local steamID = tostring(p:getSteamID())
            local claims = getClaimsData()
            claims[steamID] = nil

            -- Уведомить клиент игрока сбросить локальный ModData
            sendServerCommand(p, "StarterKit", "kitReset", {})

            print("[StarterKit] Reset kit for " .. username .. " (SteamID: " .. steamID .. ")")
            return true
        end
    end
    print("[StarterKit] Player not found: " .. username)
    return false
end

-------------------------------------------------
-- Обработка команд от клиента
-------------------------------------------------

local function onClientCommand(module, command, player, args)
    if module ~= "StarterKit" then return end

    if command == "claimKit" then
        local ok, reason, extra = canClaimKit(player)
        if ok then
            giveKit(player)
            sendServerCommand(player, "StarterKit", "kitGranted", {})
        else
            sendServerCommand(player, "StarterKit", "kitDenied", {
                reason = reason or "Denied",
                extra  = extra,
            })
        end

    elseif command == "resetKit" then
        local level = player:getAccessLevel()
        if level ~= "Admin" and level ~= "admin" then
            print("[StarterKit] WARN: non-admin " .. player:getUsername() .. " attempted resetKit")
            return
        end

        local targetName = args and args.target
        if not targetName then return end

        local ok = StarterKitServer.resetKit(targetName)
        if ok then
            sendServerCommand(player, "StarterKit", "resetDone", { target = targetName })
        else
            sendServerCommand(player, "StarterKit", "resetFail", { target = targetName })
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
