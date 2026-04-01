# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Язык общения

Общайся на русском языке.

## Обзор проекта

PlanB Server — кастомный сервер Project Zomboid (Build 42 MP) с PvP, безопасной зоной, динамическими событиями, радиовещанием, стартовыми наборами, античитом и аудит-логированием.

**Стек:** Lua 5.1 (игровые скрипты), Go (Steam Guard утилита), Bash (деплой), Python (Discord).

## Архитектура

**Двухуровневая система:**
- **Тонкий клиент** (`mods/SafeZone/`) — Workshop мод, только UI и отображение. Публикуется в Steam Workshop.
- **Серверные скрипты** (`server-scripts/`) — вся бизнес-логика, скрыта от клиентов. Загружается через ScriptLoader.

**Механизм загрузки скриптов:**
1. `SZ_ScriptLoader.lua` (server) запускается на `Events.OnServerStarted`
2. Читает манифест `server-scripts/init.lua` — упорядоченный список файлов для загрузки
3. Каждый скрипт читается через `getFileReader()`, парсится `loadstring()`, выполняется `pcall()`
4. После загрузки скриптов `SafeZoneConfig.loadExternal()` читает конфиги из `~/Zomboid/Lua/`

**Командный мост (file-based):** Сервер каждые 5 секунд читает `SafeZone_commands.txt` для выполнения команд из консоли без RCON.

**Система событий (state machine):** `pending → spawned → visited → pending_cleanup → cleanup`. Автоспавн каждые 5 минут, 6 типов событий с TTL-очисткой.

## Команды разработки

### Деплой серверных скриптов и конфигов
```bash
cd tools/deploy
cp deploy.env.example deploy.env  # заполнить реальные данные
./deploy.sh scripts    # деплой только Lua скриптов
./deploy.sh config     # деплой конфигов сервера
./deploy.sh messages   # деплой текстовых сообщений (радио, события, доска)
./deploy.sh all        # деплой всего
```

### Публикация мода в Steam Workshop
```bash
cd tools/deploy
./upload.sh "описание изменений"
```

### Сборка Steam Guard (Go)
```bash
cd tools/steam-guard
go build -o steam-guard .           # macOS
GOOS=linux GOARCH=amd64 go build -o steam-guard-linux .  # Linux
```

### Локальная разработка
Для тестирования без деплоя используются симлинки:
```bash
ln -s ~/projects/planb-server/mods/SafeZone ~/Zomboid/Workshop/SafeZone
ln -s ~/projects/planb-server/server-scripts ~/Zomboid/Lua/SafeZone_scripts
```

## Ключевые соглашения

- **Конфиги:** файлы `config/*.example.*` — шаблоны. На сервере живут в `~/Zomboid/Lua/` без суффикса `.example`.
- **Манифест скриптов:** при добавлении нового серверного скрипта обязательно добавить его в `server-scripts/init.lua`.
- **Клиентский код мода** не должен содержать игровой логики — только UI и отправка команд серверу.
- **Админ-проверка:** `SZ_Utils.isAdmin(player)` — единый способ проверки админских прав.
- **Общий конфиг:** `SafeZoneConfig` (shared) — единая точка доступа ко всей конфигурации.
- **Серверные скрипты** используют глобальные таблицы (напр. `SZ_EventManager`, `SZ_StarterKit`) — каждая система в своём неймспейсе.
- **Логирование:** `print("[SafeZone] ...")` для серверных логов. Audit logging через `LoggerManager`.

## Структура серверных скриптов

| Система | Файлы |
|---------|-------|
| События | `event_config.lua`, `event_types.lua`, `event_registry.lua`, `event_manager.lua`, `event_utils.lua`, `event_commands.lua` |
| Стартовый набор | `starterkit.lua`, `starterkit_config.lua` |
| Радио | `radio.lua` |
| Статистика | `stats.lua` |
| Античит | `anticheat.lua` |
| Аудит | `audit_log.lua` |
| Консольные команды | `commands.lua` |

## Админ-команды в чате

```
/event spawn <type> [x y]  — спавн события
/event list                — список активных событий
/event remove <id>         — удалить событие
/event reload              — перезагрузить конфиг событий
```

## Java-патчи

`tools/pz-patches/` содержит патчи для `projectzomboid.jar` (Build 42 баги). Инструкции компиляции в `tools/pz-patches/README.md`.
