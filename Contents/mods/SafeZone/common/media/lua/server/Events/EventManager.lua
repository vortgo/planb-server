EventManager = EventManager or {}

-- Состояния события
EventManager.STATE_PENDING         = "pending"          -- запланировано, чанк не загружен, в мире ничего нет
EventManager.STATE_SPAWNED         = "spawned"          -- объекты созданы в мире, игрок не подходил
EventManager.STATE_VISITED         = "visited"          -- игрок подошёл, ждём TTL для cleanup
EventManager.STATE_PENDING_CLEANUP = "pending_cleanup"  -- TTL истёк, но чанк выгружен — ждём загрузки

local function log(msg)
    print("[EventManager] " .. tostring(msg))
end

-- ---------------------------------------------------------------------------
-- Хранилище: getGameTime():getModData()["SafeZone_Events"]
-- ---------------------------------------------------------------------------

local function getStorage()
    local modData = getGameTime():getModData()
    if not modData["SafeZone_Events"] then
        modData["SafeZone_Events"] = { events = {}, nextId = 1 }
    end
    return modData["SafeZone_Events"]
end

-- ---------------------------------------------------------------------------
-- Проверка: загружен ли чанк с координатами события
-- ---------------------------------------------------------------------------

local function isChunkLoaded(x, y, z)
    return getCell():getGridSquare(x, y, z or 0) ~= nil
end

-- ---------------------------------------------------------------------------
-- Радио-сообщения из файла Zomboid/Lua/SafeZone_event_messages.txt
-- Формат: секции [typename], по одному сообщению на строку
-- Плейсхолдеры: {x}, {y}
-- ---------------------------------------------------------------------------

EventManager.eventMessages = {}

local function loadEventMessages()
    local fileName = EventConfig.EVENT_MESSAGES_FILE
    local reader = getFileReader(fileName, true)
    if not reader then
        log("Event messages file not found: " .. fileName)
        return
    end

    EventManager.eventMessages = {}
    local currentType = nil
    local line = reader:readLine()
    while line do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            local section = line:match("^%[(.+)%]$")
            if section then
                currentType = section:lower()
                EventManager.eventMessages[currentType] = EventManager.eventMessages[currentType] or {}
            elseif currentType then
                table.insert(EventManager.eventMessages[currentType], line)
            end
        end
        line = reader:readLine()
    end
    reader:close()

    local total = 0
    for typeName, msgs in pairs(EventManager.eventMessages) do
        total = total + #msgs
        log("Loaded " .. #msgs .. " radio messages for [" .. typeName .. "]")
    end
    log("Total event radio messages: " .. total)
end

-- ---------------------------------------------------------------------------
-- Уведомления: лог + радио
-- ---------------------------------------------------------------------------

function EventManager.notify(message, eventData)
    log(message)

    if not eventData or not eventData.type then return end

    local msgs = EventManager.eventMessages[eventData.type]
    if not msgs or #msgs == 0 then return end

    local channel = DynamicRadio and DynamicRadio.cache
        and DynamicRadio.cache[SafeZoneRadio.channelUUID]
    if not channel then
        log("Radio channel not available, skipping broadcast")
        return
    end

    local msg = msgs[ZombRand(#msgs) + 1]
    msg = msg:gsub("{x}", tostring(eventData.x or "???"))
    msg = msg:gsub("{y}", tostring(eventData.y or "???"))

    local bc = RadioBroadCast.new("SZ-EVT-" .. tostring(ZombRand(100000, 999999)), -1, -1)
    bc:AddRadioLine(RadioLine.new("<bzzt>", 0.5, 0.5, 0.5))
    bc:AddRadioLine(RadioLine.new(msg, 1.0, 0.8, 0.2))
    bc:AddRadioLine(RadioLine.new("<fzzt>", 0.5, 0.5, 0.5))
    channel:setAiringBroadcast(bc)

    log("Radio broadcast sent for event #" .. (eventData.id or "?"))
end

-- ---------------------------------------------------------------------------
-- Попытка инициализации pending-события (спавн объектов в мире)
-- ---------------------------------------------------------------------------

local function tryInitialize(event)
    local handler = EventRegistry.get(event.type)
    if not handler then return false end

    if not isChunkLoaded(event.x, event.y, event.z) then return false end

    -- Валидация
    if handler.validate then
        local valid, err = handler.validate(event.x, event.y, event.z)
        if not valid then
            log("Init validation failed for #" .. event.id .. ": " .. tostring(err))
            return false, err
        end
    end

    -- Спавн
    local spawnData, spawnErr = handler.spawn(event.x, event.y, event.z, event.id)
    if not spawnData then
        log("Init spawn failed for #" .. event.id .. ": " .. tostring(spawnErr))
        return false, spawnErr
    end

    event.state = EventManager.STATE_SPAWNED
    event.spawnData = spawnData

    local origX, origY = event.x, event.y
    event.x = spawnData.x or event.x
    event.y = spawnData.y or event.y
    event.z = spawnData.z or event.z

    local dist = math.floor(EventUtils.distance(origX, origY, event.x, event.y))
    log("Event #" .. event.id .. " spawned: origin=" .. origX .. "," .. origY
        .. " loot=" .. event.x .. "," .. event.y .. "," .. event.z
        .. " dist=" .. dist)

    return true
end

-- ---------------------------------------------------------------------------
-- Cleanup: удаляем всё что наспавнили
-- Возвращает true если cleanup выполнен, false если отложен
-- force=true пропускает проверку игроков (для /event remove)
-- ---------------------------------------------------------------------------

local CLEANUP_RADIUS = 20

local function doCleanup(event, force)
    -- pending — в мире ничего нет, всегда успех
    if event.state == EventManager.STATE_PENDING then return true end

    -- Чанк не загружен — cleanup невозможен
    if not isChunkLoaded(event.x, event.y, event.z) then return false end

    -- Игрок рядом — откладываем (не удаляем на глазах)
    if not force and EventUtils.isPlayerNearby(event.x, event.y, CLEANUP_RADIUS) then
        return false
    end

    local handler = EventRegistry.get(event.type)
    if not handler then return true end

    if handler.cleanup then
        local ok, err = pcall(handler.cleanup, event.spawnData, event.id)
        if not ok then
            log("Cleanup error for #" .. event.id .. ": " .. tostring(err))
        end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Spawn: регистрация события в планировщике
-- ---------------------------------------------------------------------------

function EventManager.spawn(typeName, x, y, z, source)
    local handler = EventRegistry.get(typeName)
    if not handler then
        log("Unknown event type: " .. tostring(typeName))
        return nil, "Unknown event type: " .. tostring(typeName)
    end

    z = z or 0
    source = source or "manual"

    -- Проверка сейфхауса
    if EventUtils.isInSafehouse(x, y, EventConfig.BUILDING_SEARCH_RADIUS) then
        log("Event blocked: location " .. x .. "," .. y .. " is inside a safehouse")
        return nil, "Location is inside a safehouse"
    end

    -- Регистрация в планировщике
    local storage = getStorage()
    local id = storage.nextId
    storage.nextId = id + 1

    local event = {
        id = id,
        type = typeName:lower(),
        x = x,
        y = y,
        z = z,
        spawnTime = os.time(),
        state = EventManager.STATE_PENDING,
        source = source,
        spawnData = nil,
    }

    table.insert(storage.events, event)

    log("Event #" .. id .. " (" .. typeName .. ") created at origin=" .. x .. "," .. y)

    -- Радио-уведомление сразу при создании
    EventManager.notify("Event #" .. id .. " created", event)

    -- Пробуем сразу инициализировать
    local ok, err = tryInitialize(event)
    if not ok and err then
        -- Валидация или спавн провалились — удаляем из планировщика
        table.remove(storage.events, #storage.events)
        return nil, err
    end

    if event.state == EventManager.STATE_PENDING then
        log("Event #" .. id .. " (" .. typeName .. ") scheduled at " .. x .. "," .. y .. " (chunk not loaded)")
    end

    return event, nil
end

-- ---------------------------------------------------------------------------
-- Удаление события по ID
-- ---------------------------------------------------------------------------

function EventManager.remove(eventId, force)
    local storage = getStorage()
    for i, event in ipairs(storage.events) do
        if event.id == eventId then
            local cleaned = doCleanup(event, force)
            if not cleaned then
                event.state = EventManager.STATE_PENDING_CLEANUP
                log("Event #" .. eventId .. ": cleanup deferred (chunk/player)")
                return false, "Cleanup deferred"
            end

            table.remove(storage.events, i)
            log("Removed event #" .. eventId .. " (was " .. event.state .. ")")
            return true
        end
    end

    log("Event #" .. eventId .. " not found")
    return false, "Event not found"
end

-- ---------------------------------------------------------------------------
-- Удалить все события
-- ---------------------------------------------------------------------------

function EventManager.removeAll(force)
    local storage = getStorage()
    local count = #storage.events
    local deferred = 0

    for i = count, 1, -1 do
        local event = storage.events[i]
        local cleaned = doCleanup(event, force)
        if cleaned then
            table.remove(storage.events, i)
        else
            event.state = EventManager.STATE_PENDING_CLEANUP
            deferred = deferred + 1
        end
    end

    local removed = count - deferred
    log("Removed " .. removed .. " events" .. (deferred > 0 and (", " .. deferred .. " deferred") or ""))
    return removed, deferred
end

-- ---------------------------------------------------------------------------
-- Список активных событий
-- ---------------------------------------------------------------------------

function EventManager.list()
    local storage = getStorage()
    return storage.events
end

-- ---------------------------------------------------------------------------
-- Проверка: существует ли событие с данным ID
-- ---------------------------------------------------------------------------

function EventManager.exists(eventId)
    local storage = getStorage()
    for _, event in ipairs(storage.events) do
        if event.id == eventId then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Tick: инициализация pending, retry pending_cleanup, proximity check, TTL
-- ---------------------------------------------------------------------------

local function tick()
    local storage = getStorage()
    local now = os.time()
    local ttlSec = EventConfig.TTL_HOURS * 3600
    local toRemove = {}

    for _, event in ipairs(storage.events) do
        -- 1. Pending: пробуем инициализировать если чанк загрузился
        if event.state == EventManager.STATE_PENDING then
            tryInitialize(event)
        end

        -- 2. Pending cleanup: повторяем cleanup если чанк загрузился
        if event.state == EventManager.STATE_PENDING_CLEANUP then
            if isChunkLoaded(event.x, event.y, event.z) then
                table.insert(toRemove, event.id)
            end
        end

        -- 3. Spawned: proximity check → переводим в visited
        if event.state == EventManager.STATE_SPAWNED then
            if EventUtils.isPlayerNearby(event.x, event.y, EventConfig.VISIT_RADIUS) then
                event.state = EventManager.STATE_VISITED
                event.visitedTime = now
                log("Event #" .. event.id .. " visited by a player")
            end
        end

        -- 4. TTL для pending и spawned — cleanup
        if event.state == EventManager.STATE_PENDING or event.state == EventManager.STATE_SPAWNED then
            if (now - event.spawnTime) > ttlSec then
                table.insert(toRemove, event.id)
            end
        end

        -- 5. TTL для visited — cleanup, но только когда рядом нет игроков
        if event.state == EventManager.STATE_VISITED then
            if (now - event.spawnTime) > ttlSec then
                if not EventUtils.isPlayerNearby(event.x, event.y, EventConfig.VISIT_RADIUS) then
                    table.insert(toRemove, event.id)
                end
            end
        end
    end

    for j = #toRemove, 1, -1 do
        EventManager.remove(toRemove[j])
    end
end

Events.EveryOneMinute.Add(tick)

-- ---------------------------------------------------------------------------
-- Сборщик мусора: при загрузке чанка проверяем осиротевшие объекты
-- Если объект/предмет помечен SZEventId, но такого события нет — удаляем
-- ---------------------------------------------------------------------------

local function onLoadGridsquare(square)
    if not square then return end

    local objsToRemove = {}
    for i = 0, square:getObjects():size() - 1 do
        local obj = square:getObjects():get(i)
        local objEventId = obj:getModData().SZEventId

        -- 1. Объект создан событием (ящик, палатка) — удаляем целиком
        if objEventId and not EventManager.exists(objEventId) then
            table.insert(objsToRemove, obj)
        end

        -- 2. Предметы в контейнере — удаляем осиротевшие независимо от пометки объекта
        local container = obj:getContainer()
        if container then
            local itemsToRemove = {}
            for j = 0, container:getItems():size() - 1 do
                local item = container:getItems():get(j)
                local itemEventId = item:getModData().SZEventId
                if itemEventId and not EventManager.exists(itemEventId) then
                    table.insert(itemsToRemove, item)
                end
            end
            for _, item in ipairs(itemsToRemove) do
                container:Remove(item)
            end
        end
    end

    for _, obj in ipairs(objsToRemove) do
        square:transmitRemoveItemFromSquare(obj)
    end

    -- 3. Предметы на земле (WorldObjects)
    local worldObjsToRemove = {}
    for i = 0, square:getWorldObjects():size() - 1 do
        local wo = square:getWorldObjects():get(i)
        local item = wo:getItem()
        if item then
            local itemEventId = item:getModData().SZEventId
            if itemEventId and not EventManager.exists(itemEventId) then
                table.insert(worldObjsToRemove, wo)
            end
        end
    end

    for _, wo in ipairs(worldObjsToRemove) do
        square:removeWorldObject(wo)
    end

    -- 4. Машины (BaseVehicle)
    local vehicle = square:getVehicleContainer()
    if vehicle then
        local eventId = vehicle:getModData().SZEventId
        if eventId and not EventManager.exists(eventId) then
            vehicle:permanentlyRemove()
            log("GC: removed orphaned vehicle (eventId=" .. eventId .. ")")
        end
    end

    -- 5. Трупы (IsoDeadBody)
    local bodies = square:getDeadBodys()
    if bodies then
        for i = bodies:size() - 1, 0, -1 do
            local body = bodies:get(i)
            if body then
                local eventId = body:getModData().SZEventId
                if eventId and not EventManager.exists(eventId) then
                    square:removeCorpse(body, false)
                    log("GC: removed orphaned corpse (eventId=" .. eventId .. ")")
                end
            end
        end
    end
end

Events.LoadGridsquare.Add(onLoadGridsquare)
Events.OnServerStarted.Add(loadEventMessages)

-- ---------------------------------------------------------------------------
-- Автоспавн событий
-- ---------------------------------------------------------------------------

local lastAutoSpawn = 0

local function autoSpawn()
    local now = os.time()
    local intervalSec = EventConfig.AUTO_SPAWN_INTERVAL_MINUTES * 60

    if (now - lastAutoSpawn) < intervalSec then return end
    lastAutoSpawn = now

    -- Выбираем случайный тип из разрешённых
    local allowedTypes = EventConfig.AUTO_SPAWN_TYPES
    if not allowedTypes or #allowedTypes == 0 then
        log("AutoSpawn: no types configured")
        return
    end

    -- Фильтруем: только те у кого есть локации и зарегистрирован handler
    local availableTypes = {}
    for _, typeName in ipairs(allowedTypes) do
        local locs = EventConfig.Locations and EventConfig.Locations[typeName]
        if locs and #locs > 0 and EventRegistry.get(typeName) then
            table.insert(availableTypes, typeName)
        end
    end

    if #availableTypes == 0 then
        log("AutoSpawn: no available types with locations")
        return
    end

    local typeName = availableTypes[ZombRand(#availableTypes) + 1]
    local locations = EventConfig.Locations[typeName]
    local loc = locations[ZombRand(#locations) + 1]
    log("AutoSpawn: trying " .. typeName .. " at " .. loc.x .. "," .. loc.y)

    local event, err = EventManager.spawn(typeName, loc.x, loc.y, 0, "auto")
    if not event then
        log("AutoSpawn: failed — " .. tostring(err))
    end
end

Events.EveryOneMinute.Add(autoSpawn)

log("EventManager loaded")
