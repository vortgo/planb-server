# Project Zomboid Lua API Reference (Build 42)

Справочник по Java API движка Project Zomboid, доступному из серверных Lua модов.

> **Источник данных:** декомпиляция `projectzomboid.jar` через `javap`, анализ Lua файлов движка и модов.
> Все типы указаны в Java-нотации. В Lua типы приводятся автоматически (int/float/double → number, String → string, ArrayList → table, boolean → boolean).
> `KahluaTable` в Lua — обычная таблица `{}`.
>
> **⚠️ Важно:** Не все Java-классы экспонированы в Lua через `LuaManager.Exposer`. В частности, `GameServer` **НЕ доступен** из Lua (возвращает nil/null). Методы `GameServer.*` описаны ниже для справки, но вызывать их напрямую нельзя. Используйте глобальные функции-обёртки (`sendServerCommand`, `sendAddItemToContainer`, `sendRemoveItemFromContainer` и т.д.).

---

## Содержание

1. [Создание объектов в мире (IsoObject)](#1-создание-объектов-в-мире-isoobject)
2. [Создание трупов (IsoDeadBody)](#2-создание-трупов-isodeadbody)
3. [Создание и управление зомби (IsoZombie)](#3-создание-и-управление-зомби-isozombie)
4. [Создание транспорта (BaseVehicle)](#4-создание-транспорта-basevehicle)
5. [Работа с клетками (IsoGridSquare)](#5-работа-с-клетками-isogridsquare)
6. [Работа с контейнерами (ItemContainer)](#6-работа-с-контейнерами-itemcontainer)
7. [Работа с SafeHouse](#7-работа-с-safehouse)
8. [Сеть и синхронизация](#8-сеть-и-синхронизация)
9. [Спрайты и свойства](#9-спрайты-и-свойства)
10. [Утилиты](#10-утилиты)
11. [События (Events)](#11-события-events)
12. [Радиовещание](#12-радиовещание)

---

## 1. Создание объектов в мире (IsoObject)

**Класс:** `zombie.iso.IsoObject` — базовый класс для всех объектов на карте.

### Конструкторы

```lua
-- Основные конструкторы, доступные из Lua:
local obj = IsoObject.new(cell)                          -- IsoObject(IsoCell)
local obj = IsoObject.new(cell, square, sprite)          -- IsoObject(IsoCell, IsoGridSquare, IsoSprite)
local obj = IsoObject.new(cell, square, spriteName)      -- IsoObject(IsoCell, IsoGridSquare, String)
local obj = IsoObject.new(square, spriteName)            -- IsoObject(IsoGridSquare, String)
local obj = IsoObject.new(square, spriteName, movable)   -- IsoObject(IsoGridSquare, String, boolean)

-- Статический фабричный метод:
local obj = IsoObject.getNew(square, spriteName, containerSpriteName, doNotSync)
-- IsoObject.getNew(IsoGridSquare, String, String, boolean) → IsoObject
```

### Добавление на клетку

| Метод | Сигнатура | Описание |
|-------|-----------|----------|
| `AddSpecialObject` | `square:AddSpecialObject(obj)` | Добавляет объект как "специальный" (интерактивный: двери, окна, контейнеры). Не синхронизирует автоматически. |
| `AddSpecialObject` | `square:AddSpecialObject(obj, index)` | То же, с указанием позиции в списке объектов. |
| `AddTileObject` | `square:AddTileObject(obj)` | Добавляет объект как тайловый (стены, полы, декор). |
| `AddTileObject` | `square:AddTileObject(obj, index)` | То же, с указанием позиции. |

### Синхронизация объектов в MP

| Метод | Сигнатура | Описание |
|-------|-----------|----------|
| `transmitCompleteItemToClients` | `obj:transmitCompleteItemToClients()` | **Ключевой метод.** Отправляет полное состояние объекта всем клиентам. Вызывать после создания объекта и добавления на клетку. |
| `transmitUpdatedSpriteToClients` | `obj:transmitUpdatedSpriteToClients()` | Обновляет спрайт объекта на клиентах. |
| `transmitCustomColorToClients` | `obj:transmitCustomColorToClients()` | Синхронизирует кастомный цвет. |
| `sendObjectChange` | `obj:sendObjectChange(changeType)` | Отправляет изменение объекта. `changeType` — `IsoObjectChange`. |
| `sendObjectChange` | `obj:sendObjectChange(changeType, table)` | То же, с данными в KahluaTable. |
| `sync` | `obj:sync()` | Синхронизирует объект. |
| `sync` | `obj:sync(flags)` | Синхронизирует с флагами. |
| `transmitRemoveItemFromSquare` | `square:transmitRemoveItemFromSquare(obj)` → `int` | Удаляет объект с клетки и синхронизирует. Возвращает индекс. |
| `transmitAddObjectToSquare` | `square:transmitAddObjectToSquare(obj, index)` | Добавляет объект на клетку и синхронизирует с клиентами. |

### Свойство `doNotSync`

```lua
obj.doNotSync = true  -- Отключает автосинхронизацию объекта
```

### Основные методы IsoObject

| Метод | Возвращает | Описание |
|-------|-----------|----------|
| `getSquare()` | `IsoGridSquare` | Клетка, на которой стоит объект |
| `setSquare(square)` | `void` | Установить клетку |
| `getSprite()` | `IsoSprite` | Спрайт объекта |
| `setSprite(sprite)` / `setSprite(name)` | `void` | Установить спрайт |
| `setSpriteFromName(name)` | `void` | Установить спрайт по имени |
| `getContainer()` | `ItemContainer` | Контейнер объекта (может быть nil) |
| `setContainer(container)` | `void` | Установить контейнер |
| `getModData()` | `KahluaTable` | Мод-данные (создаются при первом вызове) |
| `hasModData()` | `boolean` | Есть ли мод-данные |
| `getDir()` | `IsoDirections` | Направление объекта |
| `setDir(dirIndex)` | `void` | Установить направление (0-7) |
| `setForwardIsoDirection(dir)` | `void` | Установить направление (IsoDirections) |
| `getName()` / `name` | `String` | Имя объекта |
| `getObjectName()` | `String` | Имя класса объекта |
| `getTextureName()` | `String` | Имя текстуры |
| `getCell()` | `IsoCell` | Ячейка мира |
| `addToWorld()` | `void` | Добавить объект в мир |
| `removeFromWorld()` | `void` | Убрать объект из мира |
| `setAlpha(alpha)` | `void` | Установить прозрачность (0.0-1.0) |
| `setAlphaAndTarget(alpha)` | `void` | Установить прозрачность и целевую |

### Создание объекта с контейнером

Объект должен иметь спрайт, у которого в свойствах указан тип контейнера (`ContainerType`). Либо можно создать контейнер вручную:

```lua
local square = getCell():getGridSquare(x, y, z)
local obj = IsoObject.new(getCell(), square, "spriteName")
square:AddSpecialObject(obj)

-- Создать контейнер вручную:
local container = ItemContainer.new("myContainer", square, obj)
container:setCapacity(50)
obj:setContainer(container)

obj:transmitCompleteItemToClients()  -- синхронизировать в MP
```

---

## 2. Создание трупов (IsoDeadBody)

**Класс:** `zombie.iso.objects.IsoDeadBody` — наследник `IsoMovingObject`.

### Конструкторы

| Конструктор | Описание |
|-------------|----------|
| `IsoDeadBody(IsoGameCharacter)` | Создаёт труп из персонажа (зомби/игрока). Копирует визуал, одежду, предметы. |
| `IsoDeadBody(IsoGameCharacter, boolean)` | `boolean` — fallOnFront (труп лицом вниз). |
| `IsoDeadBody(IsoGameCharacter, boolean, boolean)` | Второй `boolean` — killedByFall. |
| `IsoDeadBody(IsoCell)` | Пустой конструктор для загрузки. Обычно не используется в модах. |

### RandomizedWorldBase.createRandomDeadBody()

Статические методы для создания случайных трупов. **Все методы добавляют труп на клетку автоматически.**

```lua
-- Перегрузки:
RandomizedWorldBase.createRandomDeadBody(RoomDef, skinColor)
-- → IsoDeadBody. Создаёт труп в случайной позиции комнаты.

RandomizedWorldBase.createRandomDeadBody(x, y, z, direction, skinColor)
-- → IsoDeadBody. Создаёт на точных координатах.
-- direction: IsoDirections, skinColor: int

RandomizedWorldBase.createRandomDeadBody(x, y, z, direction, skinColor, persistentOutfitId)
-- → IsoDeadBody. С конкретным outfit ID.

RandomizedWorldBase.createRandomDeadBody(square, direction, skinColor, persistentOutfitId, outfitName)
-- → IsoDeadBody. С именем outfit.
-- square: IsoGridSquare, outfitName: String

RandomizedWorldBase.createRandomDeadBody(x, y, dir_x, dir_y, female, skinColor, persistentOutfitId, outfitName)
-- → IsoDeadBody. С float координатами и направлением.
-- x,y: float, dir_x,dir_y: float, female: boolean
```

### Добавление трупа на клетку

```lua
square:addCorpse(deadBody, sendToClients)
-- deadBody: IsoDeadBody
-- sendToClients: boolean — если true, синхронизирует с клиентами в MP
```

```lua
square:removeCorpse(deadBody, sendToClients)
-- boolean — синхронизировать удаление
```

### Одежда/outfit на трупе

```lua
-- Через IsoGameCharacter (базовый класс):
character:dressInNamedOutfit("Police")       -- одеть в именованный outfit
character:dressInRandomOutfit()              -- случайный outfit
character:dressInPersistentOutfit("name")    -- persistent outfit
character:dressInPersistentOutfitID(id)      -- по ID

-- На уже созданном трупе — только если создан через конструктор с персонажем,
-- т.к. одежда копируется из персонажа при создании.
-- Для createRandomDeadBody — передать outfitName в параметрах.
```

### Инвентарь трупа

```lua
-- IsoDeadBody наследует getContainer() от IsoObject:
local container = deadBody:getContainer()    -- ItemContainer (контейнер трупа)

-- Через IsoGameCharacter (если труп создан из персонажа):
-- IsoGameCharacter:getInventory() → ItemContainer

-- Добавить предмет:
container:AddItem("Base.Axe")

-- В MP — синхронизировать:
if isServer() then
    sendAddItemToContainer(container, item)
end
```

### Ключевые методы IsoDeadBody

| Метод | Возвращает | Описание |
|-------|-----------|----------|
| `isFemale()` | `boolean` | Женский пол |
| `isZombie()` | `boolean` | Был зомби |
| `isSkeleton()` | `boolean` | Скелетизирован |
| `isFakeDead()` / `setFakeDead(bool)` | `boolean` / `void` | "Притворяется мёртвым" |
| `isCrawling()` / `setCrawling(bool)` | `boolean` / `void` | Ползающий |
| `getDeathTime()` / `setDeathTime(float)` | `float` / `void` | Время смерти |
| `getAngle()` | `float` | Угол поворота |
| `setForwardDirection(x, y)` | `void` | Направление тела |
| `getOutfitName()` | `String` | Имя outfit |
| `getWornItems()` | `WornItems` | Надетые вещи |
| `setWornItems(items)` | `void` | Установить надетые вещи |
| `getPrimaryHandItem()` | `InventoryItem` | Предмет в основной руке |
| `setPrimaryHandItem(item)` | `void` | Установить предмет в руку |
| `getSecondaryHandItem()` | `InventoryItem` | Предмет во второй руке |
| `addToWorld()` | `void` | Добавить труп в мир |
| `removeFromWorld()` | `void` | Убрать из мира |
| `reanimateNow()` | `void` | Реанимировать (превратить обратно в зомби) |
| `reanimateLater()` | `void` | Запланировать реанимацию |
| `getDescriptor()` | `SurvivorDesc` | Описание персонажа |

### Синхронизация трупов в MP

```lua
-- Основной способ — через addCorpse с флагом синхронизации:
square:addCorpse(deadBody, true)  -- true = отправить клиентам

-- sendCorpse / sendBecomeCorpse — методы GameServer, ❌ НЕ доступны из Lua.
-- Используйте square:addCorpse(body, true) для синхронизации.
```

---

## 3. Создание и управление зомби (IsoZombie)

**Класс:** `zombie.characters.IsoZombie` — наследник `IsoGameCharacter`.

### createZombie()

```lua
local zombie = createZombie(x, y, z, desc, palette, direction)
-- x, y, z: float — координаты
-- desc: SurvivorDesc — описание (может быть nil)
-- palette: int — палитра скина
-- direction: IsoDirections — направление

-- Возвращает: IsoZombie
-- MP: автоматически синхронизируется (создаётся на сервере, отправляется клиентам)
```

### addZombiesInOutfit()

```lua
-- Простая версия:
local zombies = addZombiesInOutfit(x, y, z, count, outfitName, femaleChance)
-- x, y, z: int — координаты клетки
-- count: int — количество
-- outfitName: String — имя outfit (или nil для случайного)
-- femaleChance: Integer — шанс женского пола (0-100, или nil)
-- Возвращает: ArrayList<IsoZombie> — СПИСОК созданных зомби!

-- Полная версия:
local zombies = addZombiesInOutfit(x, y, z, count, outfitName, femaleChance,
    crawler, isFallOnFront, isFakeDead, knockedDown, health, dontBecomeCorpse, radius)
-- crawler: boolean — ползающий
-- isFallOnFront: boolean — лицом вниз
-- isFakeDead: boolean — притворяется мёртвым
-- knockedDown: boolean — повален
-- health: boolean — (не используется?)
-- dontBecomeCorpse: boolean — не превращается в труп
-- radius: float — радиус спавна

-- Ещё версии с дополнительными параметрами:
addZombiesInOutfit(x,y,z, count, outfit, female, crawler, fallFront, fakeDead,
    knockedDown, health, noCorpse, radius, isSkeleton)
addZombiesInOutfit(x,y,z, count, outfit, female, crawler, fallFront, fakeDead,
    knockedDown, health, noCorpse, radius, isSkeleton, customHealth)
addZombiesInOutfit(x,y,z, count, outfit, female, crawler, fallFront, fakeDead,
    knockedDown, health, noCorpse, radius, isSkeleton, customHealth, dontCallInitVisuals)

-- MP: синхронизируется автоматически.
-- Возвращает ArrayList — можно получить ссылку на каждого зомби!
```

**Можно получить ссылку на созданного зомби:**
```lua
local zombies = addZombiesInOutfit(x, y, z, 1, "Police", nil)
if zombies and zombies:size() > 0 then
    local zombie = zombies:get(0)
    -- теперь можно работать с zombie
end
```

### Убийство зомби программно

```lua
-- Способ 1: через setHealth (рекомендуемый)
zombie:setHealth(0)

-- Способ 2: через Kill на IsoGameCharacter — метод Kill() НЕ найден как публичный.
-- Используйте setHealth(0) — зомби умрёт при следующем обновлении.

-- Способ 3: через Hit
zombie:Hit(weapon, attacker, damage, bIgnoreDamage, modifier, bRemote)
```

### Ключевые методы IsoZombie

| Метод | Возвращает | Описание |
|-------|-----------|----------|
| `dressInRandomOutfit()` | `void` | Случайный outfit |
| `dressInNamedOutfit(name)` | `void` | Конкретный outfit (наследуется от IsoGameCharacter) |
| `dressInPersistentOutfit(name)` | `void` | Persistent outfit |
| `isFemale()` | `boolean` | Женский пол (наследуется) |
| `getModData()` | `KahluaTable` | Мод-данные (наследуется от IsoObject) |
| `getInventory()` | `ItemContainer` | Инвентарь (наследуется от IsoGameCharacter) |
| `getHealth()` / `setHealth(float)` | `float` / `void` | Здоровье (0 = мёртв) |
| `pathToCharacter(character)` | `void` | Идти к персонажу |
| `pathToLocationF(x, y, z)` | `void` | Идти к координатам |
| `getTarget()` / `target` | `IsoMovingObject` | Текущая цель |
| `InitSpritePartsZombie()` | `void` | Инициализация спрайтов |
| `isRemoteZombie()` | `boolean` | Управляется удалённо (MP) |

**Публичные поля (доступны напрямую):**

```lua
zombie.speedType      -- int: скорость (0=sprinter, 1=fast shambler, 2=shambler, 3=random)
zombie.strength       -- int: сила
zombie.cognition      -- int: когнитивность
zombie.memory         -- int: память
zombie.sight          -- int: зрение
zombie.hearing        -- int: слух
zombie.crawling       -- boolean: ползающий
zombie.ghost          -- boolean: призрак (не взаимодействует)
zombie.inactive       -- boolean: неактивный
zombie.target         -- IsoMovingObject: текущая цель
zombie.immortalTutorialZombie  -- boolean: бессмертный
zombie.pendingOutfitName       -- String: отложенный outfit
```

---

## 4. Создание транспорта (BaseVehicle)

**Класс:** `zombie.vehicles.BaseVehicle` — наследник `IsoMovingObject`.

### addVehicleDebug()

```lua
local vehicle = addVehicleDebug(scriptName, direction, skinIndex, square)
-- scriptName: String — имя скрипта (например "Base.PickUpVanLightsPolice")
-- direction: IsoDirections — направление (N, S, E, W, NE, NW, SE, SW)
-- skinIndex: Integer — индекс скина (или nil для случайного)
-- square: IsoGridSquare — клетка для размещения

-- Возвращает: BaseVehicle
-- MP: автоматически синхронизируется!
```

### addVehicle()

```lua
local vehicle = addVehicle(scriptName, x, y, z)
-- Более простой вариант, координаты int
-- MP: синхронизируется автоматически
```

### Работа с частями (VehiclePart)

```lua
local part = vehicle:getPartById("Engine")        -- VehiclePart по ID
local part = vehicle:getPartByIndex(0)             -- VehiclePart по индексу
local count = vehicle:getPartCount()               -- количество частей
local index = vehicle:getPartIndex("Engine")       -- индекс части

-- Состояние части:
local condition = part:getCondition()              -- int (0-100)
part:setCondition(100)                             -- установить состояние

-- Контейнер части (багажник, бардачок):
local container = part:getItemContainer()          -- ItemContainer или nil
local item = part:getInventoryItem()               -- InventoryItem (установленная деталь)
```

### Синхронизация частей в MP

```lua
vehicle:transmitPartCondition(part)       -- синхронизировать состояние части
vehicle:transmitPartItem(part)            -- синхронизировать предмет части
vehicle:transmitPartModData(part)         -- синхронизировать мод-данные части
vehicle:transmitPartUsedDelta(part)       -- синхронизировать использование (топливо и т.д.)
vehicle:transmitPartDoor(part)            -- синхронизировать дверь
vehicle:transmitPartWindow(part)          -- синхронизировать окно
vehicle:transmitEngine()                  -- синхронизировать двигатель
vehicle:transmitRust()                    -- синхронизировать ржавчину
vehicle:transmitColorHSV()                -- синхронизировать цвет
vehicle:transmitBlood()                   -- синхронизировать кровь
```

### Удаление транспорта

```lua
vehicle:permanentlyRemove()  -- полное удаление из мира (синхронизируется в MP)
```

### Другие методы BaseVehicle

| Метод | Возвращает | Описание |
|-------|-----------|----------|
| `getScript()` | `VehicleScript` | Скрипт транспорта |
| `getScriptName()` | `String` | Имя скрипта |
| `addToWorld()` / `addToWorld(sendToClients)` | `void` | Добавить в мир |
| `removeFromWorld()` | `void` | Убрать из мира |
| `isRemovedFromWorld()` | `boolean` | Удалён ли |
| `getSqlId()` | `int` | ID в базе данных |
| `getPartForSeatContainer(seatIndex)` | `VehiclePart` | Часть для сиденья |

---

## 5. Работа с клетками (IsoGridSquare)

**Класс:** `zombie.iso.IsoGridSquare` — одна клетка на карте.

### Получение клетки

```lua
-- Через глобальную функцию (рекомендуется):
local square = getSquare(x, y, z)
-- x, y, z: double → IsoGridSquare или nil (если чанк не загружен)

-- Через IsoCell:
local cell = getCell()
local square = cell:getGridSquare(x, y, z)        -- nil если не загружена
local square = cell:getOrCreateGridSquare(x, y, z) -- создаёт если нет (ОСТОРОЖНО!)
```

**Разница `getGridSquare` vs `getOrCreateGridSquare`:**
- `getGridSquare` — возвращает `nil` если клетка не загружена в память. **Безопасный.**
- `getOrCreateGridSquare` — создаёт клетку если её нет. Может вызвать загрузку чанка. **Используйте осторожно** — может создать "пустую" клетку без тайлов.

### Проверки

| Метод | Возвращает | Описание |
|-------|-----------|----------|
| `isFree(solidFloorOnly)` | `boolean` | Свободна ли клетка от блокирующих объектов. `solidFloorOnly` — требовать твёрдый пол. |
| `isFreeOrMidair(solidFloorOnly)` | `boolean` | Свободна или в воздухе |
| `TreatAsSolidFloor()` | `boolean` | Есть ли твёрдый пол (настоящий или виртуальный, например на лестнице) |
| `HasTree()` | `boolean` | Есть ли дерево |
| `hasBush()` | `boolean` | Есть ли куст |
| `hasGrassLike()` | `boolean` | Есть ли трава |
| `HasStairs()` | `boolean` | Есть ли лестница |
| `haveDoor()` | `boolean` | Есть ли дверь |
| `haveRoof` | `boolean` | Есть крыша (поле, не метод) |
| `has(flagType)` | `boolean` | Проверка флага (IsoFlagType, String, IsoObjectType) |

### Получение объектов

| Метод | Возвращает | Описание |
|-------|-----------|----------|
| `getObjects()` | `PZArrayList<IsoObject>` | **Нет такого метода!** Используйте `getLuaTileObjectList()` |
| `getLuaTileObjectList()` | `KahluaTable` | Lua-таблица всех тайловых объектов |
| `getLuaMovingObjectList()` | `KahluaTable` | Lua-таблица движущихся объектов |
| `getDeadBody()` | `IsoDeadBody` | Первый труп на клетке |
| `getDeadBodys()` | `List<IsoDeadBody>` | Все трупы на клетке |
| `getVehicleContainer()` | `BaseVehicle` | Транспорт на клетке |
| `getWorldObjects()` | `ArrayList<IsoWorldInventoryObject>` | Предметы на земле |
| `getTree()` | `IsoTree` | Дерево на клетке |
| `getBush()` | `IsoObject` | Куст |
| `getBushes()` | `List<IsoObject>` | Все кусты |
| `getGrass()` | `IsoObject` | Трава |
| `getFloor()` | `IsoObject` | Объект пола |
| `getObjectWithSprite(name)` | `IsoObject` | Объект с конкретным спрайтом |
| `getProperties()` | `PropertyContainer` | Свойства клетки |
| `getRoom()` | `IsoRoom` | Комната |
| `getRoomDef()` | `RoomDef` | Определение комнаты |
| `getBuilding()` | `IsoBuilding` | Здание на клетке (или nil) |
| `getModData()` | `KahluaTable` | Мод-данные клетки |

### Предметы на земле

```lua
-- Положить предмет на землю:
local item = square:AddWorldInventoryItem(itemType, x_offset, y_offset, z_offset)
-- itemType: String (например "Base.Axe")
-- x_offset, y_offset, z_offset: float (смещение внутри клетки, обычно 0.0-1.0)
-- Возвращает: InventoryItem

-- С дополнительными параметрами:
square:AddWorldInventoryItem(itemType, x, y, z, count)  -- count штук
square:AddWorldInventoryItem(item, x, y, z)             -- существующий предмет
square:AddWorldInventoryItem(itemType, x, y, z, existingItem)  -- boolean вариант

-- Spawn версии (для рандомизации мира):
square:SpawnWorldInventoryItem(itemType, x, y, z)       -- → InventoryItem
```

**MP:** `AddWorldInventoryItem` синхронизируется автоматически (предметы на земле — `IsoWorldInventoryObject`).

### Трупы

```lua
square:addCorpse(deadBody, sendToClients)
-- deadBody: IsoDeadBody
-- sendToClients: boolean — true = отправить клиентам в MP

square:removeCorpse(deadBody, sendToClients)
-- sendToClients: boolean — true = синхронизировать удаление
```

### Другие операции

```lua
square:DeleteTileObject(obj)              -- удалить тайловый объект
square:transmitRemoveItemFromSquare(obj)  -- удалить + синхронизировать в MP → int (индекс)
square:transmitModdata()                  -- синхронизировать мод-данные клетки
```

### Публичные поля

```lua
square.x   -- int: координата X
square.y   -- int: координата Y
square.z   -- int: этаж (0 = земля)
square.chunk  -- IsoChunk
square.room   -- IsoRoom (или nil)
-- Соседние клетки:
square.n, square.s, square.e, square.w       -- N, S, E, W
square.ne, square.nw, square.se, square.sw   -- диагонали
square.u, square.d                           -- вверх, вниз
```

---

## 6. Работа с контейнерами (ItemContainer)

**Класс:** `zombie.inventory.ItemContainer`

### Конструкторы

```lua
local container = ItemContainer.new()
local container = ItemContainer.new(capacity)
local container = ItemContainer.new(type, square, parent)
-- type: String — тип контейнера (например "crate")
-- square: IsoGridSquare
-- parent: IsoObject
```

### Добавление предметов

| Метод | Возвращает | Описание |
|-------|-----------|----------|
| `AddItem(itemType)` | `InventoryItem` | Добавить по типу. **Возвращает добавленный предмет.** |
| `AddItem(item)` | `InventoryItem` | Добавить существующий предмет. **Возвращает его же.** |
| `AddItem(itemType, float)` | `boolean` | Добавить с шансом (0.0-1.0). Возвращает успех. |
| `addItem(item)` | `InventoryItem` | Синоним AddItem (lowercase). |
| `AddItems(type, count)` | `ArrayList<InventoryItem>` | Добавить несколько. |
| `SpawnItem(type)` | `InventoryItem` | Спавн предмета (для рандомизации). |
| `DoAddItem(item)` | `InventoryItem` | Низкоуровневое добавление (без проверок). |
| `DoAddItemBlind(item)` | `InventoryItem` | Добавление без уведомлений. |

### Удаление/поиск

| Метод | Возвращает | Описание |
|-------|-----------|----------|
| `contains(item)` | `boolean` | Содержит ли предмет |
| `contains(type)` | `boolean` | Содержит ли тип |
| `containsType(type)` | `boolean` | Строгая проверка типа |
| `getNumberOfItem(type)` | `int` | Количество предметов типа |
| `getItemFromTypeRecurse(type)` | `InventoryItem` | Найти предмет рекурсивно |
| `removeItemOnServer(item)` | `void` | Удалить на сервере |
| `addItemOnServer(item)` | `void` | Добавить на сервере |

### Удаление предметов

```lua
container:Remove(item)                     -- удалить предмет из контейнера
-- ⚠️ В MP: сначала sendRemoveItemFromContainer, потом Remove!
```

### Ёмкость

```lua
container:getCapacity()                    -- int
container:setCapacity(capacity)            -- void
container:hasRoomFor(character, item)      -- boolean
container:isFull(character)                -- boolean
container:getFreeCapacity(character)       -- float
container:getEffectiveCapacity(character)  -- int
```

### Синхронизация в MP

```lua
-- Отправка добавленного предмета клиентам (глобальная функция):
sendAddItemToContainer(container, item)
-- ⚠️ ВАЖНО: Крашится если у объекта-родителя нет square!
-- Убедитесь что parent:getSquare() не nil.

-- Удаление предмета (глобальная функция):
sendRemoveItemFromContainer(container, item)
-- ⚠️ ПОРЯДОК: вызывать ДО container:Remove(item)!

-- ⚠️ GameServer НЕ доступен из Lua. Следующие методы существуют в Java,
-- но вызывать их можно только через глобальные обёртки выше:
-- GameServer.sendAddItemToContainer(container, item)       -- ❌ используйте sendAddItemToContainer()
-- GameServer.sendAddItemsToContainer(container, itemList)  -- ❌ нет глобальной обёртки
-- GameServer.sendRemoveItemFromContainer(container, item)  -- ❌ используйте sendRemoveItemFromContainer()
-- GameServer.sendReplaceItemInContainer(container, old, new) -- ❌ нет глобальной обёртки
```

**⚠️ `sendAddItemToContainer` крашит сервер** если `container.parent.square == null`. Это часто бывает если объект создан но не добавлен на клетку, или если клетка выгружена.

### Публичные поля

```lua
container.items     -- ArrayList<InventoryItem>: список предметов
container.type      -- String: тип контейнера
container.capacity  -- int: ёмкость
container.explored  -- boolean: исследован ли
container.id        -- int: ID контейнера
```

---

## 7. Работа с SafeHouse

**Класс:** `zombie.iso.areas.SafeHouse`

### Получение списка

```lua
local list = SafeHouse.getSafehouseList()
-- Возвращает: ArrayList<SafeHouse> — все сейфхаусы на сервере

for i = 0, list:size() - 1 do
    local sh = list:get(i)
    print(sh:getOwner(), sh:getX(), sh:getY(), sh:getX2(), sh:getY2())
end
```

### Координаты

| Метод | Возвращает | Описание |
|-------|-----------|----------|
| `getX()` | `int` | Левая граница X |
| `getY()` | `int` | Верхняя граница Y |
| `getW()` | `int` | Ширина |
| `getH()` | `int` | Высота |
| `getX2()` | `int` | Правая граница (X + W) |
| `getY2()` | `int` | Нижняя граница (Y + H) |
| `containsLocation(x, y)` | `boolean` | Точка внутри сейфхауса (float координаты) |

### Владелец и члены

```lua
local owner = sh:getOwner()              -- String: имя владельца
sh:setOwner(username)                    -- установить владельца
sh:isOwner(player)                       -- boolean (IsoPlayer)
sh:isOwner(username)                     -- boolean (String)

local players = sh:getPlayers()           -- ArrayList<String>: список членов
sh:addPlayer(username)                   -- добавить члена
sh:removePlayer(username)                -- убрать члена
sh:playerAllowed(player)                 -- boolean: разрешён ли доступ (IsoPlayer)
sh:playerAllowed(username)               -- boolean: по имени
```

### Поиск сейфхауса

```lua
-- По клетке:
local sh = SafeHouse.getSafeHouse(square)           -- по IsoGridSquare
local sh = SafeHouse.getSafeHouse(id)               -- по строковому ID
local sh = SafeHouse.getSafeHouse(x, y, w, h)       -- по координатам

-- По владельцу:
local sh = SafeHouse.getSafehouseByOwner(username)   -- по имени владельца
local sh = SafeHouse.hasSafehouse(username)          -- есть ли у игрока (String)
local sh = SafeHouse.hasSafehouse(player)            -- есть ли у игрока (IsoPlayer)

-- Проверка пересечений:
local sh = SafeHouse.getSafehouseOverlapping(x, y, w, h)
local sh = SafeHouse.getSafehouseOverlapping(x, y, w, h, exclude)
```

### Создание/удаление

```lua
local sh = SafeHouse.addSafeHouse(x, y, w, h, ownerName)  -- создать
SafeHouse.removeSafeHouse(sh)                               -- удалить
```

### Проверки доступа

```lua
SafeHouse.isSafehouseAllowTrepass(square, player)   -- boolean
SafeHouse.isSafehouseAllowInteract(square, player)  -- boolean
SafeHouse.isSafehouseAllowLoot(square, player)      -- boolean
SafeHouse.isPlayerAllowedOnSquare(player, square)   -- boolean
```

### Другие методы

```lua
sh:getId()                    -- String: уникальный ID
sh:getTitle() / setTitle(s)   -- String: название
sh:getLocation()              -- String: описание локации
sh:getLastVisited()           -- long: timestamp последнего визита
sh:getDatetimeCreated()       -- long: timestamp создания
sh:getHitPoints()             -- int: очки прочности
sh:setHitPoints(hp)           -- void
sh:getOpenTimer()             -- int: таймер открытия
sh:getPlayerConnected()       -- int: количество онлайн членов
sh:getOnlineID()              -- int: сетевой ID

-- Инвайты:
sh:addInvite(username)
sh:removeInvite(username)
sh:haveInvite(username)       -- boolean

-- Respawn:
sh:setRespawnInSafehouse(enabled, username)  -- boolean, String
sh:isRespawnInSafehouse(username)            -- boolean
```

---

## 8. Сеть и синхронизация

### Доступные классы из Lua

| Класс | Доступен | Как использовать |
|-------|---------|-----------------|
| `GameServer` | **❌ Нет** | Класс НЕ экспонирован в Lua. Используйте глобальные функции-обёртки. |
| `GameClient` | **❌ Нет** | Класс НЕ экспонирован в Lua. |
| `isServer()` | **Да** (глобальная) | Проверка серверной стороны |
| `isClient()` | **Да** (глобальная) | Проверка клиентской стороны |

### sendServerCommand / sendClientCommand

```lua
-- Отправка команды от клиента серверу:
sendClientCommand(module, command, args)
-- module: String — имя модуля (например "SafeZone")
-- command: String — имя команды
-- args: KahluaTable — аргументы (Lua таблица)

sendClientCommand(player, module, command, args)
-- player: IsoPlayer — от чьего имени

-- Отправка команды от сервера клиенту:
sendServerCommand(module, command, args)
-- Отправляет ВСЕМ клиентам

sendServerCommand(player, module, command, args)
-- Отправляет конкретному игроку

-- ⚠️ GameServer НЕ доступен из Lua (nil). Методы ниже — для справки.
-- Используйте глобальные функции sendServerCommand/sendClientCommand.
-- GameServer.sendServerCommand(module, command, args)
-- GameServer.sendServerCommand(module, command, args, connection)
```

### Автоматическая синхронизация

| Тип объекта | Авто-синхронизация | Комментарий |
|------------|-------------------|-------------|
| **BaseVehicle** | **Да** | Полная автосинхронизация при создании через `addVehicleDebug`/`addVehicle` |
| **IsoZombie** | **Частично** | `addZombiesInOutfit` — синхронизирует. `createZombie` — **НЕ синхронизирует** в MP (проверено) |
| **IsoObject** | **Нет** | Требует `transmitCompleteItemToClients()` после добавления на клетку |
| **IsoDeadBody** | **Частично** | `sq:addCorpse(body, true)` — второй параметр отправляет клиентам. `GameServer.sendCorpse()` — ⚠️ НЕ доступен из Lua |
| **IsoWorldInventoryObject** | **Да** | `AddWorldInventoryItem` синхронизирует автоматически |

### Ручная синхронизация

```lua
-- IsoObject (серверная сторона):
obj:transmitCompleteItemToClients()      -- полная синхронизация объекта
obj:transmitUpdatedSpriteToClients()     -- только спрайт
obj:transmitCustomColorToClients()       -- только цвет
obj:sendObjectChange(change, data)       -- отдельное изменение

-- IsoObject (клиентская сторона):
obj:transmitCompleteItemToServer()       -- отправить объект на сервер

-- Обновить визуал контейнера (пустой/полный):
pcall(obj.sendObjectChange, obj, "containers")  -- через pcall для безопасности

-- IsoGridSquare:
square:transmitRemoveItemFromSquare(obj) -- удаление объекта
square:transmitAddObjectToSquare(obj, i) -- добавление объекта
square:transmitModdata()                 -- мод-данные клетки

-- transmitModData (для IsoObject):
-- Нет отдельного метода transmitModData() на IsoObject.
-- Используйте sendObjectChange или transmitCompleteItemToClients.
-- Для клетки: square:transmitModdata()

-- ⚠️ GameServer НЕ доступен из Lua (nil). Используйте глобальные обёртки:
sendAddItemToContainer(container, item)   -- предмет в контейнер (глобальная функция)
sendRemoveItemFromContainer(container, item) -- удаление из контейнера (глобальная функция)
-- GameServer.sendObjectModData(obj)      -- ❌ не работает из Lua
-- GameServer.sendCorpse(deadBody)        -- ❌ не работает из Lua
```

### Шаблон создания синхронизированного объекта в MP

```lua
-- Серверный код:
local square = getSquare(x, y, z)
if square then
    local obj = IsoObject.new(getCell(), square, "my_sprite_name")
    square:AddSpecialObject(obj)

    -- Если нужен контейнер:
    local container = ItemContainer.new("mytype", square, obj)
    obj:setContainer(container)

    -- Добавить предметы:
    local item = container:AddItem("Base.Axe")

    -- Синхронизировать:
    obj:transmitCompleteItemToClients()
end
```

---

## 9. Спрайты и свойства

### IsoSprite

**Класс:** `zombie.iso.sprite.IsoSprite`

```lua
local sprite = obj:getSprite()               -- получить спрайт объекта
local props = sprite:getProperties()         -- PropertyContainer
local name = sprite.tilesetName              -- String (или nil)

-- Проверка свойств спрайта:
sprite:hasProperty(propertyType)             -- boolean (IsoPropertyType)
sprite:hasProperty(name)                     -- boolean (String)
sprite:hasProperty(flagType)                 -- boolean (IsoFlagType)

-- Куст:
sprite.isBush                                -- boolean (публичное поле)
```

### PropertyContainer

**Класс:** `zombie.core.properties.PropertyContainer`

```lua
local props = sprite:getProperties()
-- или:
local props = square:getProperties()

-- Проверка:
props:has(flagType)           -- boolean (IsoFlagType)
props:has(propertyType)       -- boolean (IsoPropertyType)
props:has(name)               -- boolean (String)

-- Получение значения:
local val = props:get(propertyType)    -- String или nil
local val = props:get(name)            -- String или nil

-- Сравнение:
props:propertyEquals(propertyType, value)  -- boolean
props:propertyEquals(name, value)          -- boolean

-- Установка:
props:set(name)                        -- флаг без значения
props:set(propertyType, value)         -- свойство с значением
props:set(name, value)                 -- по имени
props:set(flagType)                    -- IsoFlagType

-- Удаление:
props:unset(name)
props:unset(flagType)

-- Списки:
props:getFlagsList()                   -- ArrayList<IsoFlagType>
props:getPropertyNames()               -- ArrayList<String>

-- Специальные:
props:getSurface()                     -- int: высота поверхности
props:isTable()                        -- boolean: является ли столом
props:isTableTop()                     -- boolean
props:isSurfaceOffset()                -- boolean
```

### Проверка типа объекта (дерево/куст)

```lua
-- Дерево:
if square:HasTree() then
    local tree = square:getTree()  -- IsoTree
end

-- Куст:
if square:hasBush() then
    local bush = square:getBush()
end

-- Через спрайт:
local sprite = obj:getSprite()
if sprite and sprite.isBush then
    -- это куст
end

-- Через свойства:
local props = obj:getSprite():getProperties()
if props:has("tree") then
    -- это дерево
end
```

---

## 10. Утилиты

### Случайные числа

```lua
ZombRand(max)                -- double: случайное число [0, max)
ZombRand(min, max)           -- double: случайное число [min, max)
ZombRandBetween(min, max)    -- double: случайное число [min, max)
ZombRandFloat(min, max)      -- float: случайное число [min, max)
```

### Мир и ячейки

```lua
getCell()                    -- IsoCell: текущая ячейка мира
getWorld()                   -- IsoWorld: мир
getSquare(x, y, z)           -- IsoGridSquare: клетка (или nil)
-- x, y, z: double

-- Через IsoCell:
getCell():getGridSquare(x, y, z)          -- nil если не загружена
getCell():getOrCreateGridSquare(x, y, z)  -- создаёт если нет

-- Границы мира:
getCellMinX(), getCellMaxX()              -- int
getCellMinY(), getCellMaxY()              -- int
getCellSizeInChunks()                     -- Double
getCellSizeInSquares()                    -- Double
```

### Игроки

```lua
getOnlinePlayers()           -- ArrayList<IsoPlayer>: все онлайн игроки
getPlayer()                  -- IsoPlayer: локальный игрок (клиент)
getSpecificPlayer(index)     -- IsoPlayer: по индексу (0-3, split-screen)
getPlayerByOnlineID(id)      -- IsoPlayer: по онлайн ID

-- ⚠️ GameServer НЕ доступен из Lua. Используйте getOnlinePlayers().
-- GameServer.getPlayerByUserName(username)       -- ❌ не работает из Lua
-- GameServer.getPlayerByRealUserName(username)   -- ❌ не работает из Lua
-- GameServer.Players                              -- ❌ не работает из Lua
```

### Время

```lua
local gt = getGameTime()                 -- GameTime

gt:getHour()                             -- int: текущий час (0-23)
gt:getMinutes()                          -- int: минуты
gt:getDay()                              -- int: день
gt:getDayPlusOne()                       -- int: день + 1
gt:getMonth()                            -- int: месяц
gt:getYear()                             -- int: год

gt:getWorldAgeHours()                    -- double: возраст мира в часах
gt:getWorldAgeDaysSinceBegin()           -- double: возраст мира в днях
gt:getHoursSurvived()                    -- double: часы выживания

gt:getDaysSurvived()                     -- int: дни выживания
gt:getNightMin() / getNightMax()         -- float: границы ночи

getTimeInMillis()                        -- long: системное время в ms

-- Через IsoWorld:
getWorld():getWorldAgeDays()             -- float
```

### Чтение файлов

```lua
local reader = getFileReader(path, createIfNotExists)
-- path: String — путь к файлу (относительно Zomboid/Lua/)
-- createIfNotExists: boolean
-- Возвращает: BufferedReader

-- Использование:
local reader = getFileReader("mymod_data.txt", false)
if reader then
    local line = reader:readLine()
    while line do
        -- обработка
        line = reader:readLine()
    end
    reader:close()
end

-- Запись:
local writer = getFileWriter(path, createNew, append)
-- path: String
-- createNew: boolean
-- append: boolean
-- Возвращает: LuaFileWriter

writer:write(text)
writer:writeln(text)  -- с переводом строки
writer:close()

-- Бинарные:
getFileOutput(path)   -- DataOutputStream
getFileInput(path)    -- DataInputStream
```

### IsoDirections

```lua
-- Enum значения:
IsoDirections.N      -- Север
IsoDirections.NW     -- Северо-запад
IsoDirections.W      -- Запад
IsoDirections.SW     -- Юго-запад
IsoDirections.S      -- Юг
IsoDirections.SE     -- Юго-восток
IsoDirections.E      -- Восток
IsoDirections.NE     -- Северо-восток

-- Методы:
IsoDirections.fromString(name)     -- IsoDirections: из строки
IsoDirections.fromIndex(index)     -- IsoDirections: из индекса (0-7)
IsoDirections.fromAngle(vec2)      -- IsoDirections: из Vector2
IsoDirections.fromAngle(x, y)      -- IsoDirections: из координат

dir:RotLeft()                      -- IsoDirections: повернуть влево на 45°
dir:RotRight()                     -- IsoDirections: повернуть вправо на 45°
dir:Rot180()                       -- IsoDirections: развернуть на 180°
```

### instanceof (проверка типа)

```lua
-- Глобальная функция:
instanceof(obj, "IsoZombie")        -- boolean
instanceof(obj, "IsoDeadBody")      -- boolean
instanceof(obj, "BaseVehicle")      -- boolean
instanceof(obj, "IsoPlayer")        -- boolean
instanceof(obj, "IsoObject")        -- boolean

-- Доступна через LuaManager.GlobalObject.instof:
-- В Lua используется как instanceof(obj, className)

-- Получить имя класса:
getClassSimpleName(obj)              -- String: простое имя класса
```

### Другие утилиты

```lua
getRandomUUID()                      -- String: случайный UUID
getFileSeparator()                   -- String: "/" или "\"
isServer()                           -- boolean: серверная сторона
isClient()                           -- boolean: клиентская сторона
isCoopHost()                         -- boolean: хост кооператива

getServerOptions()                   -- ServerOptions
getServerName()                      -- String
getOnlineUsername()                   -- String: имя текущего пользователя

getDirectionTo(character, object)    -- IsoDirections: направление от персонажа к объекту

-- Локализация:
getText("IGUI_MyMod_Text")                      -- String: перевод строки
getText("IGUI_MyMod_Text", arg1, arg2)          -- String: с подстановкой аргументов

-- Проверка уровня доступа:
player:getAccessLevel()                          -- String: "Admin", "Moderator", "", ...
player:getUsername()                              -- String: имя пользователя
player:Say(text)                                 -- void: сообщение в чат над головой
```

### Работа со зданиями (Building/Room API)

```lua
-- Получить здание на клетке:
local building = square:getBuilding()            -- IsoBuilding или nil
local def = building:getDef()                    -- BuildingDef

-- Комнаты в здании:
local rooms = def:getRooms()                     -- ArrayList<RoomDef>
for i = 0, rooms:size() - 1 do
    local roomDef = rooms:get(i)
    local isoRoom = roomDef:getIsoRoom()         -- IsoRoom или nil
    if isoRoom then
        local squares = isoRoom:getSquares()     -- ArrayList<IsoGridSquare>
        for si = 0, squares:size() - 1 do
            local sq = squares:get(si)
            -- работа с клетками комнаты
        end
    end
end
```

### Работа с предметами (InventoryItem)

```lua
local item = container:AddItem("Base.SheetPaper2")
item:setName("My Note")                          -- установить имя
item:setCustomName(true)                         -- пометить как кастомное имя
item:addPage(1, "Text content")                  -- добавить страницу (для записок)
item:getModData().myField = "value"              -- мод-данные
```

---

## 11. События (Events)

### Регистрация обработчиков

```lua
-- Добавить обработчик:
Events.EventName.Add(callbackFunction)

-- Удалить обработчик:
Events.EventName.Remove(callbackFunction)
```

### Серверные тайминговые события

```lua
-- Каждую игровую минуту:
Events.EveryOneMinute.Add(function()
    -- вызывается раз в игровую минуту
end)

-- Каждые 10 игровых минут:
Events.EveryTenMinutes.Add(function()
    -- вызывается раз в 10 игровых минут
end)

-- Каждый игровой час:
Events.EveryHours.Add(function()
    -- вызывается раз в игровой час
end)

-- Каждый день:
Events.EveryDays.Add(function()
end)
```

### OnClientCommand (серверная обработка команд от клиента)

```lua
Events.OnClientCommand.Add(function(module, command, player, args)
    -- module: String — имя модуля
    -- command: String — имя команды
    -- player: IsoPlayer — игрок, отправивший команду
    -- args: KahluaTable — аргументы (Lua таблица)

    if module == "MyMod" and command == "doSomething" then
        local value = args.someKey
        -- обработка
    end
end)
```

### OnServerCommand (клиентская обработка команд от сервера)

```lua
Events.OnServerCommand.Add(function(module, command, args)
    -- module: String
    -- command: String
    -- args: KahluaTable
end)
```

### LoadGridsquare

```lua
Events.LoadGridsquare.Add(function(square)
    -- square: IsoGridSquare
    -- Вызывается когда клетка загружается в память
    -- Используется для модификации мира при загрузке чанков
end)
```

### Другие полезные события

```lua
-- Тик сервера:
Events.OnTick.Add(function()
end)

-- Старт сервера:
Events.OnServerStarted.Add(function()
end)

-- Старт игры (клиент):
Events.OnGameStart.Add(function()
end)

-- Игрок подключился:
Events.OnConnected.Add(function()
end)

-- Создание персонажа:
Events.OnCreatePlayer.Add(function(playerIndex, player)
end)

-- Зомби убит:
Events.OnZombieDead.Add(function(zombie)
end)

-- Объект добавлен:
Events.OnObjectAdded.Add(function(object)
end)

-- Загрузка радио-скриптов:
Events.OnLoadRadioScripts.Add(function(scriptManager, isNewGame)
end)

-- Контекстное меню мировых объектов (клиент):
Events.OnFillWorldObjectContextMenu.Add(function(playerIndex, context, worldobjects, test)
    if test then return end
    -- context:addOption(text, target, callback, ...)
end)
```

### LuaEventManager (Java)

Внутренний механизм. Из Lua не нужно использовать напрямую. Для тригера кастомных событий:

```lua
-- Тригер события:
triggerEvent("MyCustomEvent", arg1, arg2)
```

---

## 12. Радиовещание

### Архитектура

```
ZomboidRadio → RadioScriptManager → RadioChannel → RadioBroadCast → RadioLine
                                  → DynamicRadioChannel
```

### Получение API

```lua
local radio = getZomboidRadio()                          -- ZomboidRadio
local scriptManager = radio:getScriptManager()           -- RadioScriptManager
local radioAPI = getRadioAPI()                           -- RadioAPI
```

### RadioChannel

```lua
-- Создание канала:
local channel = RadioChannel.new(name, frequency, category)
-- name: String — имя канала
-- frequency: int — частота (например 91500 = 91.5 MHz)
-- category: ChannelCategory

local channel = RadioChannel.new(name, frequency, category, guid)

-- Добавление в менеджер:
scriptManager:AddChannel(channel, simulated)
-- simulated: boolean — симулировать прошлые трансляции

-- Удаление:
scriptManager:RemoveChannel(frequency)

-- Поиск:
local channel = scriptManager:getRadioChannel(guid)      -- по GUID
local channels = scriptManager:getChannelsList()         -- все каналы

-- Методы канала:
channel:GetFrequency()                  -- int
channel:GetName()                       -- String
channel:GetCategory()                   -- ChannelCategory
channel:IsTv()                          -- boolean
channel:getAiringBroadcast()            -- RadioBroadCast (текущая трансляция)
channel:setAiringBroadcast(broadcast)   -- установить трансляцию
channel:getLastAiredLine()              -- String
channel:isVanilla()                     -- boolean
channel:getAirCounterMultiplier()       -- float
channel:setAirCounterMultiplier(f)      -- void
```

### RadioBroadCast

```lua
-- Создание:
local broadcast = RadioBroadCast.new(id, startStamp, endStamp)
-- id: String
-- startStamp: int — начало (timestamp)
-- endStamp: int — конец (timestamp)

-- Добавление строк:
broadcast:AddRadioLine(radioLine)

-- Методы:
broadcast:getID()                       -- String
broadcast:getStartStamp()               -- int
broadcast:getEndStamp()                 -- int
broadcast:getLines()                    -- ArrayList<RadioLine>
broadcast:getNextLine()                 -- RadioLine
broadcast:getCurrentLine()              -- RadioLine
broadcast:getCurrentLineNumber()        -- int
broadcast:setCurrentLineNumber(n)       -- void
broadcast:resetLineCounter()            -- void
broadcast:PeekNextLineText()            -- String
```

### RadioLine

```lua
-- Создание:
local line = RadioLine.new(text, r, g, b)
-- text: String — текст сообщения
-- r, g, b: float — цвет текста (0.0-1.0)

local line = RadioLine.new(text, r, g, b, effects)
-- effects: String — эффекты (например "static", "bzzt")

-- Методы:
line:getText()                          -- String
line:setText(text)                      -- void
line:getR(), getG(), getB()             -- float: цвет
line:getAirTime()                       -- float: время эфира
line:setAirTime(time)                   -- void
line:isCustomAirTime()                  -- boolean
line:getEffectsString()                 -- String
```

### RadioAPI утилиты

```lua
-- Конвертация времени в timestamp:
local stamp = RadioAPI.timeToTimeStamp(day, hour, minute)
-- day, hour, minute: int → int (timestamp)

-- Обратная конвертация:
RadioAPI.timeStampToDays(stamp)         -- int
RadioAPI.timeStampToHours(stamp)        -- int
RadioAPI.timeStampToMinutes(stamp)      -- int
```

### ZomboidRadio дополнительные методы

```lua
radio:addChannelName(name, frequency, category)           -- добавить имя канала
radio:addChannelName(name, frequency, category, isCustom) -- с флагом custom
radio:removeChannelName(frequency)                        -- удалить
radio:getChannelName(frequency)                           -- String
radio:GetChannelList(category)                            -- Map<Integer, String>
radio:getRandomFrequency()                                -- int
radio:getRandomFrequency(min, max)                        -- int в диапазоне
```

### DynamicRadioChannel

Наследник `RadioChannel`. Используется для динамических каналов:

```lua
local dynChannel = DynamicRadioChannel.new(name, frequency, category)
```

### Пример: создание радиотрансляции программно

```lua
local radio = getZomboidRadio()
local scriptManager = radio:getScriptManager()
local gt = getGameTime()

-- Получить текущий timestamp:
local currentStamp = RadioAPI.timeToTimeStamp(gt:getDay(), gt:getHour(), gt:getMinutes())

-- Создать канал:
local channel = RadioChannel.new("Emergency", 91500, ChannelCategory.Emergency)
scriptManager:AddChannel(channel, false)

-- Создать трансляцию:
local broadcast = RadioBroadCast.new("emergency_001", currentStamp, currentStamp + 100)

-- Добавить строки:
local line1 = RadioLine.new("Внимание! Экстренное сообщение!", 1.0, 0.0, 0.0)
line1:setAirTime(5.0)
broadcast:AddRadioLine(line1)

local line2 = RadioLine.new("Всем оставаться на местах.", 1.0, 1.0, 1.0)
broadcast:AddRadioLine(line2)

-- Установить трансляцию на канал:
channel:setAiringBroadcast(broadcast)
```

---

## Приложение A: Полезные шаблоны

### Создание объекта с синхронизацией в MP

```lua
function createSyncedObject(x, y, z, spriteName, containerType, capacity)
    local square = getSquare(x, y, z)
    if not square then return nil end

    local obj = IsoObject.new(getCell(), square, spriteName)
    square:AddSpecialObject(obj)

    if containerType then
        local container = ItemContainer.new(containerType, square, obj)
        if capacity then container:setCapacity(capacity) end
        obj:setContainer(container)
    end

    if isServer() then
        obj:transmitCompleteItemToClients()
    end

    return obj
end
```

### Спавн зомби с outfit и получение ссылки

```lua
function spawnZombieWithOutfit(x, y, z, outfitName)
    local zombies = addZombiesInOutfit(x, y, z, 1, outfitName, nil)
    if zombies and zombies:size() > 0 then
        return zombies:get(0)
    end
    return nil
end
```

### Безопасная работа с контейнером в MP

```lua
function addItemToContainerSafe(container, itemType)
    local item = container:AddItem(itemType)
    if item and isServer() then
        sendAddItemToContainer(container, item)  -- глобальная функция, НЕ GameServer.*
    end
    return item
end
```

### Проверка принадлежности к SafeHouse

```lua
function isInAnySafehouse(x, y)
    local list = SafeHouse.getSafehouseList()
    for i = 0, list:size() - 1 do
        local sh = list:get(i)
        if sh:containsLocation(x, y) then
            return sh
        end
    end
    return nil
end
```

---

## Приложение B: Иерархия классов

```
IsoObject
├── IsoMovingObject
│   ├── IsoGameCharacter
│   │   ├── IsoZombie
│   │   ├── IsoPlayer
│   │   └── IsoAnimal
│   ├── IsoDeadBody
│   ├── BaseVehicle
│   └── IsoWorldInventoryObject
├── IsoThumpable
├── IsoWindow
├── IsoDoor
├── IsoTree
└── ...
```

---

> **Примечание:** Данная документация создана на основе декомпиляции Build 42. API может измениться в будущих обновлениях. Не все методы могут быть доступны из Lua — движок использует `LuaManager.Exposer` для экспорта Java классов. Если метод не вызывается из Lua, возможно он не экспонирован.
