-- External config for SafeZone mod
-- Copy to ~/Zomboid/Lua/SafeZone_config.lua on the server
-- Only specify parameters you want to override

return {
    SafeZone = {
        BASE_X = 9492,
        BASE_Y = 11190,
        RADIO_FREQUENCY = 95200,
    },
    Events = {
        TTL_HOURS = 0.033,
        AUTO_SPAWN_INTERVAL_MINUTES = 5,
    },
}