SafeZoneRadio = {}
SafeZoneRadio.channelUUID = "SZ-EVENTS-001"
SafeZoneRadio.frequency = 95200 -- 95.2 MHz
SafeZoneRadio.messages = {}

local MESSAGES_FILE = "SafeZone_radio_messages.txt"

-------------------------------------------------
-- Загрузка/создание файла сообщений в Zomboid/Lua/
-------------------------------------------------

local function writeDefaultMessages()
    local writer = getFileWriter(MESSAGES_FILE, true, false)
    if not writer then return end
    writer:write("Attention all survivors. Safe zone is operational. Coordinates: 13050, 9750.\n")
    writer:write("Perimeter secured. Supply crates available at the safe zone.\n")
    writer:write("All survivors - head northwest toward the old military base. Walls are holding.\n")
    writer:write("This is SafeZone broadcast. We have shelter, supplies, and defenses. You are not alone.\n")
    writer:write("Patrol reports no breach. Safe zone remains secure. Stay on this frequency for updates.\n")
    writer:close()
    print("[SafeZoneRadio] Created default " .. MESSAGES_FILE .. " in Zomboid/Lua/ folder")
    print("[SafeZoneRadio] Edit this file to customize radio messages (supports Cyrillic/UTF-8)")
end

local function loadMessages()
    local reader = getFileReader(MESSAGES_FILE, true)
    if not reader then
        writeDefaultMessages()
        reader = getFileReader(MESSAGES_FILE, true)
        if not reader then
            print("[SafeZoneRadio] ERROR: cannot read " .. MESSAGES_FILE)
            return
        end
    end

    SafeZoneRadio.messages = {}
    local line = reader:readLine()
    while line do
        line = line:match("^%s*(.-)%s*$") -- trim
        if line ~= "" then
            table.insert(SafeZoneRadio.messages, line)
        end
        line = reader:readLine()
    end
    reader:close()

    print("[SafeZoneRadio] Loaded " .. #SafeZoneRadio.messages .. " radio messages from " .. MESSAGES_FILE)
end

-------------------------------------------------
-- Радиоканал
-------------------------------------------------

function SafeZoneRadio.OnLoadRadioScripts(_scriptManager, _isNewGame)
    local channel = DynamicRadioChannel.new(
        "SafeZone Events",
        SafeZoneRadio.frequency,
        ChannelCategory.Amateur,
        SafeZoneRadio.channelUUID
    )
    channel:setAirCounterMultiplier(1.0)
    _scriptManager:AddChannel(channel, false)

    DynamicRadio.cache[SafeZoneRadio.channelUUID] = channel
    table.insert(DynamicRadio.scripts, SafeZoneRadio)

    loadMessages()

    local bc = SafeZoneRadio.CreateBroadcast()
    channel:setAiringBroadcast(bc)
end

function SafeZoneRadio.OnEveryHour(_channel, _gametime, _radio)
    -- обязательный callback для DynamicRadio.scripts (вызывается ванильным ISDynamicRadio)
end

SafeZoneRadio.placeholders = {
    ["{x}"]    = "13050",
    ["{y}"]    = "9750",
    ["{freq}"] = "95.2",
}

local function replacePlaceholders(msg)
    for placeholder, value in pairs(SafeZoneRadio.placeholders) do
        msg = msg:gsub(placeholder, value)
    end
    return msg
end

function SafeZoneRadio.CreateBroadcast()
    local bc = RadioBroadCast.new("SZ-" .. tostring(ZombRand(100000, 999999)), -1, -1)

    bc:AddRadioLine(RadioLine.new("<bzzt>", 0.5, 0.5, 0.5))

    local msgs = SafeZoneRadio.messages
    if #msgs > 0 then
        local msg = replacePlaceholders(msgs[ZombRand(#msgs) + 1])
        bc:AddRadioLine(RadioLine.new(msg, 1.0, 0.8, 0.2))
    end

    bc:AddRadioLine(RadioLine.new("<fzzt>", 0.5, 0.5, 0.5))

    return bc
end

Events.OnLoadRadioScripts.Add(SafeZoneRadio.OnLoadRadioScripts)

-------------------------------------------------
-- Автотрансляция каждые 10 игровых минут
-------------------------------------------------

local function onEveryTenMinutes()
    local channel = DynamicRadio.cache[SafeZoneRadio.channelUUID]
    if not channel then return end

    local bc = SafeZoneRadio.CreateBroadcast()
    channel:setAiringBroadcast(bc)
end

Events.EveryTenMinutes.Add(onEveryTenMinutes)

-------------------------------------------------
-- /radio <freq> <text> — админская команда
-------------------------------------------------

local function freqToInt(freqStr)
    local num = tonumber(freqStr)
    if not num then return nil end
    return math.floor(num * 1000 + 0.5)
end

local function findChannelByFreq(freqInt)
    for uuid, channel in pairs(DynamicRadio.cache) do
        if channel:GetFrequency() == freqInt then
            return channel
        end
    end
    return nil
end

local function onClientCommand(module, command, player, args)
    if module ~= "SafeZoneRadio" then return end

    if command == "broadcast" then
        local level = player:getAccessLevel()
        if level ~= "Admin" and level ~= "admin" then
            print("[SafeZoneRadio] WARN: non-admin " .. player:getUsername() .. " attempted broadcast")
            return
        end

        local freqInt = freqToInt(args.freq)
        if not freqInt then return end

        local channel = findChannelByFreq(freqInt)
        if not channel then
            print("[SafeZoneRadio] Channel not found for freq " .. tostring(args.freq))
            return
        end

        local bc = RadioBroadCast.new("SZ-ADM-" .. tostring(ZombRand(100000, 999999)), -1, -1)
        bc:AddRadioLine(RadioLine.new("<bzzt>", 0.5, 0.5, 0.5))
        bc:AddRadioLine(RadioLine.new(args.text, 1.0, 0.8, 0.2))
        bc:AddRadioLine(RadioLine.new("<fzzt>", 0.5, 0.5, 0.5))

        channel:setAiringBroadcast(bc)
        print("[SafeZoneRadio] Admin " .. player:getUsername() .. " broadcast on " .. args.freq .. " MHz: " .. args.text)
    end
end

Events.OnClientCommand.Add(onClientCommand)
