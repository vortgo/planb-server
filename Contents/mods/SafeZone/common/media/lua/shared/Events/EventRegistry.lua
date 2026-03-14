EventRegistry = EventRegistry or {}
EventRegistry.types = {}

local function log(msg)
    print("[EventRegistry] " .. tostring(msg))
end

--- Регистрация типа события
--- @param name string     уникальное имя (lowercase)
--- @param handler table   { validate, spawn, cleanup, getDescription }
function EventRegistry.register(name, handler)
    local key = name:lower()
    if EventRegistry.types[key] then
        log("WARNING: overwriting type '" .. key .. "'")
    end
    EventRegistry.types[key] = handler
    log("Registered type: " .. key)
end

--- Получение handler по имени
--- @param name string
--- @return table|nil
function EventRegistry.get(name)
    return EventRegistry.types[name:lower()]
end

--- Список зарегистрированных типов
--- @return table  массив имён
function EventRegistry.list()
    local names = {}
    for k, _ in pairs(EventRegistry.types) do
        table.insert(names, k)
    end
    table.sort(names)
    return names
end
