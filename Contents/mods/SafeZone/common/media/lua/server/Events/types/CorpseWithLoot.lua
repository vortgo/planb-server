local function log(msg)
    print("[CorpseWithLoot] " .. tostring(msg))
end

local CorpseWithLoot = {}

--- Спавн: труп с лутом + зомби-охранники
function CorpseWithLoot.spawn(x, y, z, eventId)
    local sq = EventUtils.findSafeSquare(x, y, z, EventConfig.SAFE_SQUARE_RADIUS)
    if not sq then
        return nil, "No safe square found"
    end

    local cx, cy, cz = sq:getX(), sq:getY(), sq:getZ()

    -- Выбираем аутфит
    local outfits = EventConfig.Corpse.outfits
    local outfit = outfits[ZombRand(#outfits) + 1]
    local isFemale = ZombRand(1000) < EventConfig.Corpse.femaleChance * 1000

    local body = nil

    -- Спавним зомби через addZombiesInOutfit (синхронизирует в MP),
    -- одеваем, превращаем в труп через IsoDeadBody.new
    local ok, err = pcall(function()
        local zombies = addZombiesInOutfit(cx, cy, cz, 1, outfit, 0)
        if not zombies or zombies:size() == 0 then
            log("addZombiesInOutfit returned no zombies")
            return
        end
        local zombie = zombies:get(0)
        if isFemale then
            zombie:setFemale(true)
            zombie:dressInNamedOutfit(outfit)
        end
        -- IsoDeadBody.new(zombie, fallOnFront) — копирует визуал (одежду) с зомби
        local db = IsoDeadBody.new(zombie, false)
        db:getModData().SZEventId = eventId
        -- addCorpse(body, true) — второй параметр отправляет клиентам
        sq:addCorpse(db, true)
        -- Удаляем живого зомби-источника
        zombie:removeFromWorld()
        zombie:removeFromSquare()
        body = db
        log("Corpse created via addZombiesInOutfit + IsoDeadBody.new, outfit=" .. outfit)
    end)
    if not ok then
        log("Corpse creation failed: " .. tostring(err))
    end

    -- Лут
    local count = 0
    if body then
        -- Пробуем положить лут в контейнер трупа
        local container = body:getContainer() or (body.getInventory and body:getInventory())
        if container then
            count = EventUtils.generateLoot(container, "corpswithloot", eventId, true)
            log("Loot added to corpse container: " .. count .. " items")
        end
    end

    -- Если лут в труп не попал — кладём на землю рядом
    if count == 0 then
        local lootTable = EventConfig.Loot["corpswithloot"]
        if lootTable then
            for _, entry in ipairs(lootTable) do
                if ZombRand(1000) < entry.chance * 1000 then
                    local qty = ZombRand(entry.min, entry.max + 1)
                    for _ = 1, qty do
                        local item = sq:AddWorldInventoryItem(entry.item, ZombRand(100) / 100, ZombRand(100) / 100, 0)
                        if item then
                            item:getModData().SZEventId = eventId
                            count = count + 1
                        end
                    end
                end
            end
        end
        if count == 0 then
            return nil, "Loot generation failed"
        end
        log("Loot placed on ground: " .. count .. " items at " .. cx .. "," .. cy)
    end

    -- Зомби-охранники
    EventUtils.spawnZombies(cx, cy, cz, "corpswithloot")

    return {
        x = cx,
        y = cy,
        z = cz,
        itemCount = count,
    }
end

--- Cleanup: удаляем труп и предметы по eventId
function CorpseWithLoot.cleanup(spawnData, eventId)
    if not spawnData then return end
    -- Удаляем трупы
    local cell = getCell()
    local radius = 5
    for dx = -radius, radius do
        for dy = -radius, radius do
            local sq = cell:getGridSquare(spawnData.x + dx, spawnData.y + dy, spawnData.z or 0)
            if sq then
                local bodies = sq:getDeadBodys()
                if bodies then
                    for i = bodies:size() - 1, 0, -1 do
                        local body = bodies:get(i)
                        if body and body:getModData().SZEventId == eventId then
                            sq:removeCorpse(body, false)
                            log("Removed corpse for eventId=" .. eventId)
                        end
                    end
                end
            end
        end
    end
    -- Удаляем предметы на земле (fallback)
    EventUtils.cleanupByEventId(
        spawnData.x, spawnData.y, spawnData.z,
        eventId,
        { radius = 3, removeItems = true, removeObjects = false }
    )
end

--- Описание
function CorpseWithLoot.getDescription(x, y, z)
    return "Body found near " .. x .. ", " .. y
end

-- ---------------------------------------------------------------------------
-- Регистрация
-- ---------------------------------------------------------------------------
EventRegistry.register("corpswithloot", CorpseWithLoot)
