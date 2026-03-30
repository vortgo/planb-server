local function log(msg)
    print("[Airdrop] " .. tostring(msg))
end

local Airdrop = {}

local AIRDROP_SCRIPTS = {
    "SafeZoneVehicles.airdrop",
    "SafeZoneVehicles.FEMASupplyDrop",
    "SafeZoneVehicles.SurvivorSupplyDrop",
}

--- Спавн: ящик-аирдроп (vehicle) + лут + зомби
function Airdrop.spawn(x, y, z, eventId)
    local sq = EventUtils.findSafeSquare(x, y, z, EventConfig.SAFE_SQUARE_RADIUS)
    if not sq then
        return nil, "No safe square found"
    end

    local scriptName = AIRDROP_SCRIPTS[ZombRand(#AIRDROP_SCRIPTS) + 1]
    local vehicle = addVehicleDebug(scriptName, IsoDirections.N, nil, sq)
    if not vehicle then
        return nil, "Failed to spawn airdrop vehicle: " .. scriptName
    end

    vehicle:getModData().SZEventId = eventId
    vehicle:repair()

    -- Лут в TruckBed
    local truckBed = vehicle:getPartById("TruckBed")
    local itemCount = 0
    if truckBed and truckBed:getItemContainer() then
        itemCount = EventUtils.generateLoot(truckBed:getItemContainer(), "airdrop", eventId)
    end

    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()

    -- Зомби вокруг
    EventUtils.spawnZombies(cx, cy, cz, "airdrop")

    log("Spawned " .. scriptName .. " at " .. cx .. "," .. cy .. " loot=" .. itemCount)

    return {
        x = cx,
        y = cy,
        z = cz or 0,
        itemCount = itemCount,
    }
end

--- Cleanup: удаляем аирдроп-машину
function Airdrop.cleanup(spawnData, eventId)
    if not spawnData then return end
    EventUtils.removeVehicleByEventId(
        spawnData.x, spawnData.y, spawnData.z, eventId, 5
    )
end

--- Описание
function Airdrop.getDescription(x, y, z)
    return "Airdrop spotted near " .. x .. ", " .. y
end

-- ---------------------------------------------------------------------------
-- Регистрация
-- ---------------------------------------------------------------------------
EventRegistry.register("airdrop", Airdrop)
local function log(msg)
    print("[BuildingStash] " .. tostring(msg))
end

local BuildingStash = {}

-- validate не нужен — spawn() сам проверяет наличие контейнера
-- двойной вызов findRandomContainerInBuilding был бы лишней нагрузкой

--- Спавн: найти контейнер → закинуть лут → пометить каждый предмет
function BuildingStash.spawn(x, y, z, eventId)
    local obj, container, sq = EventUtils.findRandomContainerInBuilding(
        x, y, z, EventConfig.BUILDING_SEARCH_RADIUS
    )
    if not container then
        return nil, "No building with containers found"
    end

    -- Генерируем лут, помечая каждый предмет eventId
    local count = EventUtils.generateLoot(container, "buildingstash", eventId)
    if count == 0 then
        return nil, "Loot generation failed: 0 items rolled"
    end
    log("Added " .. count .. " items to container at " .. sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ())

    -- Обновляем визуал контейнера (пустой/полный спрайт)
    EventUtils.syncContainerVisual(obj)

    -- Зомби вокруг
    EventUtils.spawnZombies(sq:getX(), sq:getY(), sq:getZ(), "buildingstash")

    return {
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
        containerX = sq:getX(),
        containerY = sq:getY(),
        containerZ = sq:getZ(),
        itemCount = count,
    }
end

--- Cleanup (spawned, не посещён): удаляем предметы, но не сам контейнер (он часть здания)
function BuildingStash.cleanup(spawnData, eventId)
    if not spawnData then return end
    EventUtils.cleanupByEventId(
        spawnData.containerX, spawnData.containerY, spawnData.containerZ,
        eventId,
        { radius = 0, removeItems = true, removeObjects = false }
    )
end

--- Описание для уведомлений
function BuildingStash.getDescription(x, y, z)
    return "Supply stash reported near " .. x .. ", " .. y
end

-- ---------------------------------------------------------------------------
-- Регистрация
-- ---------------------------------------------------------------------------
EventRegistry.register("buildingstash", BuildingStash)
local function log(msg)
    print("[ForestStash] " .. tostring(msg))
end

local ForestStash = {}

--- Спавн: найти свободную клетку → поставить ящик → закинуть лут
function ForestStash.spawn(x, y, z, eventId)
    local sq = EventUtils.findSafeSquare(x, y, z, EventConfig.SAFE_SQUARE_RADIUS)
    if not sq then
        return nil, "No safe square found"
    end

    -- Создаём деревянный ящик
    local obj = IsoObject.new(getCell(), sq, EventConfig.FOREST_CRATE_SPRITE)
    obj:getModData().SZEventId = eventId
    obj:setName("ForestStash")
    sq:AddSpecialObject(obj)
    obj:transmitCompleteItemToClients()

    -- Проверяем что контейнер появился
    local container = obj:getContainer()
    if not container then
        -- Спрайт не поддерживает контейнер — убираем объект
        sq:transmitRemoveItemFromSquare(obj)
        return nil, "Crate has no container (sprite issue)"
    end

    -- Генерируем лут
    local count = EventUtils.generateLoot(container, "foreststash", eventId)
    if count == 0 then
        sq:transmitRemoveItemFromSquare(obj)
        return nil, "Loot generation failed: 0 items rolled"
    end

    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()
    log("Placed crate with " .. count .. " items at " .. cx .. "," .. cy .. "," .. cz)

    EventUtils.syncContainerVisual(obj)

    -- Зомби вокруг
    EventUtils.spawnZombies(cx, cy, cz, "foreststash")

    return {
        x = cx,
        y = cy,
        z = cz,
        itemCount = count,
    }
end

--- Cleanup: удаляем ящик целиком (он наш, не часть мира)
function ForestStash.cleanup(spawnData, eventId)
    if not spawnData then return end
    EventUtils.cleanupByEventId(
        spawnData.x, spawnData.y, spawnData.z,
        eventId,
        { radius = 1, removeItems = true, removeObjects = true }
    )
end

--- Описание для уведомлений
function ForestStash.getDescription(x, y, z)
    return "Forest stash reported near " .. x .. ", " .. y
end

-- ---------------------------------------------------------------------------
-- Регистрация
-- ---------------------------------------------------------------------------
EventRegistry.register("foreststash", ForestStash)
local function log(msg)
    print("[AbandonedVehicle] " .. tostring(msg))
end

local AbandonedVehicle = {}

--- Спавн: найти клетку → поставить машину → настроить состояние
function AbandonedVehicle.spawn(x, y, z, eventId)
    local sq = EventUtils.findSafeSquare(x, y, z, EventConfig.SAFE_SQUARE_RADIUS)
    if not sq then
        return nil, "No safe square found"
    end

    -- Случайный тип машины
    local types = EventConfig.Vehicle.types
    local vehicleType = types[ZombRand(#types) + 1]

    -- Случайное направление
    local directions = { IsoDirections.N, IsoDirections.S, IsoDirections.E, IsoDirections.W }
    local dir = directions[ZombRand(#directions) + 1]

    local vehicle = addVehicleDebug(vehicleType, dir, nil, sq)
    if not vehicle then
        return nil, "Failed to spawn vehicle " .. vehicleType
    end

    vehicle:getModData().SZEventId = eventId

    -- Настраиваем состояние: убитый двигатель, мало топлива
    local cond = EventConfig.Vehicle.condition
    local engineCondition = ZombRand(cond.engineMin, cond.engineMax + 1)

    -- Двигатель
    local engine = vehicle:getPartById("Engine")
    if engine then
        engine:setCondition(engineCondition)
    end

    -- Топливо
    local gas = vehicle:getPartById("GasTank")
    if gas then
        local fuelAmount = cond.fuelMin + ZombRand(1000) / 1000 * (cond.fuelMax - cond.fuelMin)
        gas:setContainerContentAmount(fuelAmount)
    end

    -- Шанс отсутствия колеса
    if ZombRand(1000) < cond.missingTireChance * 1000 then
        local tires = {"TireFrontLeft", "TireFrontRight", "TireRearLeft", "TireRearRight"}
        local tireName = tires[ZombRand(#tires) + 1]
        local tire = vehicle:getPartById(tireName)
        if tire then
            tire:setCondition(0)
        end
    end

    -- Лут в бардачке/багажнике
    local container = vehicle:getPartById("GloveBox")
    if container and container:getItemContainer() then
        EventUtils.generateLoot(container:getItemContainer(), "abandonedvehicle", eventId)
    end
    local trunk = vehicle:getPartById("TruckBed")
    if trunk and trunk:getItemContainer() then
        EventUtils.generateLoot(trunk:getItemContainer(), "abandonedvehicle", eventId)
    end

    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()
    log("Spawned " .. vehicleType .. " at " .. cx .. "," .. cy .. " engine=" .. engineCondition)

    -- Зомби вокруг
    EventUtils.spawnZombies(cx, cy, cz, "abandonedvehicle")

    return {
        x = cx,
        y = cy,
        z = cz or 0,
    }
end

--- Cleanup: удаляем машину
function AbandonedVehicle.cleanup(spawnData, eventId)
    if not spawnData then return end
    EventUtils.removeVehicleByEventId(
        spawnData.x, spawnData.y, spawnData.z, eventId, 5
    )
end

--- Описание
function AbandonedVehicle.getDescription(x, y, z)
    return "Abandoned vehicle spotted near " .. x .. ", " .. y
end

-- ---------------------------------------------------------------------------
-- Регистрация
-- ---------------------------------------------------------------------------
EventRegistry.register("abandonedvehicle", AbandonedVehicle)
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
local function log(msg)
    print("[HelicopterCrash] " .. tostring(msg))
end

local HelicopterCrash = {}

-- Каждый вариант: fuselage + matching tail + matching debris items
local CRASH_VARIANTS = {
    {
        fuselage = "SafeZoneVehicles.UH60GreenCrash",
        tail     = "SafeZoneVehicles.UH60GreenTail",
    },
    {
        fuselage = "SafeZoneVehicles.UH60DesertCrash",
        tail     = "SafeZoneVehicles.UH60DesertTail",
    },
    {
        fuselage = "SafeZoneVehicles.UH60MedevacCrash",
        tail     = "SafeZoneVehicles.UH60MedevacTail",
    },
    {
        fuselage = "SafeZoneVehicles.Bell206PoliceCrash",
        tail     = "SafeZoneVehicles.Bell206PoliceTail",
    },
    {
        fuselage = "SafeZoneVehicles.Bell206SurvivalistCrash",
        tail     = "SafeZoneVehicles.Bell206SurvivalistTail",
    },
}

-- Радиус разброса обломков (в тайлах)
local DEBRIS_SPREAD = 6
-- Радиус смещения хвоста от фюзеляжа
local TAIL_OFFSET = 4

--- Найти свободную клетку на земле рядом с координатами
local function findGroundSquare(cx, cy, radius)
    for attempt = 1, 15 do
        local dx = ZombRand(-radius, radius + 1)
        local dy = ZombRand(-radius, radius + 1)
        local sq = getSquare(cx + dx, cy + dy, 0)
        if sq and not sq:isBlockedTo(sq) and sq:isFree(false) then
            return sq
        end
    end
    return nil
end

--- Спавн: разбитый вертолёт + хвост + обломки + лут + зомби
function HelicopterCrash.spawn(x, y, z, eventId)
    local sq = EventUtils.findSafeSquare(x, y, z, EventConfig.SAFE_SQUARE_RADIUS)
    if not sq then
        return nil, "No safe square found"
    end

    -- Случайный вариант крушения (всё консистентно)
    local variant = CRASH_VARIANTS[ZombRand(#CRASH_VARIANTS) + 1]

    -- Случайное направление
    local directions = { IsoDirections.N, IsoDirections.S, IsoDirections.E, IsoDirections.W }
    local dir = directions[ZombRand(#directions) + 1]

    -- Спавн фюзеляжа
    local vehicle = addVehicleDebug(variant.fuselage, dir, nil, sq)
    if not vehicle then
        return nil, "Failed to spawn helicopter: " .. variant.fuselage
    end
    vehicle:getModData().SZEventId = eventId

    -- Лут в TruckBed
    local truckBed = vehicle:getPartById("TruckBed")
    local itemCount = 0
    if truckBed and truckBed:getItemContainer() then
        itemCount = EventUtils.generateLoot(truckBed:getItemContainer(), "helicoptercrash", eventId)
    end

    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()

    -- Спавн хвостовой секции (отдельный vehicle, рядом с фюзеляжем)
    local tailSq = findGroundSquare(cx, cy, TAIL_OFFSET)
    if tailSq then
        local tailDir = directions[ZombRand(#directions) + 1]
        local tailVeh = addVehicleDebug(variant.tail, tailDir, nil, tailSq)
        if tailVeh then
            tailVeh:getModData().SZEventId = eventId
            log("Tail spawned: " .. variant.tail)
        end
    end

    -- Металлический лут разбросан вокруг (полезен для крафта)
    local debrisCount = 0
    local METAL_LOOT = {
        { item = "Base.ScrapMetal",    weight = 20 },
        { item = "Base.SheetMetal",    weight = 10 },
        { item = "Base.MetalBar",      weight = 8 },
        { item = "Base.Pipe",          weight = 6 },
        { item = "Base.Wire",          weight = 8 },
        { item = "Base.Nails",         weight = 10 },
        { item = "Base.Screws",        weight = 8 },
        { item = "Base.NutsBolts",     weight = 6 },
        { item = "Base.ElectricWire",  weight = 5 },
        { item = "Base.Aluminum",      weight = 4 },
        { item = "Base.WeldingRods",   weight = 3 },
        { item = "Base.BarbedWire",    weight = 2 },
    }

    -- Подсчёт общего веса для weighted random
    local totalWeight = 0
    for _, entry in ipairs(METAL_LOOT) do
        totalWeight = totalWeight + entry.weight
    end

    local metalCount = ZombRand(25, 50)
    for i = 1, metalCount do
        local roll = ZombRand(totalWeight)
        local cumulative = 0
        local chosen = METAL_LOOT[1].item
        for _, entry in ipairs(METAL_LOOT) do
            cumulative = cumulative + entry.weight
            if roll < cumulative then
                chosen = entry.item
                break
            end
        end

        local scrapSq = findGroundSquare(cx, cy, DEBRIS_SPREAD)
        if scrapSq then
            local scrap = scrapSq:AddWorldInventoryItem(chosen, 0, 0, 0)
            if scrap then
                scrap:getModData().SZEventId = eventId
                debrisCount = debrisCount + 1
            end
        end
    end

    -- Очаги огня вокруг крушения (4-6 шт) через IsoFire.new + AttachAnim
    if IsoFire and IsoFire.new then
        local fireCount = ZombRand(4, 7)
        local cell = getWorld():getCell()
        local tileScale = Core.getTileScale()
        local animDelay = IsoFireManager.FireAnimDelay
        local tintMod = IsoFireManager.FireTintMod
        local numFrames = IsoFire.NUM_FRAMES_FIRE

        for i = 1, fireCount do
            local fireSq = findGroundSquare(cx, cy, DEBRIS_SPREAD)
            if fireSq then
                local ok, err = pcall(function()
                    local fireObj = IsoFire.new(cell, fireSq)
                    if fireObj then
                        local scale = 0.6 + ZombRand(7) * 0.1
                        fireObj:AttachAnim("Fire", "01", numFrames,
                            animDelay, scale * tileScale,
                            -scale * tileScale, true, 0, false, 0.7, tintMod)
                        fireSq:AddTileObject(fireObj)
                        fireObj:transmitCompleteItemToClients()
                        if fireObj.setLightRadius then
                            fireObj:setLightRadius(10)
                        end
                    end
                end)
                if ok then
                    log("Fire spawned at " .. fireSq:getX() .. "," .. fireSq:getY())
                else
                    log("WARN: Fire spawn failed: " .. tostring(err))
                end
            end
        end
    else
        log("WARN: IsoFire.new not available")
    end

    -- Много зомби вокруг
    EventUtils.spawnZombies(cx, cy, cz, "helicoptercrash")

    log("Spawned " .. variant.fuselage .. " at " .. cx .. "," .. cy
        .. " dir=" .. tostring(dir) .. " loot=" .. itemCount .. " debris=" .. debrisCount)

    return {
        x = cx,
        y = cy,
        z = cz or 0,
        itemCount = itemCount,
        debrisCount = debrisCount,
    }
end

--- Cleanup: удаляем вертолёт, хвост и обломки
function HelicopterCrash.cleanup(spawnData, eventId)
    if not spawnData then return end

    local cx, cy, cz = spawnData.x, spawnData.y, spawnData.z
    local searchRadius = DEBRIS_SPREAD + 2

    -- Удаляем vehicles (фюзеляж + хвост) по SZEventId
    EventUtils.removeVehicleByEventId(cx, cy, cz, eventId, searchRadius)

    -- Удаляем WorldItems (металлолом) в радиусе крушения
    local itemsRemoved = 0
    for dx = -searchRadius, searchRadius do
        for dy = -searchRadius, searchRadius do
            local sq = getSquare(cx + dx, cy + dy, 0)
            if sq then
                local items = sq:getWorldObjects()
                if items then
                    for i = items:size() - 1, 0, -1 do
                        local obj = items:get(i)
                        if obj then
                            sq:transmitRemoveItemFromSquare(obj)
                            itemsRemoved = itemsRemoved + 1
                        end
                    end
                end
            end
        end
    end

    -- Удаляем огни (IsoFire)
    for dx = -searchRadius, searchRadius do
        for dy = -searchRadius, searchRadius do
            local sq = getSquare(cx + dx, cy + dy, 0)
            if sq then
                if sq.stopFire then
                    sq:stopFire()
                end
                if sq.transmitStopFire then
                    sq:transmitStopFire()
                end
                local objects = sq:getObjects()
                if objects then
                    for i = objects:size() - 1, 0, -1 do
                        local obj = objects:get(i)
                        if obj and instanceof(obj, "IsoFire") then
                            sq:transmitRemoveItemFromSquare(obj)
                            obj:removeFromWorld()
                        end
                    end
                end
            end
        end
    end
    log("Cleanup: removed " .. itemsRemoved .. " world items + fires for event #" .. eventId)
end

--- Описание
function HelicopterCrash.getDescription(x, y, z)
    return "Helicopter crash site near " .. x .. ", " .. y
end

-- ---------------------------------------------------------------------------
-- Регистрация
-- ---------------------------------------------------------------------------
EventRegistry.register("helicoptercrash", HelicopterCrash)
