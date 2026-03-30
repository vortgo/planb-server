# PlanB Server

Серверная платформа для Project Zomboid (Build 42 MP). PVP сервер с безопасной зоной, системой событий, радиовещанием, стартовыми наборами, библиотекой книг, статистикой, досками объявлений и античитом.

## Структура репозитория

```
planb-server/
├── mods/SafeZone/              # Workshop мод (тонкий клиент)
│   ├── Contents/mods/
│   │   ├── SafeZone/           # Основной мод
│   │   │   ├── common/media/lua/client/
│   │   │   │   ├── Events/             # Клиент событий
│   │   │   │   ├── FuelPump/           # Меню заправки колонок
│   │   │   │   ├── InfiniteGenerator/  # Бесконечные генераторы
│   │   │   │   ├── Library/            # Библиотека книг
│   │   │   │   ├── StarterKit/         # Стартовый набор
│   │   │   │   ├── Stats/              # Сбор статистики
│   │   │   │   ├── Sync/              # Server→Client синхронизация
│   │   │   │   ├── VehicleSpawner/     # Спавнер транспорта
│   │   │   │   └── WelcomeMessage/     # Приветственное окно
│   │   │   ├── common/media/lua/server/
│   │   │   │   └── ScriptLoader/       # Загрузчик серверных скриптов
│   │   │   └── common/media/lua/shared/
│   │   │       ├── SZ_Utils.lua        # Общие утилиты
│   │   │       └── SafeZoneConfig.lua  # Конфиг мода
│   │   └── SC_Boards/          # Мод досок объявлений
│   ├── mod.info
│   ├── preview.png
│   └── workshop_upload.vdf
│
├── server-scripts/             # Серверная логика (скрыта от клиентов)
│   ├── init.lua                # Манифест загрузки
│   ├── event_config.lua        # Конфиг событий (лут, зомби, локации)
│   ├── event_registry.lua      # Реестр типов событий
│   ├── event_utils.lua         # Утилиты (спавн зомби, лут, поиск клеток)
│   ├── event_types.lua         # 6 типов событий
│   ├── event_manager.lua       # Менеджер (автоспавн, TTL, cleanup)
│   ├── event_commands.lua      # Админ-команды (/event)
│   ├── commands.lua            # Файловый command bridge
│   ├── starterkit_config.lua   # Конфиг стартового набора
│   ├── starterkit.lua          # Логика стартового набора
│   ├── note.lua                # Записка новичку
│   ├── radio.lua               # Радиоканал и трансляции
│   ├── fuelpump.lua            # Заправка колонок
│   ├── animals.lua             # AnimalsFix
│   ├── vehicle_spawner.lua     # Спавнер транспорта
│   ├── library.lua             # Библиотека книг (серверная часть)
│   ├── stats.lua               # Статистика игроков
│   ├── admin_board.lua         # Админ-доска объявлений
│   └── anticheat.lua           # Античит (скриншоты)
│
├── config/                     # Примеры конфигов
│   ├── SafeZone_config.example.lua
│   ├── SafeZone_event_messages.example.txt
│   ├── SafeZone_radio_messages.example.txt
│   ├── SafeZone_admin_board.example.txt
│   └── server/                 # Конфиги PZ сервера
│       ├── servertest.ini
│       └── servertest_SandboxVars.lua
│
├── tools/
│   ├── deploy/                 # Скрипты деплоя
│   │   ├── upload.sh           # Upload мода в Workshop
│   │   ├── deploy.sh           # Deploy скриптов/конфигов на сервер
│   │   └── deploy.env.example
│   ├── steam-guard/            # Go: проверка игроков и анти-гриф
│   └── discord/                # Discord webhook скрипты
│       ├── send_rules.sh       # Отправка правил сервера
│       └── send_server_info.py # Отправка/обновление инфо о сервере
│
├── docs/                       # Справочные материалы
│   ├── PZ_LUA_API.md           # Lua API движка PZ (Build 42)
│   └── PZ_MODS_PATTERNS.md    # Паттерны модов из Workshop
│
└── zombie/                     # Java-стабы PZ для IDE (автодополнение)
```

## Архитектура

**Двухуровневая:** тонкий клиент (Workshop мод) + серверные скрипты (скрыты от клиентов).

- **Мод** (`mods/SafeZone/`) — UI, контекстные меню, ScriptLoader, доски объявлений. Публикуется в Steam Workshop.
- **Серверные скрипты** (`server-scripts/`) — вся бизнес-логика. Загружаются ScriptLoader из `~/Zomboid/Lua/SafeZone_scripts/` при старте сервера.
- **Steam Guard** (`tools/steam-guard/`) — Go-утилита: валидация Steam-профилей (часы, Family Sharing, приватность) + анти-гриф (детекция массового разрушения объектов, автокик/бан).

## Локальная разработка

Симлинки для подхвата изменений в PZ:

```bash
# Мод
ln -s ~/projects/planb-server/mods/SafeZone ~/Zomboid/Workshop/SafeZone

# Серверные скрипты
ln -s ~/projects/planb-server/server-scripts ~/Zomboid/Lua/SafeZone_scripts
```

## Деплой

### Настройка

```bash
cp tools/deploy/deploy.env.example tools/deploy/deploy.env
# Заполнить переменные в deploy.env
```

### Upload мода в Workshop

```bash
tools/deploy/upload.sh "описание изменений"
```

### Deploy на сервер

```bash
tools/deploy/deploy.sh all        # Всё
tools/deploy/deploy.sh scripts    # Только скрипты
tools/deploy/deploy.sh config     # Только конфиги
tools/deploy/deploy.sh messages   # Только сообщения
```

## Команды

### В чате (админ)

```
/event spawn <type> [x y]   — спавнить событие
/event list                  — активные события
/event remove <id>           — удалить событие
/event removeall             — удалить все
/event types                 — список типов
/event reload                — перезагрузить конфиг
```

### В серверной консоли (файловый bridge)

```
event spawn <type> x y [z]  — спавнить событие
event list                   — список активных
event remove <id>            — удалить
event removeall              — удалить все
event reload                 — перезагрузить конфиг
resetkit <username>          — сбросить кулдаун стартового набора
radio <freq> <text>          — трансляция в эфир
additem <username> <item> [count] — выдать предмет
servermsg <text>             — сообщение всем
msguser <username> <text>    — личное сообщение
kickdelay <username> <sec> <msg> — кик с задержкой
restore <sprite> <x,y,z>    — восстановить тайл объект
```

### ПКМ (админ)

- **Бензоколонка:** Refill (14000) / Drain
- **Генератор:** Make Infinite / Make Normal
- **Книжная полка:** Mark as Library Shelf / Unmark Library Shelf
- **Земля:** Spawn Vehicle (панель выбора модели, состояния, направления)

## Типы событий

| Тип | Описание | Зомби | Вес автоспавна |
|-----|----------|-------|----------------|
| buildingstash | Тайник в здании | 3-10 | 30 |
| foreststash | Лесной ящик | 3-15 | 20 |
| abandonedvehicle | Брошенная машина | 5-10 | 15 |
| airdrop | Военный аирдроп | 15-20 | 10 |
| camp | Заброшенный лагерь | 10-15 | 10 |
| helicoptercrash | Крушение вертолёта | 20-50 | 5 |

Автоспавн каждые 5 минут, TTL — 0.05 часа, радиус перекрытия событий — 30 клеток.

## Конфигурация

### Внешний конфиг (~/Zomboid/Lua/SafeZone_config.lua)

```lua
return {
    SafeZone = {
        BASE_X = 9492,
        BASE_Y = 11190,
        RADIO_FREQUENCY = 95200,
    },
    Events = {
        TTL_HOURS = 0.05,
        AUTO_SPAWN_INTERVAL_MINUTES = 5,
    },
}
```

### Sandbox Options (через UI игры)

- WelcomeTitle, WelcomeText — попап при входе (F1 для повторного показа)
- WelcomeDiscordURL, WelcomeServerURL — кнопки в попапе
- SC_Boards — настройки досок объявлений

### Внешние файлы

- `~/Zomboid/Lua/SafeZone_event_messages.txt` — сообщения событий для радио
- `~/Zomboid/Lua/SafeZone_radio_messages.txt` — фоновые радио-трансляции
- `~/Zomboid/Lua/SafeZone_admin_board.txt` — контент админ-доски
- `~/Zomboid/Lua/SafeZone_commands.txt` — файл команд (bridge)

## Известные проблемы

- **Кастомная карта** (`Map=SafeZone;Muldraugh, KY`) — ломает рендеринг этажей на dedicated server B42. Решение: `Map=Muldraugh, KY`
- **Workshop кэш** — `appworkshop_108600.acf` может застрять. Удалить файл и рестартнуть
- **WorkshopItems** — ID мода (3683486055) должен быть в списке WorkshopItems в servertest.ini
