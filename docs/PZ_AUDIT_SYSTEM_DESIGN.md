# PZ Audit System — Дизайн-документ

Система аудита и античита для выделенного сервера Project Zomboid (Build 42 MP).

> **Дата:** 2026-03-31
> **Статус:** Проектирование
> **Приоритет:** Высокий — основа для античита и модерирования

---

## Содержание

1. [Цели](#1-цели)
2. [Категории событий](#2-категории-событий)
3. [Формат данных](#3-формат-данных)
4. [Источники данных и реализуемость](#4-источники-данных-и-реализуемость)
5. [Архитектура](#5-архитектура)
6. [Детальный план по категориям](#6-детальный-план-по-категориям)
7. [Автоматическое обнаружение читов](#7-автоматическое-обнаружение-читов)
8. [Хранение и анализ](#8-хранение-и-анализ)
9. [Атрибуция игрока при удалении объектов](#9-атрибуция-игрока-при-удалении-объектов)
10. [Фазы реализации](#10-фазы-реализации)

---

## 1. Цели

1. **Античит** — обнаружение и реагирование на нелегитимные действия (спидхак, телепорт, дюп, noclip, удалённое удаление объектов)
2. **Модерирование** — понимание кто что сделал (гриф, рейд, лут чужих баз)
3. **Аналитика** — понимание поведения игроков, экономики сервера, популярных зон
4. **Расследование** — возможность восстановить цепочку событий постфактум

---

## 2. Категории событий

### 2.1 Действия игрока
- Крафт (что скрафтил, из чего)
- Чтение книги / журнала
- Приём пищи / лекарств
- Экипировка оружия / одежды
- Фарм (посадка, полив, сбор)
- Рыбалка / ловушки (установка, проверка, улов)
- Готовка (что приготовил, ингредиенты)

### 2.2 Перемещение предметов
- Подбор предмета с пола
- Бросание предмета на пол
- Перемещение между контейнерами (инвентарь ↔ ящик, машина, труп)
- Первое открытие контейнера (лут)

### 2.3 Изменение игрового мира
- Строительство (что построил, где, из чего)
- Разрушение кувалдой
- Разбор мебели / конструкций
- Рубка дерева
- Копание (лопата)
- Размещение / подъём мебели (moveable)
- Удар по объекту (дверь, стена, окно) — кто, чем, урон
- Баррикадирование / снятие баррикад

### 2.4 Перемещение игрока
- Координаты раз в секунду (трек маршрута)
- Вход/выход из здания
- Переход между этажами

### 2.5 Характеристики персонажа
- Изменение перков / XP
- Изменение HP, голода, жажды, усталости
- Получение травм
- Инфекция / болезнь

### 2.6 Боевые события
- PVP-удар: кто, кого, чем, урон, координаты обоих
- Убийство игрока: оружие, расстояние, инвентарь жертвы
- Смерть игрока: причина, координаты, инвентарь на момент смерти

### 2.7 Транспорт
- Сел / вышел из машины
- Хотвайринг
- Сифонирование топлива
- Установка / снятие деталей (двигатель, колёса, дверь)
- Столкновение (с чем, скорость)

### 2.8 Социальные события
- Сейфхаус: заявка, приглашение, кик
- Фракции: создание, вступление, выход

### 2.9 Подозрительная активность
- Спидхак (скорость перемещения выше нормы)
- Телепорт (скачок позиции >50 тайлов за секунду)
- Дюп предметов (появление без легитимного источника)
- Невозможные статы (скачок перка 0→X)
- Reach-хак (взаимодействие >5 тайлов)
- Noclip (координаты внутри solid-тайла)
- Невозможный инвентарь (вес выше максимума, предметы вне лут-таблиц)
- Удалённое удаление объектов (RemoveItemFromSquare без активного action)

### 2.10 Мета / сервер
- Подключение / отключение (IP, steamID, время сессии)
- Ошибки Lua (крэш мода)
- Генератор: вкл/выкл, заправка, взрыв

---

## 3. Формат данных

JSON Lines (`.jsonl`) — одна JSON-строка на событие:

```json
{"ts":1774947309,"cat":"map","act":"destroy","player":"Viki","steam":"76561198034616829","x":8163,"y":11635,"z":1,"target":"WoodWall","sprite":"walls_exterior_01_0","tool":"Sledgehammer"}
{"ts":1774947315,"cat":"item","act":"drop","player":"Viki","steam":"76561198034616829","x":8162,"y":11636,"z":1,"item":"Base.Bricktoys"}
{"ts":1774947320,"cat":"move","act":"pos","player":"Viki","steam":"76561198034616829","x":8165,"y":11638,"z":0}
{"ts":1774947325,"cat":"cheat","act":"speedhack","player":"Hacker","steam":"76561198099999999","x":8200,"y":11700,"z":0,"speed":45.2,"max_allowed":8.0}
```

### Поля

| Поле | Тип | Описание |
|---|---|---|
| `ts` | int | Unix timestamp (секунды) |
| `cat` | string | Категория: `action`, `item`, `map`, `move`, `combat`, `vehicle`, `social`, `cheat`, `meta`, `stats` |
| `act` | string | Действие: `destroy`, `build`, `drop`, `pickup`, `transfer`, `pos`, `hit`, `kill`, `die`, `login`, `logout`, ... |
| `player` | string | Username |
| `steam` | string | SteamID |
| `x`, `y`, `z` | int | Координаты |
| `...` | varies | Дополнительные поля зависят от категории |

---

## 4. Источники данных и реализуемость

### Уровни доверия

| Источник | Надёжность | Описание |
|---|---|---|
| **Server Lua** | Высокая | Код выполняется на сервере, клиент не может подменить |
| **Java events** | Высокая | Серверный Java-код, не контролируется клиентом |
| **Client → sendClientCommand** | Средняя | Клиент может подменить данные, но факт отправки достоверен |
| **Java patch** | Высокая | Надёжно, но хрупко — ломается при обновлении PZ |

### Доступные серверные события (Lua)

| Событие | Параметры | Что ловит |
|---|---|---|
| `OnProcessTransaction` | action, player, item, sourceId, destId, extra | drop, moveable pick/place/scrap |
| `OnObjectAboutToBeRemoved` | object | Разрушение объектов (без player) |
| `OnWeaponHitXp` | player, weapon, hitObject, damage, hitCount | Удар по объекту |
| `OnPlayerDeath` | player | Смерть |
| `OnPlayerConnect` / `OnPlayerDisconnect` | player | Подключение/отключение |
| `OnClientCommand` | module, command, player, args | Все мод-команды от клиента |
| `OnTick` / `EveryOneMinute` | — | Периодические проверки (координаты, статы) |
| `onItemFall` | item | Предмет упал с персонажа |
| `OnContainerUpdate` | object? | Изменение контейнера |
| `OnEquipPrimary/Secondary` | player, item | Экипировка |
| `OnClothingUpdated` | player | Смена одежды |
| `OnPlayerUpdate` | player | Каждый тик для каждого игрока (тяжёлый!) |

### Хуки на TimedAction (server-side через NetTimedAction)

| Action | Что отслеживаем |
|---|---|
| `ISDestroyStuffAction` | Кувалда — player + object |
| `ISDismantleAction` | Разбор — player + object |
| `ISBuildAction` / `ISBuildIsoEntity` | Строительство — player + что + где |
| `ISCraftAction` | Крафт — player + рецепт + результат |
| `ISReadABook` | Чтение — player + книга |
| `ISEatFoodAction` | Еда — player + еда |
| `ISChopTreeAction` | Рубка дерева — player + координаты |
| `ISShovelGround` | Копание — player + координаты |
| `ISGrabItemAction` | Подбор предмета — player + item |
| `ISEnterVehicle` / `ISExitVehicle` | Транспорт — player + vehicle |
| `ISHotwireVehicle` | Хотвайринг — player + vehicle |
| `ISSiphonFuel` | Сифонирование — player + vehicle |
| `ISBarricadeAction` / `ISUnbarricadeAction` | Баррикады — player + object |

### Что требует Java-патч (минимальный)

| Что | Зачем | Сложность |
|---|---|---|
| `RemoveItemFromSquarePacket` | Nearest-player в map/item логах | Уже сделано (1 класс) |
| `Transaction.update()` | Логирование container transfers | 1 класс, но объёмный |

### Что нельзя достоверно отследить без Java-патча

| Действие | Проблема |
|---|---|
| Container transfers (инвентарь ↔ ящик) | `Transaction.update()` не триггерит Lua-событий для обычных трансферов |
| Точная атрибуция `RemoveItemFromSquare` | Connection теряется в `GameServer.RemoveItemFromMap()` |

---

## 5. Архитектура

```
┌─────────────────────────────────────────────────┐
│                PZ Server (Java)                  │
│                                                  │
│  NetTimedAction ──→ ISDestroyStuff:complete()    │
│  Transaction    ──→ item move (no Lua event)     │
│  PacketHandler  ──→ RemoveItemFromSquare         │
│       │                    │                     │
│       ▼                    ▼                     │
│  Lua Events         OnObjectAboutToBeRemoved     │
│       │                    │                     │
└───────┼────────────────────┼─────────────────────┘
        │                    │
        ▼                    ▼
┌─────────────────────────────────────────────────┐
│           audit_log.lua (Server Script)          │
│                                                  │
│  ┌─────────────┐  ┌──────────────┐              │
│  │ Event Hooks  │  │ Action Hooks │              │
│  │ OnProcess..  │  │ ISDestroy..  │              │
│  │ OnWeaponHit  │  │ ISDismant..  │              │
│  │ OnPlayerDea  │  │ ISBuild..    │              │
│  │ OnTick       │  │ ISCraft..    │              │
│  └──────┬──────┘  └──────┬───────┘              │
│         │                │                       │
│         ▼                ▼                       │
│  ┌─────────────────────────────┐                │
│  │     Event Formatter          │                │
│  │  → JSON line per event       │                │
│  └──────────┬──────────────────┘                │
│             │                                    │
│             ▼                                    │
│  ┌─────────────────────────────┐                │
│  │     Writers                  │                │
│  │  → .jsonl file (getFileWr)   │                │
│  │  → LoggerManager (Logs/)     │                │
│  │  → print() (DebugLog/Loki)   │                │
│  └─────────────────────────────┘                │
│                                                  │
│  ┌─────────────────────────────┐                │
│  │     Cheat Detector           │                │
│  │  → speed check (OnTick)      │                │
│  │  → teleport check            │                │
│  │  → action validation         │                │
│  │  → auto-kick / alert         │                │
│  └─────────────────────────────┘                │
└─────────────────────────────────────────────────┘
```

---

## 6. Детальный план по категориям

### 6.1 Действия игрока (`cat: "action"`)

**Реализация:** Хуки на TimedAction `complete()` (server-side, NetTimedAction).

```lua
-- Глобальный флаг: кто сейчас выполняет действие
local activePlayer = nil

local function hookAction(cls, actName, extractFn)
    local orig = cls.complete
    cls.complete = function(self)
        activePlayer = self.character
        emit("action", actName, self.character, extractFn and extractFn(self) or {})
        local result = orig(self)
        activePlayer = nil
        return result
    end
end

-- Примеры хуков:
hookAction(ISCraftAction, "craft", function(self) return {recipe=self.recipe:getName()} end)
hookAction(ISReadABook, "read", function(self) return {book=self.item:getFullType()} end)
hookAction(ISEatFoodAction, "eat", function(self) return {food=self.item:getFullType()} end)
hookAction(ISChopTreeAction, "chop_tree", nil)
```

**Доверие:** Высокое — NetTimedAction выполняется на сервере.

### 6.2 Перемещение предметов (`cat: "item"`)

**Реализация:**
- `OnProcessTransaction` → drop на пол, moveable операции (server Lua, есть player)
- Подбор с пола → `GameServer.RemoveItemFromMap()` → наш Java-патч (nearest player)
- Container transfers → **нет Lua-события**, нужен Java-патч `Transaction.update()` или принять пробел

**Обходной путь для container transfers без Java-патча:**
Периодический снапшот инвентаря (раз в 30 секунд) — сравнение с предыдущим, логирование дельты. Не real-time, но ловит появление/исчезновение предметов.

```lua
local inventorySnapshots = {} -- player -> {itemType -> count}

Events.EveryOneMinute.Add(function()
    for _, player in ipairs(getOnlinePlayers()) do
        local current = snapshotInventory(player)
        local prev = inventorySnapshots[player:getUsername()]
        if prev then
            local diff = diffSnapshots(prev, current)
            for _, change in ipairs(diff) do
                emit("item", change.delta > 0 and "gained" or "lost", player, change)
            end
        end
        inventorySnapshots[player:getUsername()] = current
    end
end)
```

**Доверие:** Высокое (серверная проверка инвентаря).

### 6.3 Изменение мира (`cat: "map"`)

**Реализация:**
- Кувалда → хук `ISDestroyStuffAction:complete()` + `activePlayer` флаг
- Разбор → хук `ISDismantleAction:complete()`
- Строительство → хук `ISBuildAction:complete()` / `ISBuildIsoEntity`
- Удар по объекту → `OnWeaponHitXp` (есть player, weapon, damage)
- Moveable → `OnProcessTransaction` (pick/place/scrap)
- Рубка → хук `ISChopTreeAction:complete()`
- Копание → хук `ISShovelGround:complete()`
- Баррикады → хук `ISBarricadeAction` / `ISUnbarricadeAction`
- Fallback → `OnObjectAboutToBeRemoved` + nearest player для неохваченных случаев

**Доверие:** Высокое (всё через NetTimedAction на сервере).

### 6.4 Перемещение игрока (`cat: "move"`)

**Реализация:** `Events.EveryOneMinute.Add` или OnTick с throttle (раз в секунду):

```lua
local lastPos = {} -- player -> {x, y, z, tick}
local TRACK_INTERVAL_MS = 1000

Events.OnTick.Add(function()
    local now = getTimestampMs()
    for _, player in ipairs(getOnlinePlayers()) do
        local key = player:getUsername()
        local last = lastPos[key]
        if not last or now - last.tick > TRACK_INTERVAL_MS then
            local x, y, z = player:getX(), player:getY(), player:getZ()
            if not last or last.x ~= math.floor(x) or last.y ~= math.floor(y) or last.z ~= math.floor(z) then
                emit("move", "pos", player, {x=x, y=y, z=z})
            end
            lastPos[key] = {x=math.floor(x), y=math.floor(y), z=math.floor(z), tick=now}
        end
    end
end)
```

**Оптимизация:** Писать только при смене тайла, не каждую секунду. Это сильно уменьшит объём.

**Доверие:** Высокое — координаты читаются на сервере из `IsoPlayer`.

### 6.5 Характеристики персонажа (`cat: "stats"`)

**Реализация:** Периодический снапшот (раз в минуту), логирование дельт:

```lua
Events.EveryOneMinute.Add(function()
    for _, player in ipairs(getOnlinePlayers()) do
        local hp = player:getHealth()
        local perks = getAllPerks(player)
        -- сравниваем с предыдущим, логируем изменения
        -- скачок перка 0→10 за минуту → cheat alert
    end
end)
```

**Доверие:** Высокое — данные читаются на сервере из Java-объектов.

### 6.6 Боевые события (`cat: "combat"`)

**Реализация:**
- `OnWeaponHitXp` — удар по объекту (player, weapon, target, damage)
- PVP логирование — уже есть в `PVPLogTool` (Java), пишет в `pvp.txt`
- `OnPlayerDeath` — смерть с координатами
- Дополнительно: хук на PVP hit через vanilla PVPLogTool callbacks или OnClientCommand

**Доверие:** Высокое.

### 6.7 Транспорт (`cat: "vehicle"`)

**Реализация:** Хуки на TimedAction:
- `ISEnterVehicle:complete()` / `ISExitVehicle:complete()`
- `ISHotwireVehicle:complete()`
- `ISSiphonFuel:complete()`
- `ISTakeEngineParts:complete()` / `ISInstallEngineParts:complete()`

Дополнительно — `ClientActionLogs` в servertest.ini уже логирует ISEnterVehicle/ISExitVehicle.

**Доверие:** Высокое (NetTimedAction).

### 6.8 Социальные события (`cat: "social"`)

**Реализация:** Большинство идёт через `sendClientCommand` → `OnClientCommand` на сервере:
- Safehouse: команды faction/safehouse в OnClientCommand
- Фракции: аналогично

**Доверие:** Среднее — команды от клиента, но обрабатываются сервером с проверками.

### 6.9 Мета / сервер (`cat: "meta"`)

**Реализация:**
- `OnPlayerConnect` / `OnPlayerDisconnect` — login/logout
- Генератор: хук на IsoGenerator events или OnTick проверка
- Lua-ошибки: перехват через pcall обёртки

**Доверие:** Высокое.

---

## 7. Автоматическое обнаружение читов

### 7.1 Спидхак

```lua
-- В трекере координат (OnTick):
local dx = newX - lastX
local dy = newY - lastY
local distance = math.sqrt(dx*dx + dy*dy)
local dt = (now - lastTick) / 1000  -- секунды
local speed = distance / dt          -- тайлов/сек

local MAX_SPRINT = 8.0  -- макс скорость спринта
local MAX_VEHICLE = 60.0 -- макс скорость авто

if speed > MAX_VEHICLE then
    emit("cheat", "speedhack", player, {speed=speed, max=MAX_VEHICLE})
    -- auto-kick
end
```

### 7.2 Телепорт

```lua
if distance > 50 and dt < 2 then
    -- 50 тайлов за 2 секунды = телепорт
    emit("cheat", "teleport", player, {from={lastX,lastY}, to={newX,newY}, distance=distance})
end
```

### 7.3 Action validation (remote object removal)

```lua
-- activePlayer флаг из хуков TimedAction
Events.OnObjectAboutToBeRemoved.Add(function(obj)
    if activePlayer then return end -- легитимно
    -- объект удалён вне action → пришло из пакета
    local nearest = findNearest(obj)
    if nearest and distanceTo(nearest, obj) > 5 then
        emit("cheat", "remote_remove", nearest, {distance=dist, object=name})
        -- auto-kick
    end
end)
```

### 7.4 Невозможные статы

```lua
-- В периодической проверке (EveryOneMinute):
if currentPerkLevel - prevPerkLevel > 2 then
    -- скачок >2 уровней за минуту = подозрительно
    emit("cheat", "perk_jump", player, {perk=name, from=prev, to=current})
end
```

### 7.5 Матрица реагирования

| Обнаружение | Уверенность | Реакция |
|---|---|---|
| Спидхак (>60 тайлов/сек) | Высокая | Auto-kick + log |
| Телепорт (>50 тайлов мгновенно) | Высокая | Auto-kick + log |
| Remote object removal (>5 тайлов, нет action) | Высокая | Auto-kick + log |
| Perk jump (>2 за минуту) | Средняя | Log + alert в Discord |
| Невозможный инвентарь | Средняя | Log + alert |
| Noclip (внутри solid) | Средняя | Log + alert (может быть лаг) |

---

## 8. Хранение и анализ

### Файлы

```
~/Zomboid/Lua/
└── SZ_Audit/
    ├── audit_2026-03-31.jsonl       # основной лог событий
    ├── positions_2026-03-31.jsonl   # координаты (отдельно, большой объём)
    └── alerts_2026-03-31.jsonl      # подозрительная активность
```

Ротация по дням. Файл позиций отдельно — он будет самым большим.

### Объём (оценка, 20 игроков онлайн)

| Категория | Событий/мин | Размер/день |
|---|---|---|
| Координаты (при смене тайла) | ~600 | ~50 МБ |
| Действия + предметы + мир | ~100 | ~10 МБ |
| Боевые + транспорт | ~10 | ~1 МБ |
| Алерты | ~1 | <1 МБ |

### Анализ

Для старта:
```bash
# Что делал Viki за последний час:
cat audit_*.jsonl | jq 'select(.player=="Viki")' | tail -100

# Все разрушения в зоне 8100-8200, 11600-11700:
cat audit_*.jsonl | jq 'select(.cat=="map" and .x>=8100 and .x<=8200)'

# Подозрительная активность:
cat alerts_*.jsonl | jq .
```

В будущем: Go-сервис для парсинга + SQLite/ClickHouse + Grafana дашборд.

---

## 9. Атрибуция игрока при удалении объектов

### Проблема

`OnObjectAboutToBeRemoved` — единственное Lua-событие где объект ещё жив и можно снять все данные. Но оно **не содержит информации об игроке**.

При этом данные объекта нужны для **восстановления после грифа** — спрайт, класс, индекс, контейнеры.

### Три пути удаления объекта

```
1. NetTimedAction (легитимно):
   ISDestroyStuffAction:complete() → transmitRemoveItemFromSquare()
   → GameServer.RemoveItemFromMap() → removeItemFromMap(null)
   → OnObjectAboutToBeRemoved(obj)

2. Серверный скрипт (легитимно):
   Lua server code → transmitRemoveItemFromSquare()
   → GameServer.RemoveItemFromMap() → removeItemFromMap(null)
   → OnObjectAboutToBeRemoved(obj)

3. Клиентский пакет (чит или легитимное действие):
   Client → RemoveItemFromSquare packet → processServer(connection)
   → removeItemFromMap(connection, ...) → OnObjectAboutToBeRemoved(obj)
```

### Решение: трёхуровневый флаг

```lua
local activePlayer = nil     -- кто выполняет action
local serverScript = false   -- серверный скрипт выполняется

-- 1. Хукаем все TimedAction которые удаляют объекты
hookAction(ISDestroyStuffAction, "sledgehammer")
hookAction(ISDismantleAction, "dismantle")
-- ...

-- 2. Оборачиваем серверные скрипты (костёр, ловушки, фермерство)
-- Ставим serverScript = true перед вызовами transmitRemove

-- 3. В OnObjectAboutToBeRemoved определяем источник:
Events.OnObjectAboutToBeRemoved.Add(function(obj)
    local data = snapshotObject(obj)  -- полные данные для восстановления

    if activePlayer then
        -- Путь 1: из action хука, знаем точно кто
        data.player = activePlayer:getUsername()
        data.steam = tostring(activePlayer:getSteamID())
        data.source = "action"
    elseif serverScript then
        -- Путь 2: серверный скрипт, не игрок
        data.source = "server"
    else
        -- Путь 3: клиентский пакет или неизвестный путь
        local nearest, dist = findNearestPlayer(obj)
        if nearest and dist <= 3 then
            data.player = nearest:getUsername()
            data.steam = "~" .. tostring(nearest:getSteamID())  -- ~ = эвристика
            data.source = "packet_near"
        elseif nearest and dist > 3 then
            data.player = nearest:getUsername()
            data.steam = "~" .. tostring(nearest:getSteamID())
            data.source = "CHEAT_remote"  -- подозрительно!
        else
            data.source = "unknown"
        end
    end

    writeAudit(data)
end)
```

### Точность атрибуции

| Путь | Источник player | Точность | Пример |
|---|---|---|---|
| NetTimedAction хук | `self.character` | 100% | Кувалда, разбор мебели |
| Серверный скрипт | — (помечаем "server") | 100% | Костёр потух, ловушка |
| Клиентский пакет, игрок рядом (≤3) | nearest player | ~100% | Легитимное действие или локальный чит |
| Клиентский пакет, игрок далеко (>3) | nearest player | ~95% | **CHEAT** — удалённое удаление |
| Клиентский пакет, никого рядом | — | 0% | Phantom removal |

Nearest player на расстоянии ≤3 тайла — фактически 100% точность, потому что `transmitRemoveItemFromSquare` с клиента отправляется при взаимодействии с объектом рядом с игроком.

### Дополнение из Java-патча map.txt

Java-патч `RemoveItemFromSquarePacket` (уже установлен на сервере) пишет в `map.txt` с **точным steamID** для клиентских пакетов:

```
76561198034616829 "Viki" removed IsoObject (furniture_storage_01_32) at 8166,11634,1
```

При необходимости можно склеить `map.txt` и `audit.jsonl` по ключу `sprite + x,y,z + timestamp (±1 сек)` для 100% атрибуции читерских пакетов. Но для большинства случаев Lua-атрибуции через nearest player достаточно.

### Данные для восстановления объектов

В `OnObjectAboutToBeRemoved` объект ещё жив — снимаем полный снапшот:

```lua
local function snapshotObject(obj)
    local data = {
        ts = os.time(),
        cat = "map",
        act = "removed",
        sprite = obj:getSprite() and obj:getSprite():getName() or nil,
        class = obj:getClass() and obj:getClass():getSimpleName() or nil,
        name = obj:getName() or obj:getObjectName() or nil,
        index = obj:getObjectIndex(),
        x = obj:getSquare():getX(),
        y = obj:getSquare():getY(),
        z = obj:getSquare():getZ(),
    }
    -- контейнеры
    if obj:getContainerCount() > 0 then
        data.containers = {}
        for i = 0, obj:getContainerCount() - 1 do
            local c = obj:getContainerByIndex(i)
            table.insert(data.containers, {
                type = c:getType(),
                explored = c:isExplored(),
                looted = c:isHasBeenLooted(),
                capacity = c:getMaxWeight(),
                items = c:getItems():size()
            })
        end
    end
    return data
end
```

### Восстановление и лут-респавн

При восстановлении объектов из лога:

| Тип объекта | Как восстанавливать | Лут-респавн |
|---|---|---|
| Стена, пол (без контейнера) | `IsoObject.new(sq, sprite)` | Не применимо |
| Мебель с контейнером | `IsoObject.new(sq, sprite)` + создать контейнер | Нужно настроить |
| IsoThumpable (построенное игроками) | `IsoThumpable.new(...)` | Исключён из респавна движком |
| IsoDoor | Специальная обработка | Не применимо |

Для контейнеров при восстановлении ставим `explored=true, hasBeenLooted=true` — контейнер ведёт себя как уже залученный, лут появится по обычному серверному таймеру `HoursForLootRespawn`. Это корректное поведение — то же что было бы без разрушения.

**Важно:** `IsoThumpable` (построенное игроками) **исключён из лут-респавна** в движке (строка 124 `LootRespawn.java`). Ванильную мебель нужно восстанавливать как `IsoObject`, не как `IsoThumpable`.

---

## 10. Фазы реализации

### Фаза 1 — MVP

Минимальный рабочий аудит. Чистый Lua, 0 Java-патчей.

- [ ] **Map events с атрибуцией** — хуки ISDestroyStuffAction, ISDismantleAction + OnObjectAboutToBeRemoved + трёхуровневый флаг (activePlayer / serverScript / nearest)
- [ ] **Полный снапшот объекта** в OnObjectAboutToBeRemoved — sprite, class, index, containers (для восстановления)
- [ ] **OnProcessTransaction** — drop, moveable pick/place/scrap
- [ ] **OnWeaponHitXp** — удары по объектам
- [ ] **Player death** — OnPlayerDeath
- [ ] **Login/logout** — OnPlayerConnect/Disconnect
- [ ] **Position tracking** — OnTick с throttle, только при смене тайла
- [ ] **Cheat: speedhack/teleport** — на основе position tracking
- [ ] **Cheat: remote removal** — activePlayer=nil + nearest>3 tiles = alert
- [ ] **JSONL writer** — запись в файлы с ротацией по дням

### Фаза 2 — Расширенный аудит

- [ ] Хуки на действия: craft, read, eat, chop, barricade
- [ ] Хуки на транспорт: enter/exit, hotwire, siphon, parts
- [ ] Inventory snapshots (дельты раз в минуту) — обнаружение дюпа
- [ ] Perk/stats snapshots — обнаружение невозможных скачков
- [ ] Safehouse/faction events через OnClientCommand
- [ ] Alert в Discord webhook при обнаружении чита

### Фаза 3 — Восстановление

- [ ] Скрипт `restore.lua` — восстановление объектов из audit JSONL
- [ ] Фильтрация по области (x1,y1 → x2,y2), времени, игроку
- [ ] Корректная обработка контейнеров (explored=true, hasBeenLooted=true)
- [ ] Различение IsoObject vs IsoThumpable vs IsoDoor при восстановлении
- [ ] Dry-run режим (показать что будет восстановлено, без применения)
- [ ] Склейка с map.txt для точной атрибуции читерских пакетов (если нужна)

### Фаза 4 — Аналитика

- [ ] Go-сервис для приёма и хранения событий
- [ ] SQLite / ClickHouse для запросов
- [ ] Grafana дашборд для модераторов
- [ ] Heatmap перемещений игроков
- [ ] Loki интеграция (если оправдана)

### Фаза 5 — Продвинутый античит

- [ ] Noclip detection (координаты vs solid tiles)
- [ ] Inventory validation (проверка легитимности предметов)
- [ ] Container reach validation
- [ ] Java-патч `Transaction.update()` для полного item tracking (если нужен)
- [ ] Replay система (воспроизведение событий по таймлайну)
