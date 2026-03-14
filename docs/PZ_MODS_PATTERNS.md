# Project Zomboid — Паттерны модов: создание объектов, зомби, трупов, транспорта и MP-синхронизация

> Анализ установленных модов из Steam Workshop (`108600/`)
> Дата: 2026-03-14

---

## Содержание

1. [Создание контейнеров/ящиков в мире](#1-создание-контейнеровящиков-в-мире)
2. [Создание трупов/мёртвых тел](#2-создание-труповмёртвых-тел)
3. [Спавн зомби](#3-спавн-зомби)
4. [Спавн транспорта](#4-спавн-транспорта)
5. [Предметы на земле](#5-предметы-на-земле)
6. [Клиент-серверное взаимодействие](#6-клиент-серверное-взаимодействие)
7. [Работа с радио](#7-работа-с-радио)
8. [Чтение файлов и конфигурации](#8-чтение-файлов-и-конфигурации)
9. [Проверка безопасности клеток](#9-проверка-безопасности-клеток)
10. [Общие паттерны (ModData, cleanup, lifecycle)](#10-общие-паттерны)

---

## 1. Создание контейнеров/ящиков в мире

### Подход A: IsoObject + AddSpecialObject (минимальный пример)

**Мод:** Bandits (3268487204)
**Файл:** `server/BanditServerSpawner.lua`

```lua
local function spawnObject(player, sprite, x, y, z)
    local cell = player:getCell()
    local square = cell:getGridSquare(x, y, z)
    if not square then return end

    local obj = IsoObject.new(square, sprite, "")
    square:AddSpecialObject(obj)
    obj:transmitCompleteItemToClients()
end
```

**Ключевые моменты:**
- `IsoObject.new(square, sprite, name)` — создание объекта
- `AddSpecialObject()` — добавляет объект с контейнером на клетку
- `transmitCompleteItemToClients()` — синхронизирует объект со всеми клиентами
- Спрайт ОБЯЗАН поддерживать контейнер (`getContainer()` может вернуть nil)
- **MP:** Подтверждено — работает
- **Плюсы:** Простой и надёжный, ванильный API
- **Минусы:** Нужен спрайт с поддержкой контейнера

> **Примечание:** На клиенте вместо `transmitCompleteItemToClients()` используется `transmitCompleteItemToServer()` — сервер рассылает остальным клиентам автоматически.

---

### Подход B: IsoObject + AddTileObject (через GlobalObject систему)

**Мод:** TchernoLib (3389605231)
**Файл:** `server/GlobalObject/SGlobalObjectCreator.lua`

```lua
function oType:addObject()
    if self:getObject() then return end
    local square = self:getSquare()
    if not square then return end

    -- Создаём IsoObject с именем GlobalObject
    local isoObject = IsoObject.new(square, self:getSpriteName(), ShGO.getGOName(key))

    -- Записываем ModData из Lua-объекта в IsoObject
    self:toModData(isoObject)

    -- AddTileObject вместо AddSpecialObject
    square:AddTileObject(isoObject)

    self:noise('added '..key..' IsoObject at index='..isoObject:getObjectIndex())
end

-- Создание через систему команд с синхронизацией:
oSysType['add_'..key] = function(self, playerObj, args)
    local grid = ShGO.getGridSquareFromArgs(args)
    if not grid then return nil end
    if self:getIsoObjectOnSquare(grid) then return nil end

    local luaObject = self:newLuaObjectOnSquare(grid)
    luaObject:initNew()
    luaObject = ShGO.overrideGOArgsWithParams(luaObject, args.transfer)
    luaObject:addObject()

    local isoObject = luaObject:getIsoObject()
    if isoObject then
        luaObject:toModData(isoObject)
        isoObject:transmitCompleteItemToClients()
    end
    return luaObject
end

-- Удаление:
function oType:removeObject()
    local square = self:getSquare()
    local isoObject = self:getIsoObject()
    if not square or not isoObject then return end
    square:transmitRemoveItemFromSquare(isoObject)
end
```

**Ключевые моменты:**
- `AddTileObject()` — альтернатива `AddSpecialObject()`, добавляет как тайл
- Продвинутая система с Lua-обёрткой и ModData синхронизацией
- **MP:** Полная поддержка через `transmitCompleteItemToClients()`
- **Плюсы:** Архитектурно правильная система для массовых объектов
- **Минусы:** Сложность реализации

---

### Подход D: Vehicle как контейнер (аирдропы)

**Мод:** Airdrops (3590950467)
**Файл:** `server/airdrop_server.lua`

```lua
local function createAirdrop(spawnArea, preset)
    local validation = ValidateAirdropAt(spawnArea.x, spawnArea.y, spawnArea.z or 0)
    if not validation.valid or not validation.square then return nil end
    local square = validation.square

    -- Случайное направление для визуального разнообразия
    local directions = {
        IsoDirections.N, IsoDirections.NE, IsoDirections.E, IsoDirections.SE,
        IsoDirections.S, IsoDirections.SW, IsoDirections.W, IsoDirections.NW
    }
    local randomDirection = directions[ZombRand(#directions) + 1]

    -- Создаём "транспорт" как контейнер
    local airdrop = addVehicleDebug("RandomAirdropsASV.airdrop", randomDirection, nil, square)

    if airdrop then
        airdrop:repair()  -- 100% состояние

        -- Доступ к контейнеру через часть транспорта
        if SandboxVars.AirdropMain.DefaultAirdropLootTable then
            local selectedPreset = preset or AirdropLoot.selectAirdropPreset()
            AirdropLoot.spawnPresetLoot(airdrop, selectedPreset, spawnArea)
        else
            AirdropLoot.SpawnLootFromFile(airdrop)
        end
        return airdrop
    end
    return nil
end
```

**Работа с контейнером транспорта:**
```lua
function AirdropLoot.spawnPresetLoot(airdrop, preset, spawnArea)
    -- Доступ к контейнеру через ID части
    local container = airdrop:getPartById("TruckBed"):getItemContainer()

    -- Добавление предметов
    container:AddItem("Base.WaterRationCan")
    container:AddItem("Base.CannedBeans")
    -- ...
end
```

**Ключевые моменты:**
- Vehicle автоматически синхронизируется в MP
- Контейнер через `getPartById("TruckBed"):getItemContainer()`
- Нужен XML-скрипт для определения vehicle
- **MP:** Полная автоматическая поддержка
- **Плюсы:** Надёжная синхронизация, поддержка лута
- **Минусы:** Нужен отдельный XML-скрипт для vehicle

---

---

## 2. Создание трупов/мёртвых тел

### Подход A: Bandits — массовый спавн трупов

**Мод:** Bandits (3268487204)
**Файл:** `shared/BanditBases/BanditBasePlacements.lua`

```lua
function BanditBasePlacements.Body(x, y, z, q)
    for i = 1, q do
        local zombie = createZombie(x, y, z, nil, 0, IsoDirections.S)
        local body = IsoDeadBody.new(zombie, false)  -- false = не был мёртв заранее
    end
end
```

**Ключевые моменты:**
- Минимальный код — без одежды, без лута, без синхронизации
- `IsoDeadBody.new(zombie, false)` — второй параметр false (не был мёртвым заранее)
- **MP:** Неявная синхронизация (может не работать надёжно)
- **Плюсы:** Простота
- **Минусы:** Нет контроля внешнего вида, нет MP-синхронизации

---

### Подход B: IsoDeadBody из животного

**Мод:** Airdrops (3590950467)
**Файл:** `server/airdrop_loot.lua`

```lua
function AirdropLoot.attemptSpawnAnimalNear(spawnArea)
    local animalX = spawnArea.x + dx
    local animalY = spawnArea.y + dy
    local animalZ = spawnArea.z or 0

    local finalSquare = getCell():getGridSquare(animalX, animalY, animalZ)
    if finalSquare and AirdropPositions.SquareIsSafe(finalSquare) then
        -- Получаем случайное определение животного
        local defs = getAllAnimalsDefinitions()
        local def = defs:get(ZombRand(defs:size()))
        local breeds = def:getBreeds()
        local breedName = breeds:get(ZombRand(breeds:size()))

        -- Создаём объект животного
        local tmpAnimal = IsoAnimal.new(
            getCell(),
            finalSquare:getX(), finalSquare:getY(), finalSquare:getZ(),
            def:getAnimalType(), breedName
        )

        -- Оборачиваем в IsoDeadBody
        local wasCorpseAlready = true    -- животное уже мертво
        local addToSquareAndWorld = false -- мы сами добавим на клетку
        local isoDeadBody = IsoDeadBody.new(tmpAnimal, wasCorpseAlready, addToSquareAndWorld)

        -- Получаем предмет трупа и кладём на землю
        local corpseItem = isoDeadBody:getItem()
        if corpseItem then
            finalSquare:AddWorldInventoryItem(corpseItem, 0.5, 0.0, 0.0)
        end
    end
end
```

**Ключевые моменты:**
- `IsoAnimal.new(cell, x, y, z, type, breed)` — создаёт животное
- `IsoDeadBody.new(animal, true, false)` — для животных 3 параметра
- `isoDeadBody:getItem()` — получаем предмет-труп для размещения
- `AddWorldInventoryItem(item, 0.5, 0.0, 0.0)` — кладём на землю
- **MP:** Работает через стандартную синхронизацию inventory items

---

### Подход C: createRandomDeadBody (ванильный метод)

```lua
-- Сигнатура:
RandomizedWorldBase.createRandomDeadBody(square, direction, age, unused, outfitName)

-- Пример:
local body = RandomizedWorldBase.createRandomDeadBody(
    sq,                  -- IsoGridSquare
    IsoDirections.S,     -- направление тела
    20,                  -- "возраст" трупа (разложение)
    0,                   -- не используется
    outfit               -- название outfit (строка)
)
```

**Ключевые моменты:**
- Ванильный метод — используется при генерации мира
- Третий параметр (20) — "возраст"/разложение трупа, НЕ количество крови
- **MP:** Синхронизация НЕ подтверждена — тело может быть видно только после релогина
- **Одежда:** параметр outfit может НЕ применяться корректно (подтверждено тестами — труп голый)
- **Статус:** требует дополнительного исследования

---

## 3. Спавн зомби

### Подход A: addZombiesInOutfit (основной для групп)

**Мод:** Airdrops (3590950467)
**Файл:** `server/airdrop_server.lua`

```lua
-- Спавн зомби при уничтожении аирдропа
local zombieCount = math.max(1, math.floor(explosionPower / 10))
local spawnRadius = math.max(1, math.floor(explosionPower / 40))

for i = 1, zombieCount do
    local angle = ZombRand(360) * math.pi / 180
    local distance = ZombRand(spawnRadius) + 1
    local zombieX = square:getX() + math.floor(distance * math.cos(angle))
    local zombieY = square:getY() + math.floor(distance * math.sin(angle))
    local zombieZ = square:getZ()

    local zombieSquare = getCell():getGridSquare(zombieX, zombieY, zombieZ)
    if zombieSquare then
        addZombiesInOutfit(zombieX, zombieY, zombieZ, 1, nil, 50)
    end
end
```

**Сигнатура:**
```lua
addZombiesInOutfit(x, y, z, count, outfitName, radius)
-- x, y, z    — координаты центра спавна
-- count      — количество зомби
-- outfitName — nil для случайного, или строка "Police", "Military" и т.д.
-- radius     — радиус разброса (0 = точная позиция)
```

**Ключевые моменты:**
- Автоматическая синхронизация в MP
- Не возвращает ссылки на созданных зомби
- **MP:** Полная автоматическая поддержка
- **Плюсы:** Простота, надёжность
- **Минусы:** Нет контроля над конкретными зомби после спавна

---

### Подход B: addZombiesInOutfit с расширенными параметрами (Bandits)

**Мод:** Bandits (3268487204)
**Файл:** `server/BanditServerSpawner.lua`

```lua
local function spawnGroup(spawnPoints, args)
    local cid = args.cid
    local clan = BanditCustom.ClanGet(cid)
    local banditOptions = BanditCustom.GetFromClan(cid)

    -- Перемешиваем опции
    local keys = {}
    for key in pairs(banditOptions) do table.insert(keys, key) end
    for i = #keys, 2, -1 do
        local j = ZombRand(i) + 1
        keys[i], keys[j] = keys[j], keys[i]
    end

    local i = 1
    for bid, bandit in pairs(banditSelected) do
        bandit.general.bid = bid
        local femaleChance = bandit.general.female and 100 or 0
        local outfit = "Naked" .. (1 + ZombRand(101))

        local sp = spawnPoints[i]

        -- Расширенный вызов с параметрами поведения
        local zombieList = BanditCompatibility.AddZombiesInOutfit(
            sp.x, sp.y, sp.z,       -- координаты
            outfit,                   -- костюм
            femaleChance,             -- шанс женского пола (0-100)
            crawler,                  -- ползающий зомби
            fallOnFront,              -- упал лицом
            fakeDead,                 -- притворяется мёртвым
            knockedDown,              -- сбит с ног
            invulnerable,             -- неуязвимый
            sitting,                  -- сидящий
            health                    -- здоровье
        )

        -- Получаем ссылку на зомби для дальнейшей настройки
        if zombieList:size() > 0 then
            local zombie = zombieList:get(0)
            banditize(zombie, bandit, clan, args)  -- превращаем в бандита
            i = i + 1
        end
    end
    return i - 1
end
```

**Ключевые моменты:**
- `BanditCompatibility.AddZombiesInOutfit()` — обёртка, возвращающая список зомби
- Можно получить ссылку на зомби через `zombieList:get(0)`
- Расширенные параметры: crawler, fakeDead, invulnerable и т.д.
- **MP:** Полная поддержка, + `TransmitBanditModData()` для данных бандитов

---

### Подход C: createZombie (для единичных зомби)

```lua
-- Сигнатура:
local zombie = createZombie(x, y, z, classType, health, direction)

-- Пример:
local zombie = createZombie(cx, cy, cz, nil, 0, IsoDirections.S)
-- x, y, z    — координаты
-- classType  — nil для обычного зомби
-- health     — 0 = стандартное здоровье
-- direction  — IsoDirections.S, N, E, W и т.д.

-- После создания можно настроить:
zombie:setFemale(true)
zombie:dressInNamedOutfit("Police")
```

**Когда что использовать:**
- `addZombiesInOutfit` — для групп зомби, автоматическая MP-синхронизация, не возвращает ссылку
- `createZombie` — для единичных зомби, когда нужна ссылка для дальнейшей настройки (переодеть, превратить в труп). **НЕ синхронизируется автоматически с клиентами в MP!**

---

## 4. Спавн транспорта

### Подход A: Базовый спавн (Bandits)

**Мод:** Bandits (3268487204)
**Файл:** `server/BanditServerSpawner.lua`

```lua
local function spawnVehicle(player, x, y, vtype, args)
    local cell = player:getCell()
    local square = cell:getGridSquare(x, y, 0)
    if not square then return end

    -- Создаём транспорт
    local vehicle = addVehicleDebug(vtype, IsoDirections.S, nil, square)
    if not vehicle then return end

    -- Очищаем все контейнеры
    for i = 0, vehicle:getPartCount() - 1 do
        local container = vehicle:getPartByIndex(i):getItemContainer()
        if container then
            container:removeAllItems()
        end
    end

    -- Ремонт до 100%
    vehicle:repair()

    -- Случайная сигнализация (33% шанс)
    if ZombRand(3) == 1 then
        vehicle:setAlarmed(true)
    end

    -- Случайное состояние деталей (20-100%)
    local cond = (2 + ZombRand(8)) / 10
    vehicle:setGeneralPartCondition(cond, 80)

    -- Запуск двигателя
    if args.engine then
        vehicle:setHotwired(true)
        vehicle:tryStartEngine(true)
        vehicle:engineDoStartingSuccess()
        vehicle:engineDoRunning()
    end

    -- Включение фар
    if args.lights then
        vehicle:setHeadlightsOn(true)
    end
end

-- Пример вызова:
local carOpts = {"Base.PickUpTruck", "Base.PickUpVan", "Base.VanSeats"}
spawnVehicle(player, vx, vy, BanditUtils.Choice(carOpts), {engine=true, lights=true})
```

**Ключевые моменты:**
- `addVehicleDebug(scriptName, direction, nil, square)` — основной метод
- `vehicle:repair()` — ремонт до 100%
- `vehicle:setGeneralPartCondition(cond, maxCond)` — общее состояние деталей
- `vehicle:setHotwired(true)` + `tryStartEngine(true)` — запуск двигателя
- **MP:** Автоматическая синхронизация
- **Удаление:** `vehicle:permanentlyRemove()`

---

### Подход B: Детальная настройка частей (True Essentials2)

**Мод:** True Essentials2 (3632510540)
**Файл:** `server/CBB_VehicleAdminSpawn.lua`

```lua
Events.OnClientCommand.Add(function(module, command, player, params)
    if module == 'AdminVehicleSpawner' and command == 'spawnVehicle' then
        local model = params.vehicleModel
        if not model or model == "" then return end

        local square = getCell():getGridSquare(params.posX, params.posY, params.posZ)
        if not square then return end

        -- Направление: 1=W, 2=E, 3=N, 4=S
        local direction = params.vehicleDirection or 0
        if direction == 0 then direction = ZombRand(1, 5) end
        if direction == 1 then direction = IsoDirections.W
        elseif direction == 2 then direction = IsoDirections.E
        elseif direction == 3 then direction = IsoDirections.N
        elseif direction == 4 then direction = IsoDirections.S end

        local vehicle = addVehicleDebug(model, direction, nil, square)

        if not string.contains(string.lower(model), "burnt") then
            local totalParts = vehicle:getPartCount()
            for i = 1, totalParts do
                local part = vehicle:getPartByIndex(i - 1)
                local partName = part:getId()
                if part and partName then

                    -- БАТАРЕЯ
                    if string.contains(string.lower(partName), "battery") then
                        local amount = ZombRand(1, 101)
                        if params.noBattery then amount = 0 end
                        if amount > 0 then amount = 1 - (amount / 100) end
                        part:getInventoryItem():setUsedDelta(amount)
                        vehicle:transmitPartUsedDelta(part)  -- синхронизация
                    end

                    -- ТОПЛИВО
                    if string.contains(string.lower(partName), "tank") then
                        local amount = ZombRand(1, 101)
                        if params.noFuel then amount = 0 end
                        local capacity = part:getContainerCapacity()
                        if amount > 0 then amount = capacity * amount / 100 end
                        part:setContainerContentAmount(amount)
                        vehicle:transmitPartModData(part)  -- синхронизация
                    end

                    -- ДВИГАТЕЛЬ
                    if string.lower(partName) == "engine" then
                        local engineCondition = 100
                        if tonumber(params.vehicleCondition) ~= 100 then
                            engineCondition = ZombRand(40, 81)
                        end
                        local engineL = vehicle:getScript():getEngineLoudness() or 100
                        local engineP = vehicle:getScript():getEngineForce()
                        vehicle:setEngineFeature(engineCondition, engineL, engineP)
                        vehicle:transmitEngine()  -- синхронизация
                    end

                    -- БАРДАЧОК + КЛЮЧ
                    if string.lower(partName) == "glovebox" and params.keyGlovebox then
                        local item = vehicle:createVehicleKey()
                        part:getItemContainer():AddItem(item)
                        -- Разблокируем все двери
                        for j = 0, 4 do
                            local door = vehicle:getPassengerDoor(j)
                            if not door then break end
                            door:getDoor():setLockBroken(false)
                            door:getDoor():setLocked(false)
                            vehicle:transmitPartDoor(door)  -- синхронизация
                        end
                    end

                    -- Состояние каждой детали
                    local condition = 100
                    if tonumber(params.vehicleCondition) ~= 100 then
                        condition = ZombRand(40, 81)
                    end
                    part:setCondition(condition)
                    vehicle:transmitPartCondition(part)  -- синхронизация
                end
            end
        end
    end
end)
```

**Методы синхронизации частей транспорта:**
| Метод | Что синхронизирует |
|-------|-------------------|
| `vehicle:transmitPartUsedDelta(part)` | Заряд батареи |
| `vehicle:transmitPartModData(part)` | ModData части (топливо) |
| `vehicle:transmitEngine()` | Состояние двигателя |
| `vehicle:transmitPartDoor(door)` | Состояние двери (замок) |
| `vehicle:transmitPartCondition(part)` | Состояние детали |

**Ключевые моменты:**
- Каждая часть требует отдельного transmit-вызова
- `vehicle:createVehicleKey()` — создание ключа зажигания
- Батарея: `setUsedDelta()` (0-1 float)
- Топливо: `setContainerContentAmount()` (литры)
- Двигатель: `setEngineFeature(condition, loudness, power)`
- **MP:** Полная поддержка через transmit-методы

---

## 5. Предметы на земле

### Подход A: AddWorldInventoryItem по типу (строка)

**Мод:** Airdrops (3590950467)
**Файл:** `server/airdrop_destroy_server.lua`

```lua
-- Мусор при уничтожении аирдропа
local trash = {
    "Base.TinCanEmpty", "Base.PopBottleEmpty", "Base.Garbagebag",
    "Base.Paperbag_Jays", "Base.Paperbag_Spiffos", "Base.ScrapMetal"
}
local count = ZombRand(3) + 2  -- 2-4 предмета
for i = 1, count do
    local it = trash[ZombRand(#trash) + 1]
    -- Случайные смещения внутри клетки (0.1-0.9)
    sq:AddWorldInventoryItem(it, ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0)
end
```

**Сигнатура:**
```lua
square:AddWorldInventoryItem(itemTypeOrObject, offsetX, offsetY, offsetZ)
-- itemTypeOrObject — строка "Module.ItemName" или объект InventoryItem
-- offsetX          — смещение по X внутри клетки (0.0 - 1.0, 0.5 = центр)
-- offsetY          — смещение по Y внутри клетки (0.0 - 1.0, 0.5 = центр)
-- offsetZ          — высота (обычно 0)
```

---

### Подход B: AddWorldInventoryItem с объектом (труп)

**Мод:** Airdrops (3590950467)

```lua
-- Создаём объект трупа и кладём на землю
local corpseItem = isoDeadBody:getItem()
if corpseItem then
    finalSquare:AddWorldInventoryItem(corpseItem, 0.5, 0.0, 0.0)
end
```

**Ключевые моменты:**
- Можно передать как строку (`"Base.Axe"`), так и InventoryItem объект
- `offsetX/Y` от 0.0 до 1.0 определяют позицию внутри клетки
- **MP:** Автоматическая синхронизация при вызове на сервере
- **Удаление:** предметы на земле удаляются через стандартные механизмы

---

## 6. Клиент-серверное взаимодействие

### Паттерн A: Сервер → Клиент (sendServerCommand)

**Мод:** Airdrops (3590950467)
**Файл:** `server/airdrop_events.lua`

```lua
function AirdropEvents.NotifyAirdropFell(spawnArea)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players:size() > 0 then
        -- Мультиплеер: отправляем каждому онлайн-игроку
        for pi = 0, players:size() - 1 do
            local pl = players:get(pi)
            sendServerCommand(pl, "ServerAirdrop", "airdrop_fell", {
                x = spawnArea.x,
                y = spawnArea.y,
                z = spawnArea.z
            })
        end
    else
        -- Синглплеер: вызываем клиентскую функцию напрямую
        if RandomAirdrops and RandomAirdrops.OnAirdropFellClient then
            RandomAirdrops.OnAirdropFellClient({
                x = spawnArea.x,
                y = spawnArea.y,
                z = spawnArea.z
            })
        end
    end
end
```

**Формат:**
```lua
-- Отправка конкретному игроку:
sendServerCommand(player, "ModuleName", "CommandName", { key1 = val1, key2 = val2 })

-- Обработка на клиенте:
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "ModuleName" then return end
    if command == "CommandName" then
        -- args.key1, args.key2 доступны
    end
end)
```

---

### Паттерн B: Клиент → Сервер (sendClientCommand)

**Мод:** Bandits (3268487204)
**Файл:** `client/BanditMenu.lua` (клиент)

```lua
-- Клиентская часть: отправляем команду на сервер
function BanditMenu.SpawnClan(player, square, cid)
    local player = getSpecificPlayer(0)
    local args = {}
    args.cid = cid
    args.x = square:getX()
    args.y = square:getY()
    args.z = square:getZ()
    args.program = "Bandit"
    args.size = 6
    sendClientCommand(player, 'Spawner', 'Clan', args)
end
```

**Файл:** `server/BanditServerSpawner.lua` (сервер)

```lua
-- Серверная часть: обрабатываем команду от клиента
local function onClientCommand(module, command, player, args)
    if module == "Spawner" and BanditServer[module] and BanditServer[module][command] then
        -- Выполняем действие
        BanditServer[module][command](player, args)
        -- Синхронизируем ModData со всеми клиентами
        if module == "Spawner" then
            TransmitBanditModData()
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
```

**Формат:**
```lua
-- Отправка на сервер:
sendClientCommand(player, "ModuleName", "CommandName", { key1 = val1 })

-- Обработка на сервере:
Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "ModuleName" then return end
    if command == "CommandName" then
        -- player — IsoPlayer, отправивший команду
        -- args.key1 доступен
    end
end)
```

---

### Паттерн C: Двойной режим (MP + SP)

**Мод:** Airdrops (3590950467)

```lua
function AirdropUtils.playAirdropEffects(spawnArea, zoneArea, zoneColor, airdropType)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if players and players:size() > 0 then
        -- MP: рассылаем команду всем
        for pi = 0, players:size() - 1 do
            local pl = players:get(pi)
            sendServerCommand(pl, "ServerAirdrop", "flyover", {
                x = spawnArea.x,
                y = spawnArea.y,
                z = spawnArea.z,
                nearPlayer = isNearPlayer
            })
        end
    else
        -- SP: вызываем напрямую
        if RandomAirdrops and RandomAirdrops.FlyOver then
            RandomAirdrops.FlyOver({
                x = spawnArea.x,
                y = spawnArea.y,
                z = spawnArea.z,
                nearPlayer = isNearPlayer
            })
        end
    end
end
```

**Ключевой паттерн:** Всегда проверяем `getOnlinePlayers()` — если nil или пусто, значит синглплеер.

---

### Паттерн D: ZoneLootRefill — полный CRUD через команды

**Мод:** ZoneLootRefill (3653007556)
**Файл:** `client/ZLR_Client.lua`

```lua
-- Запрос синхронизации
local function requestZoneSync()
    if sendClientCommand then
        sendClientCommand("ZLR", "requestSync", {})
    end
end

-- Обновление правил зоны
sendClientCommand("ZLR", "updateRules", { zoneId = self.zoneId, rules = rules })

-- Обновление границ зоны
sendClientCommand("ZLR", "updateBounds", {
    zoneId = zone.id, x1 = x1, y1 = y1, x2 = x2, y2 = y2
})

-- Создание зоны
sendClientCommand("ZLR", "addZone", { zone = zone })

-- Переименование зоны
sendClientCommand("ZLR", "renameZone", { zoneId = modal.zoneId, newName = newName })

-- Удаление зоны
sendClientCommand("ZLR", "removeZone", { zoneId = modal.zoneId })
```

**Ключевые моменты:**
- Один модуль ("ZLR"), много команд
- Данные передаются как Lua-таблица (автоматическая сериализация)
- Поддерживаются вложенные таблицы в args
- **MP:** Полная поддержка

---

## 7. Работа с радио

### RadioBroadCast — создание и отправка

**Мод:** Airdrops (3590950467)
**Файл:** `server/airdrop_radio.lua`

```lua
function airdropRadio.CreateScheduledBroadcast()
    -- Уникальный ID для трансляции
    local bc = RadioBroadCast.new("SCHED-"..tostring(ZombRand(100000,999999)), -1, -1)
    local c = {r=1.0, g=1.0, b=1.0}  -- Цвет текста (RGB)

    -- Добавляем статические помехи
    airdropRadio.AddFuzz(c, bc)

    -- Определяем язык
    local language = "EN"
    if AirdropTimeFormat and AirdropTimeFormat.getCurrentLanguage then
        language = AirdropTimeFormat.getCurrentLanguage()
    end

    -- Рассчитываем время до следующего аирдропа
    local nextAirdropTime = RandomAirdrops.calculateNextAirdropTime()
    local currentTime = getGameTime():getWorldAgeHours()
    local timeUntilDrop = nextAirdropTime - currentTime
    local timeFormatted = AirdropTimeFormat.formatTimeUntilDrop(timeUntilDrop, language)

    -- Случайные сообщения из локализации
    local rand = newrandom()
    local introNum = rand:random(1, 5)
    local introKey = string.format("IGUI_AirdropRadio_Schedule_Intro_%d", introNum)
    local introText = getText(introKey)

    local timeNum = rand:random(1, 5)
    local timeKey = string.format("IGUI_AirdropRadio_Schedule_Time_%d", timeNum)
    local timeText = string.format(getText(timeKey), timeFormatted)

    -- Добавляем строки в трансляцию
    airdropRadio.AddFuzz(c, bc)
    bc:AddRadioLine(RadioLine.new(introText, c.r, c.g, c.b))
    bc:AddRadioLine(RadioLine.new(timeText, c.r, c.g, c.b))
    airdropRadio.AddFuzz(c, bc)

    return bc
end

-- Эффект радиопомех:
function airdropRadio.AddFuzz(_c, _bc, _chance)
    local rand = ZombRand(1, _chance or 12)
    if rand == 1 or rand == 2 then
        _bc:AddRadioLine(RadioLine.new("<bzzt>", _c.r, _c.g, _c.b))
    elseif rand == 3 or rand == 4 then
        _bc:AddRadioLine(RadioLine.new("<fzzt>", _c.r, _c.g, _c.b))
    elseif rand == 5 or rand == 6 then
        _bc:AddRadioLine(RadioLine.new("<wzzt>", _c.r, _c.g, _c.b))
    end
end

-- Отправка в эфир:
local channel = airdropRadio.channel
if channel and airdropRadio.scheduledMessage then
    channel:setAiringBroadcast(airdropRadio.scheduledMessage)
end
```

**API RadioBroadCast:**
```lua
-- Создание:
local bc = RadioBroadCast.new(uniqueId, frequency1, frequency2)
-- uniqueId   — строковый ID трансляции
-- frequency1 — частота (-1 = без привязки к частоте)
-- frequency2 — вторая частота (-1 = не используется)

-- Добавление строк:
bc:AddRadioLine(RadioLine.new(text, r, g, b))
-- text — текст сообщения
-- r, g, b — цвет (0.0 - 1.0)

-- Отправка на канал:
channel:setAiringBroadcast(bc)
```

**Кириллица:**
- Тексты берутся из файлов локализации через `getText(key)`
- Прямой текст с кириллицей в `RadioLine.new()` — **не проверено**
- Рекомендуется использовать файлы переводов или `getFileReader` с UTF-8

---

## 8. Чтение файлов и конфигурации

### Подход A: getFileReader — чтение из Zomboid/Lua/

**Мод:** Airdrops (3590950467)
**Файл:** `server/airdrop_positions.lua`

```lua
function AirdropPositions.read()
    -- Открываем файл из Zomboid/Lua/
    local fileReader = getFileReader("AirdropPositions.ini", true)
    if not fileReader then
        airdropPositions = {}
        return
    end

    -- Читаем все строки
    local lines = {}
    local line = fileReader:readLine()
    while line do
        table.insert(lines, line)
        line = fileReader:readLine()
    end
    fileReader:close()

    -- Парсим как Lua-код
    local ok, tbl = pcall(function()
        local f = loadstring(table.concat(lines, "\n"))
        if f then return f() end
        return {}
    end)

    if ok and type(tbl) == "table" then
        airdropPositions = tbl
    else
        airdropPositions = {}
    end
end
```

**Сигнатура:**
```lua
local reader = getFileReader(fileName, createIfNotExists)
-- fileName          — имя файла (ищется в Zomboid/Lua/)
-- createIfNotExists — true = создать пустой файл если нет

local line = reader:readLine()  -- читает одну строку, nil = EOF
reader:close()                  -- ОБЯЗАТЕЛЬНО закрыть!
```

---

### Подход B: getModFileReader — чтение из папки мода

**Мод:** StarlitLibrary (3378285185)
**Файл:** `shared/Starlit/file/File.lua`

```lua
File.readFullFile = function(path, mod)
    local reader
    if mod then
        -- Чтение из папки мода
        reader = getModFileReader(mod, path, false)
    else
        -- Чтение из Zomboid/Lua/
        reader = getFileReader(path, false)
    end
    if not reader then return end

    local totalStr = ""
    local line = reader:readLine()
    if line then
        repeat
            totalStr = totalStr .. line
            line = reader:readLine()
        until line == nil
    end
    reader:close()

    return totalStr
end
```

**Сигнатура:**
```lua
local reader = getModFileReader(modId, filePath, createIfNotExists)
-- modId  — ID мода
-- filePath — путь относительно папки мода
```

---

### Подход C: Сериализация Lua-таблиц в файл

**Мод:** PhunLib (3667976848)
**Файл:** `shared/PhunLib/files.lua`

```lua
-- Загрузка таблицы из файла
function tools.loadTable(filename, createIfNotExists)
    local data = {}
    local fileReaderObj = getFileReader(filename, createIfNotExists == true)
    if not fileReaderObj then return nil end

    local line = fileReaderObj:readLine()
    while line do
        data[#data + 1] = line
        line = fileReaderObj:readLine()
    end
    fileReaderObj:close()

    -- Убираем trailing comma
    if data[#data]:sub(-1) == "," then
        data[#data] = data[#data]:sub(1, -2)
    end

    local result, err = tools.tableOfStringsToTable(data)
    if err then
        print("Error loading file " .. filename .. ": " .. err)
    else
        return result
    end
end

-- Сохранение таблицы в файл
function tools.saveTable(fname, data)
    if not data then return end
    local fileWriterObj = getFileWriter(fname, true, false)
    local serialized = tools.tableToString(data)
    fileWriterObj:write("return " .. serialized .. "")
    fileWriterObj:close()
end
```

**getFileWriter сигнатура:**
```lua
local writer = getFileWriter(fileName, createIfNotExists, appendMode)
-- fileName          — имя файла (записывается в Zomboid/Lua/)
-- createIfNotExists — true = создать если нет
-- appendMode        — false = перезаписать, true = дописать

writer:write(text)   -- записать текст
writer:close()       -- ОБЯЗАТЕЛЬНО закрыть!
```

---

### Подход D: INI-формат (Bandits)

**Мод:** Bandits (3268487204)
**Файл:** `shared/BanditCustom.lua`

```lua
-- Запись в INI-формат
local saveFile = function()
    local globalClanFile = getFileWriter(globalClanFileName, true, false)
    local banditOutput = ""

    for id, sections in pairs(data) do
        banditOutput = banditOutput .. "[" .. id .. "]\n"   -- секция
        for sname, tab in pairs(sections) do
            for k, v in pairs(tab) do
                -- формат: section: key = value
                banditOutput = banditOutput .. "\t" .. sname .. ": " .. k .. " = " .. tostring(v) .. "\n"
            end
        end
        banditOutput = banditOutput .. "\n"
    end

    globalClanFile:write(banditOutput)
    globalClanFile:close()
end
```

**Кириллица в файлах:**
- `getFileReader` / `getFileWriter` работают с байтами, НЕ гарантируют UTF-8
- `tostring()` не обрабатывает Unicode специально
- **Рекомендация:** для кириллицы использовать ModData (автоматическая сериализация PZ) или проверять кодировку вручную

---

## 9. Проверка безопасности клеток

### Полная проверка (Airdrops)

**Мод:** Airdrops (3590950467)
**Файл:** `server/airdrop_positions.lua`

```lua
function AirdropPositions.SquareIsSafe(square, forAnimalSpawn)
    -- 1. Клетка существует
    if not square then return false end

    -- 2. Чанк загружен и доступен
    local chunkOk, chunk = pcall(function() return square:getChunk() end)
    if not chunkOk or not chunk then return false end

    -- 3. Не внутри здания (нет комнаты)
    if square:getRoom() then return false end

    -- 4. Не вода
    if isWaterSquare(square) then return false end

    -- 5. Не твёрдый/непроходимый блок
    if square:isSolid() or square:isSolidTrans() then return false end

    -- 6. Нет пересечения с транспортом (опционально для животных)
    if not forAnimalSpawn and square:isVehicleIntersecting() then return false end

    -- 7. Есть пол
    if not square:getFloor() then return false end

    -- 8. Не блокирует размещение
    if not forAnimalSpawn and square:getProperties()
       and square:getProperties():Is("BlocksPlacement") then
        return false
    end

    -- 9. Клетка свободна (ISHutch проверка)
    if not forAnimalSpawn and not ISHutch:isSquareFree(square) then
        return false
    end

    return true
end
```

**Чеклист для безопасного спавна:**

| # | Проверка | Метод | Зачем |
|---|----------|-------|-------|
| 1 | Клетка существует | `square ~= nil` | Чанк может быть не загружен |
| 2 | Чанк доступен | `pcall(square:getChunk)` | Чанк может выгрузиться |
| 3 | Не в здании | `square:getRoom() == nil` | Не спавнить внутри построек |
| 4 | Не вода | `isWaterSquare(square)` | Предметы утонут |
| 5 | Не твёрдый | `isSolid() / isSolidTrans()` | Скалы, стены |
| 6 | Нет транспорта | `isVehicleIntersecting()` | Коллизия с машинами |
| 7 | Есть пол | `getFloor() ~= nil` | Нельзя спавнить в воздухе |
| 8 | Не BlocksPlacement | `getProperties():Is(...)` | Специальные блокирующие зоны |
| 9 | Свободна | `ISHutch:isSquareFree()` | Нет других объектов/зомби |

---

## 10. Общие паттерны

### ModData — хранение данных между сессиями

#### Глобальные данные (через GameTime)

**Мод:** Airdrops (3590950467)

```lua
-- Чтение/создание
local function _getLightsMD()
    local md = getGameTime():getModData()
    md.AirdropLights = md.AirdropLights or {}
    return md.AirdropLights
end

-- Сохранение и синхронизация
local function _saveLightsMD()
    if getGameTime().transmitModData then
        getGameTime():transmitModData()
    end
end

-- Использование:
local lights = _getLightsMD()
table.insert(lights, {
    x = square:getX(),
    y = square:getY(),
    z = square:getZ(),
    expireHours = expireHours
})
_saveLightsMD()
```

#### Через ModData API (ZoneLootRefill)

```lua
-- Получение или создание хранилища
local function getZonesData()
    local md = ModData.getOrCreate(ZLR_Client.ModDataKey)
    md.zones = md.zones or {}
    return md
end

-- Запрос синхронизации с сервером (клиент)
Events.OnInitGlobalModData.Add(function()
    getZonesData()
    if ModData and ModData.request then
        ModData.request(ZLR_Client.ModDataKey)
    end
end)
```

**Два способа хранения ModData:**
| Способ | API | Синхронизация | Когда использовать |
|--------|-----|---------------|-------------------|
| GameTime | `getGameTime():getModData()` | `transmitModData()` | Глобальные данные мира |
| ModData | `ModData.getOrCreate(key)` | `ModData.request(key)` | Модульные данные |

---

### Пометка объектов для cleanup

```lua
-- При создании:
obj:getModData().SZEventId = eventId      -- помечаем принадлежность
obj:getModData().StarterKit_Crate = true  -- или булевый флаг

-- При cleanup:
local function cleanupEvent(eventId)
    -- Обходим объекты на клетке
    local objects = sq:getObjects()
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        if obj:getModData().SZEventId == eventId then
            sq:transmitRemoveItemFromSquare(obj)
        end
    end
end
```

---

### Жизненный цикл объекта: pending → spawned → cleanup

**Мод:** Airdrops (3590950467)

```lua
-- Состояния
AirdropsData.ActiveAirdrops = {}

-- Создание (pending → spawned)
local airdrop = {
    spawnArea = spawnArea,
    state = "pending",                    -- начальное состояние
    type = airdropType,
    airdrop = nil,                        -- ссылка на vehicle (nil пока pending)
    spawnedAtHours = getGameTime():getWorldAgeHours(),
    despawnTime = getGameTime():getWorldAgeHours() + SandboxVars.AirdropMain.AirdropRemovalTimer
}
table.insert(AirdropsData.ActiveAirdrops, airdrop)

-- После создания физического объекта:
airdrop.state = "spawned"
airdrop.airdrop = vehicleRef

-- Cleanup (spawned → удаление)
for i = #AirdropsData.ActiveAirdrops, 1, -1 do
    local ad = AirdropsData.ActiveAirdrops[i]
    if ad.state == "spawned" and getGameTime():getWorldAgeHours() >= ad.despawnTime then
        -- Удаляем физический объект
        if ad.airdrop then
            ad.airdrop:permanentlyRemove()
        end
        -- Уведомляем клиентов
        sendServerCommand(pl, "ServerAirdrop", "clear_zone", { ... })
        -- Убираем из трекинга
        table.remove(AirdropsData.ActiveAirdrops, i)
    end
end
```

---

### Удаление объектов

```lua
-- Удаление IsoObject с клетки (с синхронизацией):
sq:transmitRemoveItemFromSquare(obj)

-- Удаление vehicle:
vehicle:permanentlyRemove()

-- Удаление огня:
local fire = findIsoFireOnSquare(sq)
if fire then
    fire:removeFromWorld()
    sq:transmitRemoveItemFromSquare(fire)
end

-- Поиск объекта на клетке для удаления:
local objects = square:getObjects()
for i = objects:size() - 1, 0, -1 do  -- обратный порядок при удалении!
    local obj = objects:get(i)
    if instanceof(obj, "IsoFire") then
        obj:removeFromWorld()
        square:transmitRemoveItemFromSquare(obj)
    end
end
```

---

### Обработка незагруженных чанков

```lua
-- Проверка перед спавном:
local chunkOk, chunk = pcall(function() return square:getChunk() end)
if not chunkOk or not chunk then
    -- Чанк не загружен — отложить спавн
    return
end

-- Получение клетки с проверкой:
local sq = getCell():getGridSquare(x, y, z)
if not sq then
    -- Клетка не загружена
    return
end
```

**Стратегии для незагруженных чанков:**
1. **Отложить спавн** — сохранить в pending и попробовать позже
2. **Спавнить при загрузке чанка** — подписаться на `Events.OnChunkLoaded`
3. **Использовать ModData** — данные сохраняются даже для незагруженных чанков

---

## Сводная таблица всех паттернов

| Паттерн | Основной API | MP-синхронизация | Моды-примеры |
|---------|-------------|------------------|--------------|
| Контейнер (IsoObject) | `IsoObject.new()` + `AddSpecialObject()` | `transmitCompleteItemToClients()` | Bandits, TchernoLib |
| Контейнер (Vehicle) | `addVehicleDebug()` | Автоматическая | Airdrops |
| Труп (из зомби) | `createZombie()` + `IsoDeadBody.new(zombie, false)` | **Не подтверждена** (⚠️ `GameServer` недоступен из Lua) | Bandits |
| Труп (ванильный) | `createRandomDeadBody()` | **Не подтверждена** (видно после релогина) | — |
| Труп (животное) | `IsoAnimal.new()` + `IsoDeadBody.new()` | Через `AddWorldInventoryItem()` | Airdrops |
| Зомби (группа) | `addZombiesInOutfit()` | Автоматическая | Airdrops, Bandits |
| Зомби (одиночный) | `createZombie()` | **НЕ синхронизируется** в MP | Bandits (для IsoDeadBody) |
| Транспорт | `addVehicleDebug()` | Автоматическая + `transmitPart*()` | Airdrops, Bandits, True Essentials2 |
| Предметы на земле | `AddWorldInventoryItem()` | Автоматическая | Airdrops |
| Клиент→Сервер | `sendClientCommand()` | — | Bandits, ZoneLootRefill |
| Сервер→Клиент | `sendServerCommand()` | — | Airdrops, Bandits |
| Радио | `RadioBroadCast.new()` + `RadioLine.new()` | Автоматическая | Airdrops |
| Файлы | `getFileReader()` / `getFileWriter()` | Только сервер | Airdrops, Bandits, PhunLib |
| Данные | `getGameTime():getModData()` / `ModData.getOrCreate()` | `transmitModData()` / `ModData.request()` | Airdrops, ZoneLootRefill |

### ⚠️ Известные ограничения

- **`GameServer` НЕ доступен из Lua** — вызов `GameServer.sendCorpse()` или `GameServer.sendBecomeCorpse()` приводит к ошибке `attempted index of non-table: null`
- **`createZombie()` НЕ синхронизируется** с клиентами в MP — зомби виден только серверу
- **`createRandomDeadBody()` — одежда может не применяться** — при передаче outfit параметра труп остаётся голым (подтверждено тестами)
- **`IsoDeadBody.new(zombie, true)` vs `IsoDeadBody.new(zombie, false)`** — Bandits использует `false`, разница не документирована

---

## Источники (пути к файлам)

### Airdrops (3590950467)
- `.../3590950467/mods/Airdrops/42/media/lua/server/airdrop_server.lua`
- `.../3590950467/mods/Airdrops/42/media/lua/server/airdrop_loot.lua`
- `.../3590950467/mods/Airdrops/42/media/lua/server/airdrop_events.lua`
- `.../3590950467/mods/Airdrops/42/media/lua/server/airdrop_radio.lua`
- `.../3590950467/mods/Airdrops/42/media/lua/server/airdrop_positions.lua`
- `.../3590950467/mods/Airdrops/42/media/lua/server/airdrop_destroy_server.lua`
- `.../3590950467/mods/Airdrops/42/media/lua/shared/airdrop_utils.lua`

### Bandits (3268487204)
- `.../3268487204/mods/Bandits/42.15/media/lua/server/BanditServerSpawner.lua`
- `.../3268487204/mods/Bandits/42.15/media/lua/shared/BanditBases/BanditBasePlacements.lua`
- `.../3268487204/mods/Bandits/42.15/media/lua/shared/BanditFS.lua`
- `.../3268487204/mods/Bandits/42.15/media/lua/shared/BanditCustom.lua`
- `.../3268487204/mods/Bandits/42.15/media/lua/client/BanditMenu.lua`

### TchernoLib (3389605231)
- `.../3389605231/mods/TchernoLib/common/media/lua/server/GlobalObject/SGlobalObjectCreator.lua`

### True Essentials2 (3632510540)
- `.../3632510540/mods/True Essentials2/42/media/lua/server/CBB_VehicleAdminSpawn.lua`

### ZoneLootRefill (3653007556)
- `.../3653007556/mods/ZoneLootRefill/42/media/lua/server/ZLR_Server.lua`
- `.../3653007556/mods/ZoneLootRefill/42/media/lua/client/ZLR_Client.lua`

### PhunLib (3667976848)
- `.../3667976848/mods/PhunLib/media/lua/shared/PhunLib/files.lua`

### StarlitLibrary (3378285185)
- `.../3378285185/mods/StarlitLibrary/42.13/media/lua/shared/Starlit/file/File.lua`

> Базовый путь: `/Users/viktor.pelih/Library/Application Support/Steam/steamapps/workshop/content/108600/`
