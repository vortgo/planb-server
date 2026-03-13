StarterKitClient = StarterKitClient or {}

-- Локальные константы (не зависим от require)
local CRATE_SPRITE = "carpentry_01_16"

-------------------------------------------------
-- Кеш ящиков и мигание
-------------------------------------------------

local knownCrates = {}
local glowTimer = 0

-------------------------------------------------
-- Утилиты
-------------------------------------------------

local function isSupplyCrate(obj)
    if not obj then return false end
    local md = obj:getModData()
    return md and md.StarterKit_Crate == true
end

local function findSupplyCrate(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if isSupplyCrate(obj) then return obj end
        local sq = obj:getSquare()
        if sq then
            for i = 0, sq:getObjects():size() - 1 do
                local sqObj = sq:getObjects():get(i)
                if isSupplyCrate(sqObj) then return sqObj end
            end
        end
    end
    return nil
end

local function getSquareFromObjects(worldobjects)
    for _, obj in ipairs(worldobjects) do
        local sq = obj:getSquare()
        if sq then return sq end
    end
    return nil
end

local function isAdmin(playerObj)
    local level = playerObj:getAccessLevel()
    return level == "Admin" or level == "admin"
end

-------------------------------------------------
-- Мигание золотым для ящиков снабжения
-------------------------------------------------

-- Подсветка — вызывается каждый кадр рендера
local function onRenderTick()
    if #knownCrates == 0 then return end

    glowTimer = glowTimer + 0.05
    if glowTimer > 6.2831 then glowTimer = glowTimer - 6.2831 end

    local alpha = 0.15 + 0.45 * (0.5 + 0.5 * math.sin(glowTimer))

    local i = 1
    while i <= #knownCrates do
        local obj = knownCrates[i]
        if not obj or not obj:getSquare() then
            table.remove(knownCrates, i)
        else
            obj:setHighlighted(true, false)
            obj:setHighlightColor(1.0, 0.85, 0.2, alpha)
            i = i + 1
        end
    end
end

Events.OnRenderTick.Add(onRenderTick)

-- Сканирование — раз в ~секунду ищем ящики рядом с игроком
local scanTimer = 0
local function onTick()
    scanTimer = scanTimer + 1
    if scanTimer < 60 then return end
    scanTimer = 0

    local player = getSpecificPlayer(0)
    if not player then return end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())
    local radius = 20

    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = getCell():getGridSquare(px + dx, py + dy, pz)
            if sq then
                for j = 0, sq:getObjects():size() - 1 do
                    local obj = sq:getObjects():get(j)
                    if isSupplyCrate(obj) then
                        local found = false
                        for _, cached in ipairs(knownCrates) do
                            if cached == obj then found = true; break end
                        end
                        if not found then
                            table.insert(knownCrates, obj)
                        end
                    end
                end
            end
        end
    end
end

Events.OnTick.Add(onTick)

-------------------------------------------------
-- Действия
-------------------------------------------------

local function doPlaceCrate(playerObj, square)
    local cell = getCell()
    if not cell or not square then return end

    local obj = IsoObject.new(cell, square, CRATE_SPRITE)
    obj:getModData().StarterKit_Crate = true
    obj:setName("SupplyCrate")

    square:AddSpecialObject(obj)

    -- Очистить содержимое если спрайт создал контейнер
    local container = obj:getContainer()
    if container then
        container:removeAllItems()
    end

    obj:transmitCompleteItemToServer()

    -- Добавляем в кеш для мигания
    table.insert(knownCrates, obj)
end

local function doRemoveCrate(playerObj, crate)
    local sq = crate:getSquare()
    if sq then
        sq:transmitRemoveItemFromSquare(crate)
    end
end

local function doClaimKit(playerObj, crate)
    sendClientCommand(playerObj, "StarterKit", "claimKit", {})
end

-------------------------------------------------
-- Контекстное меню
-------------------------------------------------

local function onFillWorldObjectContextMenu(playerIndex, context, worldobjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(playerIndex)
    if not playerObj then return end

    local square = getSquareFromObjects(worldobjects)
    if not square then return end

    local crate = findSupplyCrate(worldobjects)

    if crate then
        local claimOpt = context:addOption(
            getText("IGUI_StarterKit_Claim"),
            playerObj, doClaimKit, crate
        )

        if playerObj:getModData().StarterKit_Received then
            claimOpt.notAvailable = true
            local tip = ISWorldObjectContextMenu.addToolTip()
            tip.description = getText("IGUI_StarterKit_AlreadyReceived")
            claimOpt.toolTip = tip
        end

        if isAdmin(playerObj) then
            context:addOption(
                getText("IGUI_StarterKit_Remove"),
                playerObj, doRemoveCrate, crate
            )
        end
    else
        if isAdmin(playerObj) then
            context:addOption(
                getText("IGUI_StarterKit_Place"),
                playerObj, doPlaceCrate, square
            )
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-------------------------------------------------
-- Ответы от сервера
-------------------------------------------------

local function onServerCommand(module, command, args)
    if module ~= "StarterKit" then return end

    local playerObj = getSpecificPlayer(0)
    if not playerObj then return end

    if command == "kitGranted" then
        playerObj:getModData().StarterKit_Received = true
        playerObj:Say(getText("IGUI_StarterKit_Received"))

    elseif command == "kitDenied" then
        if args.reason == "Cooldown" then
            playerObj:Say(getText("IGUI_StarterKit_Cooldown", tostring(args.extra or "?")))
        else
            playerObj:Say(getText("IGUI_StarterKit_AlreadyReceived"))
        end

    elseif command == "kitReset" then
        playerObj:getModData().StarterKit_Received = nil
        print("[StarterKit] Your kit has been reset")

    elseif command == "resetDone" then
        print("[StarterKit] Kit reset: " .. tostring(args.target))

    elseif command == "resetFail" then
        print("[StarterKit] Player not found: " .. tostring(args.target))
    end
end

Events.OnServerCommand.Add(onServerCommand)

-------------------------------------------------
-- Чат-команды: /resetkit, /radio
-------------------------------------------------

local function hookChat()
    local chat = ISChat.instance
    if not chat or not chat.textEntry then return end

    local origFn = chat.textEntry.onCommandEntered
    local function hookedOnCommandEntered(self)
        local text = chat.textEntry:getText()
        if not text then return origFn(self) end

        local target = text:match("^/resetkit%s+(%S+)")
        if target then
            local playerObj = getSpecificPlayer(0)
            if playerObj and isAdmin(playerObj) then
                sendClientCommand(playerObj, "StarterKit", "resetKit", { target = target })
            end
            chat.textEntry:setText("")
            chat:unfocus()
            return
        end

        local freq, msg = text:match("^/radio%s+([%d%.]+)%s+(.+)")
        if freq and msg then
            local playerObj = getSpecificPlayer(0)
            if playerObj and isAdmin(playerObj) then
                sendClientCommand(playerObj, "SafeZoneRadio", "broadcast", {
                    freq = freq,
                    text = msg,
                })
            end
            chat.textEntry:setText("")
            chat:unfocus()
            return
        end

        origFn(self)
    end

    chat.textEntry.onCommandEntered = hookedOnCommandEntered
end

Events.OnGameStart.Add(hookChat)
