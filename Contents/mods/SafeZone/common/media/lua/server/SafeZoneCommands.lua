SafeZoneCommands = {}

SafeZoneCommands.COMMANDS_FILE = "SafeZone_commands.txt"
SafeZoneCommands.handlers = {}

-- ---------------------------------------------------------------------------
-- Logging
-- ---------------------------------------------------------------------------

local function log(msg)
    print("[SafeZoneCmd] " .. tostring(msg))
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function SafeZoneCommands.register(name, fn)
    SafeZoneCommands.handlers[name:lower()] = fn
    log("Registered command: " .. name)
end

-- ---------------------------------------------------------------------------
-- Parsing & execution
-- ---------------------------------------------------------------------------

local function parseLine(line)
    line = line:match("^%s*(.-)%s*$") -- trim
    if line == "" or line:sub(1, 1) == "#" then
        return nil, nil
    end

    local parts = {}
    for token in line:gmatch("%S+") do
        table.insert(parts, token)
    end

    local cmdName = table.remove(parts, 1):lower()
    return cmdName, parts
end

local function execute(cmdName, args)
    local handler = SafeZoneCommands.handlers[cmdName]
    if not handler then
        log("Unknown command: " .. cmdName)
        return
    end

    local ok, err = pcall(handler, args)
    if ok then
        log("Executed: " .. cmdName)
    else
        log("Error in '" .. cmdName .. "': " .. tostring(err))
    end
end

-- ---------------------------------------------------------------------------
-- File processing
-- ---------------------------------------------------------------------------

local function processFile()
    local reader = getFileReader(SafeZoneCommands.COMMANDS_FILE, true)
    if not reader then return end

    local lines = {}
    local line = reader:readLine()
    while line ~= nil do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()

    -- Clear the file immediately
    local writer = getFileWriter(SafeZoneCommands.COMMANDS_FILE, true, false)
    writer:close()

    for _, l in ipairs(lines) do
        local cmdName, args = parseLine(l)
        if cmdName then
            execute(cmdName, args)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Radio utilities (duplicated from SafeZoneRadio — originals are local)
-- ---------------------------------------------------------------------------

local function freqToInt(freqStr)
    local num = tonumber(freqStr)
    if not num then return nil end
    return math.floor(num * 1000 + 0.5)
end

local function findChannelByFreq(freqInt)
    if not DynamicRadio or not DynamicRadio.cache then return nil end
    for _, channel in pairs(DynamicRadio.cache) do
        if channel:GetFrequency() == freqInt then
            return channel
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Built-in commands
-- ---------------------------------------------------------------------------

-- resetkit <username>
SafeZoneCommands.register("resetkit", function(args)
    if #args < 1 then
        log("resetkit: missing username")
        return
    end
    local username = args[1]
    if StarterKitServer and StarterKitServer.resetKit then
        StarterKitServer.resetKit(username)
    else
        log("resetkit: StarterKitServer not available")
    end
end)

-- radio <freq> <text...>
SafeZoneCommands.register("radio", function(args)
    if #args < 2 then
        log("radio: usage — radio <freq> <text>")
        return
    end

    local freqInt = freqToInt(args[1])
    if not freqInt then
        log("radio: invalid frequency — " .. tostring(args[1]))
        return
    end

    local channel = findChannelByFreq(freqInt)
    if not channel then
        log("radio: channel not found for freq " .. args[1])
        return
    end

    local text = table.concat(args, " ", 2)
    local bc = RadioBroadCast.new("SZ-CMD-" .. tostring(ZombRand(100000, 999999)), -1, -1)
    bc:AddRadioLine(RadioLine.new("<bzzt>", 0.5, 0.5, 0.5))
    bc:AddRadioLine(RadioLine.new(text, 1.0, 0.8, 0.2))
    bc:AddRadioLine(RadioLine.new("<fzzt>", 0.5, 0.5, 0.5))
    channel:setAiringBroadcast(bc)

    log("radio: broadcast on " .. args[1] .. " MHz — " .. text)
end)

-- additem <username> <itemID> [count]
SafeZoneCommands.register("additem", function(args)
    if #args < 2 then
        log("additem: usage — additem <username> <itemID> [count]")
        return
    end

    local username = args[1]
    local itemID = args[2]
    local count = tonumber(args[3]) or 1

    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p:getUsername():lower() == username:lower() then
            local inv = p:getInventory()
            for _ = 1, count do
                inv:AddItem(itemID)
            end
            log("additem: gave " .. count .. "x " .. itemID .. " to " .. username)
            return
        end
    end
    log("additem: player not found — " .. username)
end)

-- servermsg <text...>
SafeZoneCommands.register("servermsg", function(args)
    if #args < 1 then
        log("servermsg: missing text")
        return
    end
    local text = table.concat(args, " ")
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        p:Say("[Server] " .. text)
    end
    log("servermsg: " .. text)
end)

-- msguser <username> <text...>
-- Sends personal message to specific player via SZ_AC client handler
SafeZoneCommands.register("msguser", function(args)
    if #args < 2 then
        log("msguser: usage — msguser <username> <message...>")
        return
    end
    local username = args[1]
    local text = table.concat(args, " ", 2)
    local players = getOnlinePlayers()
    if not players then return end
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p:getUsername():lower() == username:lower() then
            sendServerCommand(p, "SZ_AC", "msg", {text = text})
            log("msguser: sent to " .. username .. " — " .. text)
            return
        end
    end
    log("msguser: player not found — " .. username)
end)

-- kickdelay <username> <seconds> <message...>
-- Sends message to player, then kicks after delay
local pendingKicks = {}

SafeZoneCommands.register("kickdelay", function(args)
    if #args < 3 then
        log("kickdelay: usage — kickdelay <username> <seconds> <message...>")
        return
    end

    local username = args[1]
    local delaySec = tonumber(args[2]) or 10
    local message = table.concat(args, " ", 3)

    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p:getUsername():lower() == username:lower() then
            p:Say("[Server] " .. message)
            table.insert(pendingKicks, {
                username = username,
                kickTime = getTimestampMs() + (delaySec * 1000),
            })
            log("kickdelay: " .. username .. " will be kicked in " .. delaySec .. "s — " .. message)
            return
        end
    end
    log("kickdelay: player not found — " .. username)
end)

local function processPendingKicks()
    local now = getTimestampMs()
    local i = 1
    while i <= #pendingKicks do
        local kick = pendingKicks[i]
        if now >= kick.kickTime then
            local players = getOnlinePlayers()
            for j = 0, players:size() - 1 do
                local p = players:get(j)
                if p:getUsername():lower() == kick.username:lower() then
                    p:disconnect()
                    log("kickdelay: kicked " .. kick.username)
                    break
                end
            end
            table.remove(pendingKicks, i)
        else
            i = i + 1
        end
    end
end

-- ---------------------------------------------------------------------------
-- Hook into game loop
-- ---------------------------------------------------------------------------

local lastProcessTime = 0
local PROCESS_INTERVAL_MS = 5000 -- 5 seconds

local function tickProcessFile()
    local now = getTimestampMs()
    if now - lastProcessTime >= PROCESS_INTERVAL_MS then
        lastProcessTime = now
        processFile()
    end
end

if isServer() then
    Events.OnTick.Add(tickProcessFile)
    Events.OnTick.Add(processPendingKicks)
    log("Command bridge loaded — watching " .. SafeZoneCommands.COMMANDS_FILE)
end
