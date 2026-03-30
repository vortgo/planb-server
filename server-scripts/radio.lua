
SafeZoneRadio = {}
SafeZoneRadio.channelUUID = "SZ-EVENTS-001"

local RADIO_MESSAGES_FILE = "SafeZone_radio_messages.txt"
local radioMessages = {}

local function loadRadioMessages()
    local reader = getFileReader(RADIO_MESSAGES_FILE, true)
    if not reader then
        print("[SafeZoneRadio] Radio messages file not found: " .. RADIO_MESSAGES_FILE)
        return
    end

    radioMessages = {}
    local currentSection = nil
    local line = reader:readLine()
    while line do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            local section = line:match("^%[(.+)%]$")
            if section then
                currentSection = section:lower()
                radioMessages[currentSection] = radioMessages[currentSection] or {}
            elseif currentSection then
                table.insert(radioMessages[currentSection], line)
            end
        end
        line = reader:readLine()
    end
    reader:close()

    for sectionName, msgs in pairs(radioMessages) do
        print("[SafeZoneRadio] Loaded " .. #msgs .. " messages for [" .. sectionName .. "]")
    end
end

-------------------------------------------------
-- Радиоканал
-------------------------------------------------

function SafeZoneRadio.init()
    loadRadioMessages()

    local scriptManager = getZomboidRadio():getScriptManager()
    if not scriptManager then
        print("[SafeZoneRadio] ERROR: scriptManager not available")
        return
    end

    local channel = DynamicRadioChannel.new(
        "SafeZone Events",
        SafeZoneConfig.RADIO_FREQUENCY,
        ChannelCategory.Amateur,
        SafeZoneRadio.channelUUID
    )
    channel:setAirCounterMultiplier(1.0)
    scriptManager:AddChannel(channel, false)

    DynamicRadio.cache[SafeZoneRadio.channelUUID] = channel
    table.insert(DynamicRadio.scripts, SafeZoneRadio)

    local bc = SafeZoneRadio.CreateBroadcast()
    if bc then
        channel:setAiringBroadcast(bc)
    end

    print("[SafeZoneRadio] Radio channel initialized on " .. SafeZoneConfig.RADIO_FREQUENCY)
end

function SafeZoneRadio.OnEveryHour(_channel, _gametime, _radio)
    -- обязательный callback для DynamicRadio.scripts (вызывается ванильным ISDynamicRadio)
end

function SafeZoneRadio.CreateBroadcast()
    local msgs = radioMessages["broadcast"]
    if not msgs or #msgs == 0 then
        print("[SafeZoneRadio] No broadcast messages loaded")
        return nil
    end

    local bc = RadioBroadCast.new("SZ-" .. tostring(ZombRand(100000, 999999)), -1, -1)

    local idx = ZombRand(#msgs) + 1
    local freq = string.format("%.1f", SafeZoneConfig.RADIO_FREQUENCY / 1000)
    local msg = msgs[idx]
    msg = msg:gsub("{freq}", freq)
    msg = msg:gsub("{x}", tostring(SafeZoneConfig.BASE_X))
    msg = msg:gsub("{y}", tostring(SafeZoneConfig.BASE_Y))

    bc:AddRadioLine(RadioLine.new(msg, 1.0, 0.8, 0.2))

    return bc
end

--- Создаёт трансляцию для события (вызывается из EventManager)
function SafeZoneRadio.CreateEventBroadcast(eventTypeName, x, y)
    local typeToMsg = {
        buildingstash    = 1,
        foreststash      = 3,
        airdrop          = 4,
        abandonedvehicle = 5,
        camp             = 6,
        helicoptercrash  = 7,
    }

    local msgIdx = typeToMsg[eventTypeName] or 1
    local key = "IGUI_SZ_Event_" .. msgIdx
    local msg = getText(key, tostring(x), tostring(y))

    local bc = RadioBroadCast.new("SZ-EVT-" .. tostring(ZombRand(100000, 999999)), -1, -1)
    bc:AddRadioLine(RadioLine.new("<bzzt>", 0.5, 0.5, 0.5))
    bc:AddRadioLine(RadioLine.new(msg, 1.0, 0.5, 0.1))
    bc:AddRadioLine(RadioLine.new("<fzzt>", 0.5, 0.5, 0.5))

    return bc
end

--- Отправить сообщение о событии в эфир
function SafeZoneRadio.broadcastEvent(eventTypeName, x, y)
    local channel = DynamicRadio.cache[SafeZoneRadio.channelUUID]
    if not channel then return end

    local bc = SafeZoneRadio.CreateEventBroadcast(eventTypeName, x, y)
    channel:setAiringBroadcast(bc)
    print("[SafeZoneRadio] Event broadcast: " .. eventTypeName .. " at " .. x .. "," .. y)
end

SafeZoneRadio.init()

-------------------------------------------------
-- Автотрансляция 2 раза в игровые сутки (8:00 и 20:00)
-------------------------------------------------

local lastBroadcastHour = -1

local function onEveryHour()
    local hour = getGameTime():getHour()
    if hour ~= 8 and hour ~= 20 then return end
    if hour == lastBroadcastHour then return end
    lastBroadcastHour = hour

    local channel = DynamicRadio.cache[SafeZoneRadio.channelUUID]
    if not channel then return end

    local bc = SafeZoneRadio.CreateBroadcast()
    channel:setAiringBroadcast(bc)
end

Events.EveryHours.Add(onEveryHour)

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
