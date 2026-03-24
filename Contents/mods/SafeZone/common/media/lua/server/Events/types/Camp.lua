local function log(msg)
    print("[Camp] " .. tostring(msg))
end

local Camp = {}

-- ---------------------------------------------------------------------------
-- Палатки (camping_01, 2 тайла каждая, как в ваниле)
-- Ориентация 1: frontRight(camping_01_0) + backRight(camping_01_1), dy=-1
-- Ориентация 2: frontLeft(camping_01_3) + backLeft(camping_01_2), dx=-1
-- ---------------------------------------------------------------------------
local TENT_ORIENTATIONS = {
    { front = "camping_01_0", back = "camping_01_1", dx = 0, dy = -1 },
    { front = "camping_01_3", back = "camping_01_2", dx = -1, dy = 0 },
}

-- Спальники (2x1)
local SLEEPING_BAG_BASES = { 0, 8, 16, 24 }
local SLEEPING_BAG_OFFSETS = {
    {0, 0, 0},
    {1, 0, 1},
}

local CAMPFIRE_SPRITE = "camping_01_6"  -- потухший костёр
local CHEST_SPRITE = "furniture_storage_02_28"

-- ---------------------------------------------------------------------------
-- Размещение палатки (ванильный подход через IsoThumpable)
-- ---------------------------------------------------------------------------
local function placeTent(sq, orientation, eventId)
    local x, y, z = sq:getX(), sq:getY(), sq:getZ()
    local placed = {}

    -- Передний тайл (с контейнером)
    local frontObj = IsoThumpable.new(getCell(), sq, orientation.front, false, {})
    frontObj:setName("Tent")
    frontObj:getModData().SZEventId = eventId
    frontObj:setBlockAllTheSquare(true)
    frontObj:setIsThumpable(false)
    sq:AddSpecialObject(frontObj)
    frontObj:transmitCompleteItemToClients()
    table.insert(placed, frontObj)

    -- Задний тайл
    local backSq = getCell():getGridSquare(x + orientation.dx, y + orientation.dy, z)
    if backSq then
        local backObj = IsoThumpable.new(getCell(), backSq, orientation.back, false, {})
        backObj:setName("Tent")
        backObj:getModData().SZEventId = eventId
        backObj:setBlockAllTheSquare(true)
        backObj:setIsThumpable(false)
        backSq:AddSpecialObject(backObj)
        backObj:transmitCompleteItemToClients()
        table.insert(placed, backObj)
    end

    return placed
end

--- Поставить один объект на клетку
local function placeObject(sq, sprite, eventId, name)
    local obj = IsoObject.new(getCell(), sq, sprite)
    obj:getModData().SZEventId = eventId
    if name then obj:setName(name) end
    sq:AddSpecialObject(obj)
    obj:transmitCompleteItemToClients()
    return obj
end

--- Разместить multi-tile объект (спальник)
local function placeMultiTile(cx, cy, cz, dx, dy, tilesheet, base, offsets, eventId, name)
    local placed = {}
    for _, off in ipairs(offsets) do
        local sq = getCell():getGridSquare(cx + dx + off[1], cy + dy + off[2], cz)
        if sq then
            local sprite = tilesheet .. "_" .. (base + off[3])
            local obj = placeObject(sq, sprite, eventId, name)
            table.insert(placed, obj)
        end
    end
    return placed
end

--- Спавн лагеря
function Camp.spawn(x, y, z, eventId)
    local sq = EventUtils.findSafeSquare(x, y, z, EventConfig.SAFE_SQUARE_RADIUS)
    if not sq then
        return nil, "No safe square found"
    end

    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()
    local placed = 0

    -- Костёр в центре (1 тайл)
    placeObject(sq, CAMPFIRE_SPRITE, eventId, "Campfire")
    placed = placed + 1
    log("Campfire at " .. cx .. "," .. cy)

    -- 2 палатки с разными ориентациями
    local tentPositions = {{-3, -2}, {3, 2}}
    for i, pos in ipairs(tentPositions) do
        local tentSq = getCell():getGridSquare(cx + pos[1], cy + pos[2], cz)
        if tentSq then
            local orient = TENT_ORIENTATIONS[((i - 1) % #TENT_ORIENTATIONS) + 1]
            local objs = placeTent(tentSq, orient, eventId)
            placed = placed + #objs

            -- Лут в палатку (контейнер на переднем тайле)
            if #objs > 0 then
                local container = objs[1]:getContainer()
                if container then
                    EventUtils.generateLoot(container, "camp", eventId)
                    EventUtils.syncContainerVisual(objs[1])
                end
            end
            log("Tent " .. i .. " (" .. #objs .. " tiles) at " .. tentSq:getX() .. "," .. tentSq:getY())
        end
    end

    -- 1-2 спальника (2x1)
    local bagCount = ZombRand(1, 3)
    local bagPositions = {{-1, 2}, {1, -2}}
    for i = 1, bagCount do
        local pos = bagPositions[i]
        if pos then
            local base = SLEEPING_BAG_BASES[ZombRand(#SLEEPING_BAG_BASES) + 1]
            local objs = placeMultiTile(cx, cy, cz, pos[1], pos[2], "camping_02", base, SLEEPING_BAG_OFFSETS, eventId, "SleepingBag")
            placed = placed + #objs
            log("SleepingBag " .. i .. " (" .. #objs .. " tiles) base=" .. base)
        end
    end

    -- 1-2 ящика с лутом
    local chestCount = ZombRand(1, 3)
    local chestPositions = {{0, -3}, {2, 1}}
    local totalLoot = 0
    for i = 1, chestCount do
        local pos = chestPositions[i]
        if pos then
            local chestSq = getCell():getGridSquare(cx + pos[1], cy + pos[2], cz)
            if chestSq then
                local chestObj = placeObject(chestSq, CHEST_SPRITE, eventId, "SmallChest")
                placed = placed + 1

                local container = chestObj:getContainer()
                if container then
                    local count = EventUtils.generateLoot(container, "camp", eventId)
                    totalLoot = totalLoot + count
                    EventUtils.syncContainerVisual(chestObj)
                end
                log("Chest at " .. chestSq:getX() .. "," .. chestSq:getY())
            end
        end
    end

    if placed == 0 then
        return nil, "Failed to place any camp objects"
    end

    -- Зомби вокруг
    EventUtils.spawnZombies(cx, cy, cz, "camp")

    log("Camp spawned: " .. placed .. " objects, " .. totalLoot .. " loot items at " .. cx .. "," .. cy)

    return {
        x = cx,
        y = cy,
        z = cz,
        itemCount = totalLoot,
    }
end

--- Cleanup: удаляем все объекты лагеря по eventId
function Camp.cleanup(spawnData, eventId)
    if not spawnData then return end
    EventUtils.cleanupByEventId(
        spawnData.x, spawnData.y, spawnData.z,
        eventId,
        { radius = 10, removeItems = true, removeObjects = true }
    )
end

--- Описание
function Camp.getDescription(x, y, z)
    return "Abandoned camp found near " .. x .. ", " .. y
end

-- ---------------------------------------------------------------------------
-- Регистрация
-- ---------------------------------------------------------------------------
EventRegistry.register("camp", Camp)
