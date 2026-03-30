local function log(msg)
    print("[EventCmdClient] " .. tostring(msg))
end

local function isAdmin(playerObj)
    local level = playerObj:getAccessLevel()
    return level == "Admin" or level == "admin"
end

-- ---------------------------------------------------------------------------
-- Маркеры на карте (SafeZone events)
-- ---------------------------------------------------------------------------

local SZMarkers = {}
SZMarkers.pendingEvents = {}   -- {id -> {id, type, x, y}} — события, о которых узнали от сервера
SZMarkers.activeMarkers = {}   -- {id -> {icon, zone}} — маркеры на карте (только если игрок слышал радио)
SZMarkers.MARKER_RADIUS = 50
SZMarkers.MARKER_R = 0.2
SZMarkers.MARKER_G = 0.8
SZMarkers.MARKER_B = 0.2
SZMarkers.MARKER_A = 0.6

--- Запомнить событие от сервера (маркер НЕ ставим, ждём радио)
function SZMarkers.addPending(id, typeName, x, y)
    SZMarkers.pendingEvents[id] = { id = id, type = typeName, x = x, y = y }
    log("Pending event #" .. id .. " (" .. typeName .. ") at " .. x .. "," .. y)
end

--- Удалить маркер и pending
function SZMarkers.removeEvent(id)
    SZMarkers.pendingEvents[id] = nil
    local marker = SZMarkers.activeMarkers[id]
    if marker then
        -- Удаляем зону через API если карта открыта
        if marker.zone then
            local worldMap = _G.ISWorldMap_instance or (ISWorldMap and ISWorldMap.instance) or nil
            if worldMap and worldMap.mapAPI then
                local markersAPI = worldMap.mapAPI.getMarkersAPI and worldMap.mapAPI:getMarkersAPI() or nil
                if markersAPI then
                    pcall(function() markersAPI:removeMarker(marker.zone) end)
                end
            end
        end
        SZMarkers.activeMarkers[id] = nil
        SZMarkers.zonesCreated = false  -- пересоздадим при следующем открытии карты
        log("Marker removed for event #" .. id)
    end
end

--- Создать маркер для события (вызывается когда игрок услышал радио)
function SZMarkers.activateMarker(id)
    if SZMarkers.activeMarkers[id] then return end
    local ev = SZMarkers.pendingEvents[id]
    if not ev then return end
    SZMarkers.activeMarkers[id] = { x = ev.x, y = ev.y, type = ev.type }
    log("Marker activated for event #" .. id .. " at " .. ev.x .. "," .. ev.y)
end

--- Перерисовать все маркеры на карте
SZMarkers.zonesCreated = false

function SZMarkers.renderMarkers()
    local worldMap = _G.ISWorldMap_instance or (ISWorldMap and ISWorldMap.instance) or nil
    if not worldMap or not worldMap.isVisible or not worldMap:isVisible() then return end

    local mapAPI = worldMap.mapAPI
    if not mapAPI then return end

    if mapAPI.getBoolean and mapAPI.setBoolean then
        if not mapAPI:getBoolean("Symbols") then
            mapAPI:setBoolean("Symbols", true)
        end
    end

    local markersAPI = mapAPI.getMarkersAPI and mapAPI:getMarkersAPI() or nil
    if not markersAPI then return end

    if SZMarkers.zonesCreated then return end

    local count = 0
    for id, data in pairs(SZMarkers.activeMarkers) do
        if not data.zone then
            local zone = markersAPI:addGridSquareMarker(
                math.floor(data.x), math.floor(data.y),
                SZMarkers.MARKER_RADIUS,
                SZMarkers.MARKER_R, SZMarkers.MARKER_G, SZMarkers.MARKER_B, SZMarkers.MARKER_A
            )
            if zone then
                data.zone = zone
                count = count + 1
            end
        end
    end

    if count > 0 then
        SZMarkers.zonesCreated = true
        log("Created " .. count .. " map zones")
    end
end

--- Очистить все маркеры SafeZone (при входе в игру)
function SZMarkers.clearAll()
    SZMarkers.pendingEvents = {}
    SZMarkers.activeMarkers = {}
    SZMarkers.zonesCreated = false
    log("All markers cleared")
end

-- ---------------------------------------------------------------------------
-- Патч ISWorldMap: перерисовка маркеров при открытии карты
-- ---------------------------------------------------------------------------

local function patchWorldMap()
    if SZMarkers._showWorldMapPatched then return end
    if not ISWorldMap or not ISWorldMap.ShowWorldMap then return end

    local orig = ISWorldMap.ShowWorldMap
    ISWorldMap.ShowWorldMap = function(playerNum, centerX, centerY, zoom)
        orig(playerNum, centerX, centerY, zoom)
        SZMarkers.zonesCreated = false  -- пересоздаём маркеры при каждом открытии
        SZMarkers.renderMarkers()
    end
    SZMarkers._showWorldMapPatched = true
    log("ISWorldMap patched for markers")
end

-- ---------------------------------------------------------------------------
-- Events.OnDeviceText: игрок слышит радио → ищем координаты → активируем маркер
-- ---------------------------------------------------------------------------

local function onDeviceText(_guid, _interactCodes, _x, _y, _z, _line)
    if not _line or type(_line) ~= "string" then return end

    -- Ищем координаты в тексте радио: "число, число" или "число,число"
    for coordX, coordY in _line:gmatch("(%d+),%s*(%d+)") do
        local cx = tonumber(coordX)
        local cy = tonumber(coordY)
        if cx and cy then
            -- Сопоставляем с pending-событиями
            for id, ev in pairs(SZMarkers.pendingEvents) do
                if ev.x == cx and ev.y == cy and not SZMarkers.activeMarkers[id] then
                    SZMarkers.activateMarker(id)
                    SZMarkers.zonesCreated = false
                end
            end
        end
    end
end

-- Подписка перенесена в onGameStart (Events.OnDeviceText может не существовать при загрузке)

-- ---------------------------------------------------------------------------
-- Обработка ответов от сервера
-- ---------------------------------------------------------------------------

local function onServerCommand(module, command, args)
    if module ~= "SafeZoneEvents" then return end

    if command == "result" then
        log(tostring(args.text))

    elseif command == "eventNotify" then
        -- Сервер сообщает о новом событии
        SZMarkers.addPending(args.id, args.type, args.x, args.y)

    elseif command == "eventRemoved" then
        -- Сервер удалил событие — убираем маркер
        SZMarkers.removeEvent(args.id)
    end
end

Events.OnServerCommand.Add(onServerCommand)

-- ---------------------------------------------------------------------------
-- Парсинг команды /event
-- ---------------------------------------------------------------------------

local function parseEventCommand(text)
    -- /event spawn <type> [x y]
    -- /event list
    -- /event remove <id>
    -- /event removeall
    -- /event types

    local parts = {}
    for token in text:gmatch("%S+") do
        table.insert(parts, token)
    end

    -- parts[1] = "/event"
    if #parts < 2 then return nil end

    local sub = parts[2]:lower()

    if sub == "spawn" then
        if #parts < 3 then
            return nil, "Usage: /event spawn <type> [x y]"
        end
        local cmd = { command = "spawn", type = parts[3] }
        if parts[4] and parts[5] then
            cmd.x = parts[4]
            cmd.y = parts[5]
        end
        return cmd

    elseif sub == "list" then
        return { command = "list" }

    elseif sub == "remove" then
        if #parts < 3 then
            return nil, "Usage: /event remove <id>"
        end
        return { command = "remove", id = parts[3] }

    elseif sub == "removeall" then
        return { command = "removeall" }

    elseif sub == "types" then
        return { command = "types" }
    end

    return nil, "Unknown subcommand: " .. sub
        .. ". Available: spawn, list, remove, removeall, types"
end

-- ---------------------------------------------------------------------------
-- Хук чата: цепочка с существующим хуком
-- ---------------------------------------------------------------------------

local function hookChat()
    local chat = ISChat.instance
    if not chat or not chat.textEntry then return end

    -- Сохраняем предыдущий хук (может быть от StarterKitClient)
    local previousFn = chat.textEntry.onCommandEntered

    local function hookedOnCommandEntered(self)
        local text = chat.textEntry:getText()
        if not text then return previousFn(self) end

        -- Проверяем /event
        if text:match("^/event%s") or text == "/event" then
            local playerObj = getSpecificPlayer(0)

            if not playerObj or not isAdmin(playerObj) then
                log("Admin access required")
                chat.textEntry:setText("")
                chat:unfocus()
                return
            end

            local cmd, err = parseEventCommand(text)
            if cmd then
                sendClientCommand(playerObj, "SafeZoneEvents", cmd.command, cmd)
            else
                log(err or "Usage: /event <spawn|list|remove|removeall|types>")
            end

            chat.textEntry:setText("")
            chat:unfocus()
            return
        end

        -- Передаём в предыдущий хук
        return previousFn(self)
    end

    chat.textEntry.onCommandEntered = hookedOnCommandEntered
    log("Chat hook installed")
end

-- ---------------------------------------------------------------------------
-- Инициализация при старте игры
-- ---------------------------------------------------------------------------

local function onGameStart()
    -- Очищаем маркеры от прошлой сессии
    SZMarkers.clearAll()

    -- Хук чата
    hookChat()

    -- Патч карты
    patchWorldMap()

    -- Подписка на радио-текст (Events.OnDeviceText может не существовать при первичной загрузке lua)
    if Events.OnDeviceText then
        Events.OnDeviceText.Add(onDeviceText)
        log("OnDeviceText hook installed")
    else
        log("WARN: Events.OnDeviceText not available")
    end
end

Events.OnGameStart.Add(onGameStart)
local SZ_VERSION = "0.4.3"
log("EventCommandsClient v" .. SZ_VERSION .. " loaded")
