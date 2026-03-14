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
