# Project Zomboid — Система логирования сервера (Build 42)

Справочник по файлам логирования выделенного сервера Project Zomboid.

> **Источник данных:** декомпиляция `projectzomboid.jar` через `jadx`, анализ классов `zombie.debug.*`, `zombie.core.logger.*`, `zombie.network.*`.

---

## Содержание

1. [Архитектура логирования](#1-архитектура-логирования)
2. [Файлы логов](#2-файлы-логов)
3. [Лог `user` — подключения, отключения, смерти](#3-лог-user--подключения-отключения-смерти)
4. [Лог `admin` — действия администраторов](#4-лог-admin--действия-администраторов)
5. [Лог `pvp` — PVP-события](#5-лог-pvp--pvp-события)
6. [Лог `chat` — сообщения чата](#6-лог-chat--сообщения-чата)
7. [Лог `map` — изменения карты](#7-лог-map--изменения-карты)
8. [Лог `item` — операции с предметами](#8-лог-item--операции-с-предметами)
9. [Лог `cmd` — клиентские команды](#9-лог-cmd--клиентские-команды)
10. [Лог `checksum` — верификация файлов](#10-лог-checksum--верификация-файлов)
11. [Лог `DebugLog-server` — консоль](#11-лог-debuglog-server--консоль)
12. [WorldDictionaryLog — предметы мира](#12-worlddictionarylog--предметы-мира)
13. [DebugType — типы отладочных сообщений](#13-debugtype--типы-отладочных-сообщений)
14. [LogSeverity — уровни серьёзности](#14-logseverity--уровни-серьёзности)
15. [Ротация и хранение](#15-ротация-и-хранение)
16. [Настройка логирования в servertest.ini](#16-настройка-логирования-в-servertestini)
17. [Команда /log — управление в рантайме](#17-команда-log--управление-в-рантайме)
18. [Loki-интеграция](#18-loki-интеграция)
19. [Динамические логгеры из Lua](#19-динамические-логгеры-из-lua)
20. [BUG: Сломанное логирование map/item в Build 42](#20-bug-сломанное-логирование-mapitem-в-build-42)

---

## 1. Архитектура логирования

Три уровня:

### DebugLog (`zombie.debug.DebugLog`)

Основная система. Перехватывает `System.out`/`System.err`, форматирует и пишет во все назначения (файл, консоль, Loki).

### ZLogger (`zombie.core.logger.ZLogger`)

Файловый логгер. Каждый именованный логгер пишет в отдельный файл:
```
~/Zomboid/Logs/{startup_timestamp}_{name}.txt
```

Максимальный размер файла — **10 МБ** (`s_maxSizeKo = 10000`). При превышении файл обнуляется.

### LoggerManager (`zombie.core.logger.LoggerManager`)

Менеджер логгеров. При старте сервера **перемещает старые логи** в папку `logs_{date}/`. Создаёт логгеры по имени:

```java
LoggerManager.getLogger("user").write("message");
LoggerManager.getLogger("admin").write("message", "IMPORTANT");
```

---

## 2. Файлы логов

Все файлы создаются в `~/Zomboid/Logs/`.

| Имя логгера | Файл | Что логирует |
|---|---|---|
| `user` | `{ts}_user.txt` | Подключения, отключения, смерти, античит |
| `admin` | `{ts}_admin.txt` | Все действия администраторов |
| `pvp` | `{ts}_pvp.txt` | PVP-удары, убийства, переключение safety |
| `chat` | `{ts}_chat.txt` | Все сообщения чата |
| `map` | `{ts}_map.txt` | Изменения объектов на карте, ошибки чанков |
| `item` | `{ts}_item.txt` | Перемещение предметов в/из контейнеров |
| `cmd` | `{ts}_cmd.txt` | Клиентские команды (фильтруемые) |
| `checksum` | `{ts}_checksum.txt` | Несовпадения чексумм файлов |
| `checksum-{connID}` | `{ts}_checksum-{connID}.txt` | Чексуммы конкретного игрока |
| `DebugLog-server` | `{ts}_DebugLog-server.txt` | Весь вывод консоли |

`{ts}` — timestamp старта сервера (`ZomboidFileSystem.getStartupTimeStamp()`).

---

## 3. Лог `user` — подключения, отключения, смерти

**Источники:** `LoginPacket`, `GoogleAuthKeyPacket`, `GameServer`, `UdpEngine`, `LoginQueue`, `IsoGameCharacter`, `BodyDamage`, `AntiCheat`, `EquipPacket`, `EvolvedRecipe`, `AddInventoryItemToContainerPacket`

### Подключения

```
{connID} "username" attempting to join
{connID} "username" attempting to join used preferred queue
{connID} "username" allowed to join
{connID} "username" fully connected (x,y,z)
player username loading time was: 1234 ms
```

### Отказы в подключении

```
access denied: user "username" client version (42.0.1) does not match server version (42.0.2)
access denied: user "username" is banned
access denied: user "username" already connected
access denied: user "username" Server is too busy
access denied: user "username" ping is too high
access denied: user "username" reason "..."
```

### Отключения

```
{connID} "username" disconnected player (x,y,z)
Connection disconnect index=N guid=N id=...
Connection delayed disconnect index=N guid=N id=...
```

### Смерти

```
user username died at (x,y,z) (non pvp)
```

### Урон (BodyDamage)

Детализация ранений игрока — тип урона, зона тела, величина.

### Античит

```
[сообщение о подозрительной активности]
```

### Ошибки

```
Error: Dupe item ID for PlayerName (x,y,z)
{connID} equipped unknown item type
```

---

## 4. Лог `admin` — действия администраторов

**Источники:** все классы `zombie.commands.serverCommands.*`, `BanSystem`, `GameServer`, пакеты `AddWarningPointPacket`, `AddUserlogPacket`, `RemoveUserlogPacket`, `BanUnbanUserActionPacket`

### Управление пользователями

```
admin created user username with password ***
admin created user username without password
admin added allowed SteamID 76561198...
admin removed allowed SteamID 76561198...
admin removed user username from whitelist
admin granted admin access level on username
```

### Баны и кики

```
admin banned user username [reason]
admin unbanned user username [reason]
admin banned IP 1.2.3.4(username) [reason]
admin unbanned IP (username) [reason]
admin kicked user username
admin ban voice username
admin unban voice username
```

### Предметы и XP

```
admin added item Base.Axe in username's inventory
admin removed item ... (message)
admin added 500 Strength xp's to username
```

### Телепорт

```
admin teleport to username
admin teleported username1 to username2
admin teleported to 10500,11200,0
```

### Режимы (godmode, noclip, invisible)

```
admin enabled godmode on username
admin disabled godmode on username
admin enabled noclip on username
admin disabled noclip on username
admin enabled invisibility on username
admin disabled invisibility on username
```

### Мир и погода

```
admin created a horde of 50 zombies near 10500,11200    [IMPORTANT]
admin removed zombies near 10500,11200                   [IMPORTANT]
admin did chopper
admin did gunshot
admin started rain
admin stopped rain
admin started thunderstorm
admin stopped weather
admin thunder start
```

### Настройки сервера

```
admin changed option PVP=true
admin reloaded options
admin closed server
```

### Warning points и userlog

```
admin added 5 warning point(s) on username, reason: griefing
admin added log on user username, log: ...
admin removed log on user username, type: Kicked, log: ...
```

---

## 5. Лог `pvp` — PVP-события

**Источник:** `zombie.network.PVPLogTool`

Три типа записей:

```
Safety: "username" (x,y,z) toggled true
Kill: "attacker" (x,y,z) killed "victim" (x,y,z)
Combat: "attacker" (x,y,z) hit "victim" (x,y,z) weapon="Base.Axe" damage=0.5
```

Также дублируется в админ-чат если `PVPLogToolChat=true` в servertest.ini.

---

## 6. Лог `chat` — сообщения чата

**Источники:** `zombie.network.chat.ChatServer`, `WorldMessagePacket`

Логирует **все** сообщения:
- Подключение/отключение игроков к чат-серверу
- Каждое сообщение: `Got message: {msg}`
- Типы: General, Say, Shout, Whisper, Radio, Admin, Server, Faction, Safehouse
- Создание/удаление whisper/faction/safehouse чатов
- Discord-интеграцию
- Бан/кик за badwords

WorldMessage (старое API):
```
{connIndex} "username" A "message text"
```

---

## 7. Лог `map` — изменения карты

> **ВНИМАНИЕ:** В ванильном Build 42 этот лог **не создаётся** из-за бага — см. [раздел 20](#20-bug-сломанное-логирование-mapitem-в-build-42). Требуется патч `RemoveItemFromSquarePacket`.

**Источники:** `IsoChunk`, `ServerChunkLoader`, `ServerMap`, `PlayerDownloadServer`, `AddItemToMapPacket`, `RemoveItemFromSquarePacket`, `AddExplosiveTrapPacket`, `PlayerHitObjectPacket`

### Размещение объектов

```
{connID} "username" added doorframe at 10500.0,11200.0,0.0
{connID} "username" added Base.TrapMolotov at 10500,11200,0
```

### Удаление объектов

```
{connID} "username" removed wallpiece at 10500,11200,0
```

С патчем (connection == null, NetTimedAction path):
```
"server" removed IsoObject (furniture_seating_indoor_02_13) at 8163,11635,1
```

### Разрушение объектов

```
{connID} "username" destroyed WoodWall with Axe at 10500.0,11200.0,0.0
```

### Ошибки чанков

```
Error loading chunk 420,560
Error saving chunk 420,560
[stack trace]
```

---

## 8. Лог `item` — операции с предметами

> **ВНИМАНИЕ:** В ванильном Build 42 этот лог **практически не создаётся** из-за бага — см. [раздел 20](#20-bug-сломанное-логирование-mapitem-в-build-42). Перемещение предметов через `ItemTransactionPacket` не логируется вообще. С патчем логируется только удаление предметов с пола (подбор).

**Источники:** `AddInventoryItemToContainerPacket`, `RemoveInventoryItemFromContainerPacket`, `AddItemToMapPacket`, `RemoveItemFromSquarePacket`, `AddCorpseToMapPacket`

### Контейнеры

В Build 42 перемещение предметов между контейнерами идёт через `ItemTransactionPacket` → `TransactionManager` → `Transaction.update()`, **минуя** `AddInventoryItemToContainerPacket.processServer()`. Логирование **не срабатывает**.

```
# Этот формат НЕ пишется в B42:
{connID} "username" container +3 10500,11200,0 [Base.Axe]
{connID} "username" container -1 10500,11200,0 [Base.Pistol]
```

### Пол

С патчем — только подбор предмета с пола (удаление `IsoWorldInventoryObject`):
```
"server" floor -1 8162,11636,1 [Base.Bricktoys]
```

Бросание предмета на пол идёт через `Transaction.update()` → Lua event `"OnProcessTransaction"/"dropOnFloor"`, **не логируется**.

### Трупы

```
{connID} "username" corpse +1 10500,11200,0
```

---

## 9. Лог `cmd` — клиентские команды

**Источник:** `zombie.network.GameServer`

```
{connID} "username" moduleName.commandName @ 10500,11200,0
```

Фильтруется через `ClientCommandFilter` в servertest.ini. Формат фильтра:
- `-vehicle.*` — не логировать все vehicle-команды
- `+vehicle.damageWindow` — но логировать damageWindow

---

## 10. Лог `checksum` — верификация файлов

**Источник:** `zombie.network.packets.service.ChecksumPacket`

Общий лог:
```
[причина несовпадения][детали чексуммера]
```

На каждого игрока создаётся отдельный логгер `checksum-{connectionID}`:
```
[причина несовпадения]
```

---

## 11. Лог `DebugLog-server` — консоль

**Источник:** `zombie.debug.DebugLog`

Весь вывод `System.out`/`System.err` + все `DebugLog.*` вызовы. Формат строки:

```
{severity}{type, 12 chars} f:{frameNo}, t:{timestamp_ms}, st:{server_time}> {class.method, 36 chars}> {message}
```

Пример:
```
LOG  : General      f:1234, t:1711900000, st:5,000> GameServer.main> Server started
```

Префиксы severity: `LOG  :`, `WARN :`, `ERROR:`, `DEBUG:`, `TRACE:`, `NOISE:`.

---

## 12. WorldDictionaryLog — предметы мира

**Источник:** `zombie.world.logger.WorldDictionaryLogger`

Сохраняется **в директорию сейва** (не в `~/Zomboid/Logs/`), формат — Lua-таблица.

Логирует:
- Регистрацию новых предметов (`register`)
- Удаление предметов (`obsolete`)
- Смену modID предметов (`modIdChanged`)
- Изменение версий скриптов (`scriptVersionChanged`)

Файл: `{save_dir}/WorldDictionaryLog.lua`

---

## 13. DebugType — типы отладочных сообщений

Enum `zombie.debug.DebugType` определяет 50+ типов. Ключевые для сервера:

| Тип | Описание |
|---|---|
| `General` | Общие сообщения |
| `Lua` | Lua-скрипты |
| `Mod` | Моды |
| `Multiplayer` | Мультиплеер |
| `Network` | Сетевой уровень |
| `Combat` | Боевая система |
| `Damage` | Урон |
| `Death` | Смерти |
| `Vehicle` | Транспорт |
| `Zombie` | Зомби |
| `Animal` | Животные |
| `Checksum` | Чексуммы |
| `Statistic` | Статистика |
| `MapLoading` | Загрузка карты |
| `Recipe` | Рецепты |
| `Clothing` | Одежда |
| `ActionSystem` | Система действий |
| `IsoRegion` | Регионы |
| `FileIO` | Файловый ввод/вывод |
| `Radio` | Радио |
| `Objects` | Объекты мира |

---

## 14. LogSeverity — уровни серьёзности

Enum `zombie.debug.LogSeverity`:

```
Trace → Noise → Debug → General → Warning → Error → Off
```

**Дефолты при инициализации сервера:**

| DebugType | Уровень |
|---|---|
| Все типы (сервер) | `Warning` |
| `General` | `General` |
| `Lua` | `General` |
| `Mod` | `General` |
| `Multiplayer` | `General` |
| `Network` | `Error` (только ошибки) |

---

## 15. Ротация и хранение

### ZLogger

Максимальный размер файла: **10 МБ**. При превышении файл **обнуляется** (не ротируется, не переименовывается).

### LoggerManager (при старте сервера)

Все `.txt` файлы из `~/Zomboid/Logs/` перемещаются в `logs_{date}/`.

### ZipLogs

Архивирует `console.txt`, `server-console.txt`, `coop-console.txt`, `DebugLog.txt` в `logs.zip`. Хранит до **5 копий** внутри архива.

### LimitSizeFileOutputStream

Потоковый вариант — при превышении лимита обнуляет файл и пишет заново (используется для raw-консоли).

---

## 16. Настройка логирования в servertest.ini

```ini
# PVP логирование
PVPLogToolChat=true          # Дублировать PVP-события в админ-чат
PVPLogToolFile=true          # Писать PVP-события в файл pvp.txt

# Действия клиентов (какие Lua-действия логировать)
ClientActionLogs=ISEnterVehicle;ISExitVehicle;ISTakeEngineParts;

# Перки
PerkLogs=true                # Логирование изменений перков

# Фильтр клиентских команд
# -pattern = не логировать, +pattern = логировать
ClientCommandFilter=-vehicle.*;+vehicle.damageWindow;+vehicle.fixPart;+vehicle.installPart;+vehicle.uninstallPart
```

---

## 17. Команда /log — управление в рантайме

**Источник:** `zombie.commands.serverCommands.LogCommand`

Позволяет менять уровень логирования DebugType в рантайме:

```
/log                          — показать текущие уровни всех типов
/log Multiplayer Trace        — включить трейсинг мультиплеера
/log Network Warning          — только предупреждения для сети
/log General Off              — отключить общие сообщения
```

Допустимые уровни: `Trace`, `Noise`, `Debug`, `General`, `Warning`, `Error`, `Off`.

---

## 18. Loki-интеграция

Движок поддерживает отправку логов в **Grafana Loki** через встроенный `TinyLoki`.

JVM-параметры:
```
-DlokiUrl=http://loki:3100/loki/api/v1/push
-DlokiUser=username
-DlokiPass=password
```

Лейблы:
- `instance` — идентификатор инстанса
- `service_name` — `pz.server` (для сервера) или `pz.client` (для клиента)

---

## 19. Динамические логгеры из Lua

Lua-код может создавать свои именованные логгеры:

```lua
-- Из LuaManager.java (строка 7242):
LoggerManager.getLogger(loggerName).write(logs)
```

Это позволяет модам писать в собственные лог-файлы через Java API. Файл будет создан по стандартному пути: `~/Zomboid/Logs/{ts}_{loggerName}.txt`.

---

## 20. BUG: Сломанное логирование map/item в Build 42

### Проблема

В Build 42 логи `map` и `item` **не создаются** на выделенном сервере. Это баг в ванильном движке, подтверждённый экспериментально 2026-03-31.

### Корневая причина

В Build 42 действия игроков (кувалда, перемещение предметов) выполняются на сервере через **NetTimedAction** и **ItemTransactionPacket/TransactionManager**, а не через старую систему пакетов.

**Путь кувалды (NetTimedAction):**
```
ISDestroyStuffAction:complete()          — Lua, выполняется на сервере
  → IsoGridSquare.transmitRemoveItemFromSquare()  — Java
    → GameServer.RemoveItemFromMap(obj)            — Java
      → RemoveItemFromSquarePacket.removeItemFromMap(null, x, y, z, index)
                                                     ^^^^ connection = null!
```

В `removeItemFromMap()` логирование защищено проверкой `if (connection != null)`, которая не проходит:
```java
// GameServer.java:2899
RemoveItemFromSquarePacket.removeItemFromMap(null, x, y, z, index);
//                                           ^^^^
// Файл: RemoveItemFromSquarePacket.java:128-137
if (connection != null) {  // <-- НЕ проходит, логирование пропускается
    LoggerManager.getLogger("map").write(...);
}
```

**Путь перемещения предметов (Transaction):**
```
ItemTransactionPacket → TransactionManager.update() → Transaction.update()
```
`Transaction.update()` напрямую перемещает предметы между контейнерами и вызывает `GameServer.RemoveItemFromMap()` (опять с `null`). Пакеты `AddInventoryItemToContainerPacket` / `RemoveInventoryItemFromContainerPacket` отправляются только для синхронизации клиентов, их `processServer()` не вызывается → логирование не срабатывает.

### Что затронуто

| Действие | Лог `map` | Лог `item` | Статус |
|---|---|---|---|
| Кувалда (разбор тайла) | Не пишется | — | **BUG** |
| Удар по объекту (дверь, окно) через `PlayerHitObjectPacket` | Пишется | — | OK (connection передаётся) |
| Подбор предмета с пола | — | Не пишется | **BUG** |
| Бросание предмета на пол | — | Не пишется | **BUG** (другой путь — Lua event) |
| Перемещение между контейнерами | — | Не пишется | **BUG** (Transaction, не пакет) |
| Размещение объекта на карту (`AddItemToMapPacket`) | Пишется | Пишется | OK (клиент отправляет пакет) |

### Патч (proof-of-concept)

Файл: `zombie/network/packets/RemoveItemFromSquarePacket.class`

Изменение в методе `removeItemFromMap()` — убрана проверка `connection != null`, логирование срабатывает всегда:

```java
// БЫЛО:
if (o instanceof IsoWorldInventoryObject) {
    IsoWorldInventoryObject wio = (IsoWorldInventoryObject) o;
    handleRemoveRadio(o, sq);
    if (connection != null) {
        LoggerManager.getLogger("item").write(connection.getIDStr() + " \"" + connection.getUserName() + "\" floor -1 ...");
    }
} else {
    ...
    if (connection != null) {
        LoggerManager.getLogger("map").write(connection.getIDStr() + " \"" + connection.getUserName() + "\" removed ...");
    }
}

// СТАЛО:
String who = connection != null
    ? connection.getIDStr() + " \"" + connection.getUserName() + "\""
    : "\"server\"";
if (o instanceof IsoWorldInventoryObject) {
    IsoWorldInventoryObject wio = (IsoWorldInventoryObject) o;
    handleRemoveRadio(o, sq);
    LoggerManager.getLogger("item").write(who + " floor -1 " + x + "," + y + "," + z + " [" + wio.getItem().getFullType() + "]");
} else {
    ...
    LoggerManager.getLogger("map").write(who + " removed " + name + " at " + x + "," + y + "," + z);
}
```

### Применение патча

```bash
# 1. Бэкап оригинала
cp /home/pzserver/pz-server/java/projectzomboid.jar /home/pzserver/pz-server/java/projectzomboid.jar.bak

# 2. Компиляция (требуется JDK 25, т.к. class format version 69)
javac -cp projectzomboid.jar -d /tmp/pz-patch-out RemoveItemFromSquarePacket.java

# 3. Замена класса в jar
cd /tmp/pz-patch-out
jar uf /home/pzserver/pz-server/java/projectzomboid.jar zombie/network/packets/RemoveItemFromSquarePacket.class

# 4. Перезагрузка сервера
```

### Результат патча (проверено)

```
# map.txt — кувалда:
"server" removed IsoObject (furniture_seating_indoor_02_13) at 8163,11635,1

# item.txt — подбор предмета с пола:
"server" floor -1 8162,11636,1 [Base.Bricktoys]
```

### Ограничения патча

1. **Нет имени игрока** — вместо steamID/username пишется `"server"`, потому что `GameServer.RemoveItemFromMap()` не передаёт connection. Для полного исправления нужно пробрасывать connection/player через всю цепочку: `Transaction.update()` → `GameServer.RemoveItemFromMap()` → `removeItemFromMap()`.
2. **Контейнеры не логируются** — перемещение предметов между контейнерами (инвентарь ↔ ящик) идёт через `Transaction.update()` и не проходит через `removeItemFromMap()` вообще. Для логирования контейнерных операций нужен отдельный патч `Transaction.update()` или `TransactionManager`.
3. **Бросание на пол не логируется** — идёт через Lua event `OnProcessTransaction`/`dropOnFloor`, минуя Java-логирование.
4. **Патч перезатирается при обновлении PZ** — после обновления сервера через SteamCMD нужно применять патч заново. Бэкап оригинала: `projectzomboid.jar.bak`.

### Идеальное исправление (TODO)

Для полного логирования в B42 нужно:
1. Пробросить `UdpConnection` из `Transaction` в `GameServer.RemoveItemFromMap()` → `removeItemFromMap()`
2. Добавить логирование в `Transaction.update()` для контейнерных операций и drop-на-пол
3. Либо: добавить серверный Lua-хук на `OnProcessTransaction` для логирования всех транзакций

---

## Userlog — БД-логирование (SQLite)

Помимо файлового логирования, сервер ведёт записи в SQLite-базе `players.db`, таблица `userlog`:

```sql
CREATE TABLE userlog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT,
    type TEXT,
    text TEXT,
    issuedBy TEXT,
    amount INTEGER,
    lastUpdate TEXT
);
```

### Типы записей (`UserlogType`)

| Тип | Описание |
|---|---|
| `AdminLog` | Действия администраторов |
| `Kicked` | Кики |
| `Banned` | Баны |
| `DupeItem` | Дюп предметов |
| `LuaChecksum` | Несовпадение чексумм Lua |
| `WarningPoint` | Предупреждения |
| `UnauthorizedPacket` | Неавторизованные пакеты |
| `SuspiciousActivity` | Подозрительная активность |

Доступ из серверной консоли: `/checkModsNeedUpdate`, `/players`, просмотр через админ-панель в игре.

---

## Структура файлов на диске

```
~/Zomboid/
├── Logs/
│   ├── {ts}_DebugLog-server.txt    # Основной лог консоли
│   ├── {ts}_user.txt               # Подключения, смерти
│   ├── {ts}_admin.txt              # Действия админов
│   ├── {ts}_pvp.txt                # PVP-события
│   ├── {ts}_chat.txt               # Чат
│   ├── {ts}_map.txt                # Изменения карты
│   ├── {ts}_item.txt               # Предметы
│   ├── {ts}_cmd.txt                # Клиентские команды
│   ├── {ts}_checksum.txt           # Чексуммы
│   ├── {ts}_checksum-{connID}.txt  # Чексуммы по игрокам
│   ├── console.txt                 # Raw-консоль
│   ├── logs.zip                    # Архив предыдущих console.txt
│   └── logs_{date}/                # Архив логов предыдущего запуска
│
├── db/
│   └── {server_name}.db            # SQLite с таблицей userlog
│
└── Saves/Multiplayer/{server_name}/
    └── WorldDictionaryLog.lua      # Лог предметов мира
```
