local TAG = "[SZ_ConnectLog]"
local LOG_FILE = "SZ_AC/connect_log.txt"

local knownPlayers = {}

local function getTimestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function writeLog(line)
    local writer = getFileWriter(LOG_FILE, true, true)
    if writer then
        writer:writeln(line)
        writer:close()
    end
end

local function checkPlayers()
    local players = getOnlinePlayers()
    if not players then return end

    local currentSet = {}
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        local username = p:getUsername()
        currentSet[username] = true

        if not knownPlayers[username] then
            knownPlayers[username] = true
            local steamId = string.format("%.0f", p:getSteamID())
            local accessLevel = p:getAccessLevel() or ""
            local line = getTimestamp() .. " connect " .. username .. " " .. steamId .. " " .. accessLevel
            writeLog(line)
            print(TAG .. " " .. line)
        end
    end

    for username, _ in pairs(knownPlayers) do
        if not currentSet[username] then
            knownPlayers[username] = nil
            local line = getTimestamp() .. " disconnect " .. username
            writeLog(line)
            print(TAG .. " " .. line)
        end
    end
end

local lastCheck = 0
local CHECK_INTERVAL = 5000

local function onTick()
    local now = getTimestampMs()
    if now - lastCheck < CHECK_INTERVAL then return end
    lastCheck = now
    checkPlayers()
end

if isServer() then
    Events.OnTick.Add(onTick)
    print(TAG .. " Connect logger loaded (polling), file: " .. LOG_FILE)
end
