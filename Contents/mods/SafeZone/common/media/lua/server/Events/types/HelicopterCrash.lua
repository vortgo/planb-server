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

    local metalCount = ZombRand(15, 25)
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
