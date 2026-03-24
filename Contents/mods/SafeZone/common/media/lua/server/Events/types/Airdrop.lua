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
