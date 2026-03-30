SafeZoneConfig = SafeZoneConfig or {}

-- ---------------------------------------------------------------------------
-- Загрузка внешнего конфига из ~/Zomboid/Lua/SafeZone_config.lua
-- Файл не является частью мода — не затирается при обновлении через Steam.
-- Указывайте только те параметры, которые хотите изменить.
-- ---------------------------------------------------------------------------

local function deepMerge(base, override)
    for k, v in pairs(override) do
        if type(v) == "table" and type(base[k]) == "table" then
            local isArray = (#v > 0) or (#base[k] > 0)
            if isArray then
                base[k] = v
            else
                deepMerge(base[k], v)
            end
        else
            base[k] = v
        end
    end
end

local CONFIG_FILE = "SafeZone_config.lua"

function SafeZoneConfig.loadExternal()
    local reader = getFileReader(CONFIG_FILE, false)
    if not reader then
        print("[SafeZoneConfig] No external config (" .. CONFIG_FILE .. "), using defaults")
        return false
    end
    reader:close()

    local r2 = getFileReader(CONFIG_FILE, false)
    local lines = {}
    local line = r2:readLine()
    while line ~= nil do
        table.insert(lines, line)
        line = r2:readLine()
    end
    r2:close()

    local code = table.concat(lines, "\n")
    local fn, err = loadstring(code)
    if not fn then
        print("[SafeZoneConfig] ERROR parsing config: " .. tostring(err))
        return false
    end

    local ok, overrides = pcall(fn)
    if not ok then
        print("[SafeZoneConfig] ERROR executing config: " .. tostring(overrides))
        return false
    end

    if type(overrides) ~= "table" then
        print("[SafeZoneConfig] ERROR: config must return a table")
        return false
    end

    -- Мержим секции
    if overrides.SafeZone then
        deepMerge(SafeZoneConfig, overrides.SafeZone)
    end
    if overrides.Events and EventConfig then
        deepMerge(EventConfig, overrides.Events)
    end

    print("[SafeZoneConfig] External config loaded successfully")
    return true
end

-- ---------------------------------------------------------------------------
-- Дефолтные значения
-- ---------------------------------------------------------------------------

-- Координаты базы (используются в записке, радио-сообщениях)
SafeZoneConfig.BASE_X = 9492
SafeZoneConfig.BASE_Y = 11190

-- Частота радиоканала (в кГц, 95200 = 95.2 MHz)
SafeZoneConfig.RADIO_FREQUENCY = 95200
