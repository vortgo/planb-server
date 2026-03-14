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
