EventConfig = EventConfig or {}

-- Время жизни непосещённого события (в реальных часах)
-- TODO: вернуть на 2 после тестов
EventConfig.TTL_HOURS = 0.083 -- ~5 минут для тестирования

-- Радиус proximity-check (в клетках)
EventConfig.VISIT_RADIUS = 30

-- Радиус поиска здания для BuildingStash
EventConfig.BUILDING_SEARCH_RADIUS = 7

-- Радиус поиска свободной клетки
EventConfig.SAFE_SQUARE_RADIUS = 20

-- ---------------------------------------------------------------------------
-- Лут-таблицы
-- chance = вероятность (0..1), min/max = количество
-- ---------------------------------------------------------------------------

EventConfig.Loot = {
    buildingstash = {
        { item = "Base.Axe",              chance = 0.3, min = 1, max = 1 },
        { item = "Base.Shotgun",          chance = 0.15, min = 1, max = 1 },
        { item = "Base.ShotgunShells",    chance = 0.3, min = 2, max = 8 },
        { item = "Base.Bullets9mm",       chance = 0.25, min = 4, max = 12 },
        { item = "Base.FirstAidKit",      chance = 0.4, min = 1, max = 1 },
        { item = "Base.TinnedBeans",      chance = 0.5, min = 1, max = 3 },
        { item = "Base.WaterBottle",      chance = 0.5, min = 1, max = 2 },
        { item = "Base.Hammer",           chance = 0.3, min = 1, max = 1 },
        { item = "Base.Nails",            chance = 0.4, min = 5, max = 20 },
        { item = "Base.Plank",            chance = 0.3, min = 2, max = 5 },
    },
    foreststash = {
        { item = "Base.Axe",              chance = 0.4, min = 1, max = 1 },
        { item = "Base.TinnedBeans",      chance = 0.6, min = 2, max = 4 },
        { item = "Base.WaterBottle",  chance = 0.5, min = 1, max = 2 },
        { item = "Base.Bandage",          chance = 0.5, min = 1, max = 3 },
        { item = "Base.HuntingKnife",     chance = 0.3, min = 1, max = 1 },
    },
    corpswithloot = {
        { item = "Base.Pistol",           chance = 0.2, min = 1, max = 1 },
        { item = "Base.Bullets9mm",       chance = 0.3, min = 4, max = 8 },
        { item = "Base.Bandage",          chance = 0.4, min = 1, max = 2 },
        { item = "Base.Pills",            chance = 0.3, min = 1, max = 1 },
        { item = "Base.Wallet",           chance = 0.2, min = 1, max = 1 },
    },
    airdrop = {
        { item = "Base.AssaultRifle",     chance = 0.2, min = 1, max = 1 },
        { item = "Base.Shotgun",          chance = 0.3, min = 1, max = 1 },
        { item = "Base.ShotgunShells",    chance = 0.5, min = 4, max = 16 },
        { item = "Base.Bullets556",       chance = 0.4, min = 10, max = 30 },
        { item = "Base.FirstAidKit",      chance = 0.5, min = 1, max = 2 },
        { item = "Base.MRE",              chance = 0.6, min = 2, max = 4 },
        { item = "Base.WaterBottle",  chance = 0.5, min = 2, max = 4 },
    },
    abandonedvehicle = {
        { item = "Base.Wrench",           chance = 0.4, min = 1, max = 1 },
        { item = "Base.Screwdriver",      chance = 0.3, min = 1, max = 1 },
        { item = "Base.TinnedBeans",      chance = 0.3, min = 1, max = 2 },
        { item = "Base.WaterBottle",  chance = 0.3, min = 1, max = 1 },
    },
    camp = {
        { item = "Base.TinnedBeans",      chance = 0.6, min = 2, max = 5 },
        { item = "Base.WaterBottle",  chance = 0.5, min = 1, max = 3 },
        { item = "Base.Bandage",          chance = 0.4, min = 1, max = 3 },
        { item = "Base.HuntingKnife",     chance = 0.3, min = 1, max = 1 },
        { item = "Base.Torch",            chance = 0.4, min = 1, max = 1 },
    },
}

-- ---------------------------------------------------------------------------
-- Настройки зомби для типов событий
-- ---------------------------------------------------------------------------

EventConfig.Zombies = {
    buildingstash   = { min = 0, max = 2 },
    foreststash     = { min = 0, max = 3 },
    corpswithloot   = { min = 1, max = 4 },
    airdrop         = { min = 3, max = 8 },
    abandonedvehicle = { min = 0, max = 3 },
    camp            = { min = 2, max = 6 },
}

-- ---------------------------------------------------------------------------
-- Настройки трупа (CorpseWithLoot)
-- ---------------------------------------------------------------------------

EventConfig.Corpse = {
    outfits = {
        "Civilian", "Police", "Bandit", "ArmyHazmat",
    },
    femaleChance = 0.3,
}

-- ---------------------------------------------------------------------------
-- Настройки транспорта (AbandonedVehicle)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Радио-сообщения при спавне события
-- Загружаются из Zomboid/Lua/SafeZone_event_messages.txt
-- Формат: секции [typename], сообщения по одной строке, {x}/{y} — плейсхолдеры
-- ---------------------------------------------------------------------------

EventConfig.EVENT_MESSAGES_FILE = "SafeZone_event_messages.txt"

-- ---------------------------------------------------------------------------
-- Интервал автоспавна (в реальных минутах)
-- ---------------------------------------------------------------------------

EventConfig.AUTO_SPAWN_INTERVAL_MINUTES = 3

-- Типы для автоспавна (закомментируй чтобы исключить из ротации)
EventConfig.AUTO_SPAWN_TYPES = {
    -- "buildingstash",
--     "foreststash",
--     "abandonedvehicle",
    "corpswithloot",
    -- "airdrop",
    -- "camp",
}

-- ---------------------------------------------------------------------------
-- Координаты спавна событий (центры поиска)
-- ---------------------------------------------------------------------------

EventConfig.FOREST_CRATE_SPRITE = "carpentry_01_16"

EventConfig.Locations = {
    buildingstash = {
        {x=10878, y=7138},
        {x=10901, y=7140},
        {x=10732, y=6998},
        {x=10657, y=7188},
        {x=11241, y=6766},
        {x=11243, y=6789},
        {x=11243, y=6807},
        {x=11245, y=6835},
        {x=11242, y=6863},
        {x=11417, y=6874},
        {x=11440, y=6876},
        {x=11499, y=6873},
        {x=11566, y=6880},
        {x=11619, y=6880},
        {x=11673, y=6879},
        {x=11789, y=6860},
        {x=11865, y=6756},
    },
    foreststash = {
        {x=11807, y=7103},
        {x=11840, y=7105},
        {x=11935, y=7126},
        {x=12008, y=7140},
    },
    abandonedvehicle = {
        {x=11708, y=7180},
        {x=11834, y=7181},
        {x=11912, y=7181},
        {x=12019, y=7180},
        {x=12236, y=7139},
        {x=12238, y=7014},
        {x=12253, y=6865},
        {x=12370, y=6639},
    },
    corpswithloot = {
        {x=12103, y=6775},
        {x=11843, y=6673},
        {x=11696, y=6710},
        {x=11624, y=6704},
        {x=11477, y=6694},
        {x=11261, y=6698},
        {x=11262, y=6907},
        {x=11923, y=6712},
    },
    airdrop = {
        {x=11197, y=6983},
        {x=11062, y=6976},
        {x=10956, y=7000},
        {x=10820, y=6844},
        {x=10820, y=6681},
        {x=10656, y=6763},
    },
    camp = {
        {x=11541, y=7899},
        {x=11988, y=7905},
        {x=10194, y=7948},
        {x=9750, y=9825},
        {x=9170, y=9826},
    },
}

-- ---------------------------------------------------------------------------
-- Настройки транспорта (AbandonedVehicle)
-- ---------------------------------------------------------------------------

EventConfig.Vehicle = {
    types = {
        "Base.CarNormal",
        "Base.PickUpTruck",
        "Base.OffRoad",
        "Base.CarLightsPolice",
        "Base.Van",
    },
    -- Состояние: engine 0..100, fuel 0..1, missingTire chance
    condition = {
        engineMin = 0,
        engineMax = 30,
        fuelMin = 0.0,
        fuelMax = 0.1,
        missingTireChance = 0.5,
    },
}
