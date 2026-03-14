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
