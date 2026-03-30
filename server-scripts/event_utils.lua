EventUtils = EventUtils or {}

local function log(msg)
    print("[EventUtils] " .. tostring(msg))
end

-- ---------------------------------------------------------------------------
-- Проверка: попадает ли точка в чей-то сейфхаус
-- ---------------------------------------------------------------------------

function EventUtils.isInSafehouse(x, y, radius)
    radius = radius or 0
    local safehouses = SafeHouse.getSafehouseList()
    if not safehouses then return false end

    for i = 0, safehouses:size() - 1 do
        local sh = safehouses:get(i)
        local sx1 = sh:getX()
        local sy1 = sh:getY()
        local sx2 = sh:getX2()
        local sy2 = sh:getY2()
        -- Проверяем пересечение с радиусом поиска
        if x + radius >= sx1 and x - radius <= sx2
            and y + radius >= sy1 and y - radius <= sy2 then
            return true
        end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Расстояние
-- ---------------------------------------------------------------------------

function EventUtils.distance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

-- ---------------------------------------------------------------------------
-- Проверка безопасности клетки
-- ---------------------------------------------------------------------------

function EventUtils.isSquareSafe(square)
    if not square then return false end

    -- isFree() проверяет коллизии, стены, объекты — всё в одном вызове
    if not square:isFree(false) then return false end
    if square:TreatAsSolidFloor() == false then return false end

    -- Встроенные методы IsoGridSquare для деревьев и кустов
    if square:HasTree() then return false end
    if square:hasBush() then return false end

    return true
end

-- ---------------------------------------------------------------------------
-- Спавн зомби вокруг точки
-- ---------------------------------------------------------------------------

function EventUtils.spawnZombies(x, y, z, eventTypeName, radius)
    local cfg = EventConfig.Zombies[eventTypeName]
    if not cfg then return 0 end

    local count = ZombRand(cfg.min, cfg.max + 1)
    if count <= 0 then return 0 end

    radius = radius or 10

    -- Спавним каждого зомби отдельно со смещением от точки (минимум 3 клетки)
    -- чтобы не застревали в объекте события
    local spawned = 0
    for _ = 1, count do
        local angle = ZombRand(360) * math.pi / 180
        local dist = 3 + ZombRand(radius - 2)
        local zx = x + math.floor(dist * math.cos(angle))
        local zy = y + math.floor(dist * math.sin(angle))
        addZombiesInOutfit(zx, zy, z or 0, 1, nil, 0)
        spawned = spawned + 1
    end

    log("Spawned " .. spawned .. " zombies for " .. eventTypeName .. " at " .. x .. "," .. y)
    return spawned
end

-- ---------------------------------------------------------------------------
-- Поиск свободной клетки в радиусе
-- ---------------------------------------------------------------------------

function EventUtils.findSafeSquare(x, y, z, maxRadius)
    maxRadius = maxRadius or EventConfig.SAFE_SQUARE_RADIUS
    local cell = getCell()
    local zz = z or 0

    -- Сначала проверяем саму точку
    local sq0 = cell:getGridSquare(x, y, zz)
    if EventUtils.isSquareSafe(sq0) then
        return sq0
    end

    -- Расширяем радиус постепенно: 2 → 5 → 10 → maxRadius
    local steps = { 2, 5, 10, maxRadius }
    for _, r in ipairs(steps) do
        if r > maxRadius then r = maxRadius end
        for _ = 1, 8 do
            local rx = x + ZombRand(-r, r + 1)
            local ry = y + ZombRand(-r, r + 1)
            local sq = cell:getGridSquare(rx, ry, zz)
            if EventUtils.isSquareSafe(sq) then
                return sq
            end
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Поиск случайного контейнера в здании
-- ---------------------------------------------------------------------------

function EventUtils.findRandomContainerInBuilding(x, y, z, radius)
    radius = radius or EventConfig.BUILDING_SEARCH_RADIUS

    -- Собираем здания в радиусе
    local buildings = {}
    local cell = getCell()

    -- Сканируем сетку с шагом 3 по всем этажам (0-3)
    for dz = 0, 3 do
        for dx = -radius, radius, 3 do
            for dy = -radius, radius, 3 do
                local sq = cell:getGridSquare(x + dx, y + dy, dz)
                if sq then
                    local building = sq:getBuilding()
                    if building then
                        local found = false
                        for _, b in ipairs(buildings) do
                            if b == building then found = true; break end
                        end
                        if not found then
                            table.insert(buildings, building)
                        end
                    end
                end
            end
        end
    end

    if #buildings == 0 then
        log("No buildings found near " .. x .. "," .. y)
        return nil, nil, nil
    end

    -- Случайное здание
    local building = buildings[ZombRand(#buildings) + 1]
    local def = building:getDef()
    if not def then return nil, nil, nil end

    -- Собираем все комнаты
    local rooms = {}
    for i = 0, def:getRooms():size() - 1 do
        table.insert(rooms, def:getRooms():get(i))
    end

    if #rooms == 0 then
        log("Building has no rooms")
        return nil, nil, nil
    end

    -- Перемешиваем комнаты и ищем контейнер
    for attempt = 1, math.min(#rooms, 5) do
        local idx = ZombRand(#rooms) + 1
        local room = rooms[idx]
        local roomDef = room

        -- Получаем IsoRoom → сканируем клетки
        local isoRoom = roomDef:getIsoRoom()
        if isoRoom then
            local containers = {}
            for si = 0, isoRoom:getSquares():size() - 1 do
                local sq = isoRoom:getSquares():get(si)
                if sq then
                    for oi = 0, sq:getObjects():size() - 1 do
                        local obj = sq:getObjects():get(oi)
                        if obj:getContainer() then
                            table.insert(containers, obj)
                        end
                    end
                end
            end

            if #containers > 0 then
                local chosen = containers[ZombRand(#containers) + 1]
                local csq = chosen:getSquare()
                return chosen, chosen:getContainer(), csq
            end
        end
    end

    log("No containers found in building rooms")
    return nil, nil, nil
end

-- ---------------------------------------------------------------------------
-- Proximity check: есть ли игрок рядом
-- ---------------------------------------------------------------------------

function EventUtils.isPlayerNearby(x, y, radius)
    radius = radius or EventConfig.VISIT_RADIUS
    local players = getOnlinePlayers()
    if not players then return false end

    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then
            local dist = EventUtils.distance(x, y, p:getX(), p:getY())
            if dist <= radius then
                return true
            end
        end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Синхронизация визуала контейнера (спрайт пустой/полный)
-- ---------------------------------------------------------------------------

function EventUtils.syncContainerVisual(obj)
    if not obj or not obj:getContainer() then return end
    pcall(obj.sendObjectChange, obj, "containers")
end

-- ---------------------------------------------------------------------------
-- Кэш предметов по категориям (для category-based лута)
-- ---------------------------------------------------------------------------

EventUtils.categoryCache = nil

function EventUtils.buildCategoryCache()
    if EventUtils.categoryCache then return EventUtils.categoryCache end

    local cache = {}
    local itemList = getScriptManager():getAllItems()
    for i = 0, itemList:size() - 1 do
        local script = itemList:get(i)
        if not script:getObsolete() and not script:isHidden() then
            local cat = script:getTypeString() or ""
            if cat ~= "" then
                if not cache[cat] then cache[cat] = {} end
                table.insert(cache[cat], script:getFullName())
            end
        end
    end

    -- Логируем доступные категории
    local catNames = {}
    for cat, items in pairs(cache) do
        table.insert(catNames, cat .. "(" .. #items .. ")")
    end
    table.sort(catNames)
    log("Category cache built: " .. table.concat(catNames, ", "))

    EventUtils.categoryCache = cache
    return cache
end

function EventUtils.getRandomItemFromCategory(categoryName)
    local cache = EventUtils.buildCategoryCache()
    local items = cache[categoryName]
    if not items or #items == 0 then
        log("No items in category: " .. tostring(categoryName))
        return nil
    end
    return items[ZombRand(#items) + 1]
end

-- ---------------------------------------------------------------------------
-- Генерация лута из таблицы
-- Поддерживает:
--   { item = "Base.Axe", chance = 0.5, min = 1, max = 2 }       — конкретный предмет
--   { category = "Weapon", chance = 0.5, min = 1, max = 2 }     — случайный из категории
-- ---------------------------------------------------------------------------

function EventUtils.generateLoot(container, lootTableName, eventId, skipSync)
    local lootTable = EventConfig.Loot[lootTableName]
    if not lootTable then
        log("Unknown loot table: " .. tostring(lootTableName))
        return 0
    end

    local count = 0
    for _, entry in ipairs(lootTable) do
        if ZombRand(1000) < entry.chance * 1000 then
            local qty = ZombRand(entry.min, entry.max + 1)
            for _ = 1, qty do
                local itemId = entry.item
                if not itemId and entry.category then
                    itemId = EventUtils.getRandomItemFromCategory(entry.category)
                end
                if itemId then
                    local added = container:AddItem(itemId)
                    if added then
                        if eventId then
                            added:getModData().SZEventId = eventId
                        end
                        if not skipSync then
                            sendAddItemToContainer(container, added)
                        end
                        count = count + 1
                    end
                end
            end
        end
    end

    return count
end

-- ---------------------------------------------------------------------------
-- Универсальный cleanup по eventId в радиусе
-- Сканирует клетки вокруг точки, удаляет объекты и предметы с SZEventId == eventId
-- opts.radius       — радиус сканирования (default 5)
-- opts.removeItems  — удалять предметы из контейнеров (default true)
-- opts.removeObjects — удалять сами объекты с клетки (default true)
-- ---------------------------------------------------------------------------

function EventUtils.cleanupByEventId(x, y, z, eventId, opts)
    opts = opts or {}
    local radius = opts.radius or 5
    local removeItems = opts.removeItems ~= false
    local removeObjects = opts.removeObjects ~= false

    local cell = getCell()
    local removedObjects = 0
    local removedItems = 0

    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = cell:getGridSquare(x + dx, y + dy, z or 0)
            if sq then
                local objsToRemove = {}
                for i = 0, sq:getObjects():size() - 1 do
                    local obj = sq:getObjects():get(i)
                    local objEventId = obj:getModData().SZEventId

                    -- Удаляем помеченные предметы из ЛЮБОГО контейнера на клетке
                    if removeItems then
                        local container = obj:getContainer()
                        if container then
                            local itemsToRemove = {}
                            for j = 0, container:getItems():size() - 1 do
                                local item = container:getItems():get(j)
                                if item:getModData().SZEventId == eventId then
                                    table.insert(itemsToRemove, item)
                                end
                            end
                            for _, item in ipairs(itemsToRemove) do
                                sendRemoveItemFromContainer(container, item)
                                container:Remove(item)
                                removedItems = removedItems + 1
                            end
                            if #itemsToRemove > 0 then
                                EventUtils.syncContainerVisual(obj)
                            end
                        end
                    end

                    -- Объект создан событием — помечаем на удаление
                    if removeObjects and objEventId == eventId then
                        table.insert(objsToRemove, obj)
                    end
                end

                -- Удаляем объекты с клетки
                for _, obj in ipairs(objsToRemove) do
                    sq:transmitRemoveItemFromSquare(obj)
                    removedObjects = removedObjects + 1
                end

                -- Предметы на земле (WorldItems)
                if removeItems then
                    local groundItems = {}
                    for i = 0, sq:getWorldObjects():size() - 1 do
                        local wo = sq:getWorldObjects():get(i)
                        local item = wo:getItem()
                        if item and item:getModData().SZEventId == eventId then
                            table.insert(groundItems, wo)
                        end
                    end
                    for _, wo in ipairs(groundItems) do
                        sq:removeWorldObject(wo)
                        removedItems = removedItems + 1
                    end
                end
            end
        end
    end

    log("Cleanup eventId=" .. eventId .. ": removed " .. removedObjects .. " objects, " .. removedItems .. " items")
    return removedObjects, removedItems
end

-- ---------------------------------------------------------------------------
-- Удаление транспорта по eventId
-- BaseVehicle — отдельная сущность, не IsoObject на клетке
-- Ищем через getMovingObjects() или getVehicleContainer()
-- ---------------------------------------------------------------------------

function EventUtils.removeVehicleByEventId(x, y, z, eventId, radius)
    radius = radius or 5
    local cell = getCell()
    local removed = 0

    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = cell:getGridSquare(x + dx, y + dy, z or 0)
            if sq then
                local vehicle = sq:getVehicleContainer()
                if vehicle and vehicle:getModData().SZEventId == eventId then
                    vehicle:permanentlyRemove()
                    removed = removed + 1
                    log("Removed vehicle #" .. removed .. " for eventId=" .. eventId)
                end
            end
        end
    end

    if removed == 0 then
        log("Vehicle not found for eventId=" .. eventId)
    end
    return removed > 0
end
