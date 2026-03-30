if not isServer() then return end

-- =========================================================================
-- Stats — collect player statistics, store in ModData + CSV
-- =========================================================================

local STATS_FILE = "SafeZone_stats.csv"
local WRITE_INTERVAL_MS = 5 * 60 * 1000 -- записываем CSV раз в 5 минут
local lastWriteTime = 0

local stats = {} -- username -> {zombieKills, survivorKills, hoursSurvived, deaths, perks, ...}

local function log(msg)
    print("[Stats] " .. tostring(msg))
end

-- ----- Load/Save ModData ------------------------------------------------

local function loadStats()
    local modData = getGameTime():getModData()
    local saved = modData["SZStats"]
    if saved and type(saved) == "table" then
        stats = saved
        local count = 0
        for _ in pairs(stats) do count = count + 1 end
        log("Loaded stats for " .. count .. " players")
    else
        stats = {}
        log("No saved stats, starting fresh")
    end
end

local function saveStats()
    getGameTime():getModData()["SZStats"] = stats
end

-- ----- CSV export -------------------------------------------------------

local function writeCSV()
    local writer = getFileWriter(STATS_FILE, true, false)

    -- Header
    writer:write("username;zombieKills;zombieKillsMax;zombieKillsTotal;survivorKills;survivorKillsTotal;hoursSurvived;hoursSurvivedMax;deaths;physical;combat;firearm;crafting;survivalist;farming;lastUpdate\r\n")

    for username, s in pairs(stats) do
        local line = username
            .. ";" .. (s.zombieKills or 0)
            .. ";" .. (s.zombieKillsMax or 0)
            .. ";" .. (s.zombieKillsTotal or 0)
            .. ";" .. (s.survivorKills or 0)
            .. ";" .. (s.survivorKillsTotal or 0)
            .. ";" .. string.format("%.1f", s.hoursSurvived or 0)
            .. ";" .. string.format("%.1f", s.hoursSurvivedMax or 0)
            .. ";" .. (s.deaths or 0)
            .. ";" .. (s.perks and s.perks.physical or 0)
            .. ";" .. (s.perks and s.perks.combat or 0)
            .. ";" .. (s.perks and s.perks.firearm or 0)
            .. ";" .. (s.perks and s.perks.crafting or 0)
            .. ";" .. (s.perks and s.perks.survivalist or 0)
            .. ";" .. (s.perks and s.perks.farming or 0)
            .. ";" .. (s.lastUpdate or 0)
        writer:write(line .. "\r\n")
    end

    writer:close()
end

-- ----- Process player data from client ----------------------------------

local function onPlayerData(player, args)
    if not args then return end
    if not player then return end

    -- Trust server-side player object, not client args
    local username = player:getUsername()
    if not username then return end

    if not player:isAlive() then return end

    local s = stats[username] or {}

    -- Current life stats from server-side player object
    s.zombieKills = player:getZombieKills() or 0
    s.survivorKills = player:getSurvivorKills() or 0
    s.hoursSurvived = player:getHoursSurvived() or 0

    -- All-time records
    s.zombieKillsMax = math.max(s.zombieKillsMax or 0, s.zombieKills)
    s.hoursSurvivedMax = math.max(s.hoursSurvivedMax or 0, s.hoursSurvived)

    -- Cumulative zombie kills (track delta between updates)
    if s._prevZombieKills and args.zombieKills > s._prevZombieKills then
        s.zombieKillsTotal = (s.zombieKillsTotal or 0) + (args.zombieKills - s._prevZombieKills)
    elseif not s._prevZombieKills then
        s.zombieKillsTotal = s.zombieKillsTotal or 0
    end
    s._prevZombieKills = args.zombieKills

    -- Cumulative survivor kills (track delta)
    if s._prevSurvivorKills and args.survivorKills > s._prevSurvivorKills then
        s.survivorKillsTotal = (s.survivorKillsTotal or 0) + (args.survivorKills - s._prevSurvivorKills)
    elseif not s._prevSurvivorKills then
        s.survivorKillsTotal = s.survivorKillsTotal or 0
    end
    s._prevSurvivorKills = args.survivorKills

    -- Perks — accept from client but sanitize (numbers only)
    if args.perks and type(args.perks) == "table" then
        local validKeys = {physical=true, combat=true, firearm=true, crafting=true, survivalist=true, farming=true}
        local sanitized = {}
        for k, v in pairs(args.perks) do
            if validKeys[k] then
                sanitized[k] = math.max(0, math.floor(tonumber(v) or 0))
            end
        end
        s.perks = sanitized
    else
        s.perks = s.perks or {}
    end

    -- Meta — steamID from server
    s.steamID = getSteamIDFromUsername(username) or s.steamID
    s.lastUpdate = os.time()
    s.deaths = s.deaths or 0

    stats[username] = s
    saveStats()
end

-- ----- Player death -----------------------------------------------------

local function onPlayerDeath(player)
    local username = player:getUsername()
    local s = stats[username]
    if not s then return end

    s.deaths = (s.deaths or 0) + 1

    -- Reset current life stats
    s.zombieKills = 0
    s.survivorKills = 0
    s.hoursSurvived = 0
    s._prevZombieKills = nil
    s._prevSurvivorKills = nil

    -- Reset perks
    s.perks = {physical = 0, combat = 0, firearm = 0, crafting = 0, survivalist = 0, farming = 0}

    saveStats()
    log(username .. " died (total deaths: " .. s.deaths .. ")")
end

-- ----- Command handler --------------------------------------------------

local function onClientCommand(module, command, player, args)
    if module ~= "SZStats" then return end

    if command == "playerData" then
        onPlayerData(player, args)
    end
end

-- ----- Periodic CSV write -----------------------------------------------

local function tickWrite()
    local now = getTimestampMs()
    if now - lastWriteTime < WRITE_INTERVAL_MS then return end
    lastWriteTime = now
    writeCSV()
end

-- ----- Init -------------------------------------------------------------

local function onServerStarted()
    loadStats()
    Events.OnClientCommand.Add(onClientCommand)
    Events.OnPlayerDeath.Add(onPlayerDeath)
    log("Stats initialized")
end

Events.OnServerStarted.Add(onServerStarted)
Events.OnTick.Add(tickWrite)
log("Stats module ready")
