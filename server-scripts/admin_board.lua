if not isServer() then return end

-- =========================================================================
-- AdminBoard — sync SC_Boards bulletin from external text file
-- =========================================================================

local BOARD_FILE = "SafeZone_admin_board.txt"
local CHECK_INTERVAL_MS = 5 * 60 * 1000
local UUID_PREFIX = "adm_"

local lastCheckTime = 0
local boardID = nil
local prevHash = nil

local function log(msg)
    print("[AdminBoard] " .. tostring(msg))
end

-- Simple string hash for change detection
local function hashStr(s)
    local h = 0
    for i = 1, #s do
        h = (h * 31 + string.byte(s, i)) % 2147483647
    end
    return h
end

local function makeUUID(title)
    return UUID_PREFIX .. hashStr(title)
end

-- ----- Parse file -----------------------------------------------------------

local function parseFile()
    local reader = getFileReader(BOARD_FILE, true)
    if not reader then
        return nil, nil
    end

    local coordLine = reader:readLine()
    if not coordLine then
        reader:close()
        return nil, nil
    end

    -- First line: x,y,z
    coordLine = coordLine:match("^%s*(.-)%s*$")
    local x, y, z = coordLine:match("^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)$")
    if not x then
        log("Invalid coordinates: " .. coordLine)
        reader:close()
        return nil, nil
    end

    local bID = x .. y .. z
    local ads = {}
    local currentTitle = nil
    local currentLines = {}
    local rawContent = coordLine

    local line = reader:readLine()
    while line do
        rawContent = rawContent .. line
        local trimmed = line:match("^%s*(.-)%s*$")
        local section = trimmed:match("^%[(.+)%]$")
        if section then
            if currentTitle then
                local text = table.concat(currentLines, "\n")
                -- trim trailing empty lines
                text = text:match("^(.-)%s*$") or text
                table.insert(ads, { title = currentTitle, text = text })
            end
            currentTitle = section
            currentLines = {}
        elseif currentTitle then
            table.insert(currentLines, line)
        end
        line = reader:readLine()
    end
    reader:close()

    -- Last section
    if currentTitle then
        local text = table.concat(currentLines, "\n")
        text = text:match("^(.-)%s*$") or text
        table.insert(ads, { title = currentTitle, text = text })
    end


    return bID, ads, hashStr(rawContent)
end

-- ----- Sync with SC_Board ---------------------------------------------------

local function isAdminUUID(uuid)
    return type(uuid) == "string" and uuid:sub(1, #UUID_PREFIX) == UUID_PREFIX
end

-- Fake player object for SC_Board:Logger (it expects self.player:getUsername())
local ADMIN_PLAYER = { getUsername = function() return "AdminBoard" end }

local function sync()
    if not SC_Board then
        log("SC_Board not available")
        return
    end

    local bID, ads, contentHash = parseFile()
    if not bID then return end

    -- Skip if content hasn't changed
    if contentHash == prevHash then return end

    boardID = bID

    if not SC_Board.boards[boardID] then
        log("Board " .. boardID .. " does not exist in SC_Boards")
        return
    end

    -- SC_Board:Logger needs self.player set
    SC_Board.player = ADMIN_PLAYER

    local existing = SC_Board.boardsAds[boardID] or {}

    -- Collect current admin UUIDs
    local oldAdminUUIDs = {}
    for uuid, _ in pairs(existing) do
        if isAdminUUID(uuid) then
            oldAdminUUIDs[uuid] = true
        end
    end

    -- Build new admin ads map
    local newAdminAds = {}
    for _, ad in ipairs(ads) do
        local uuid = makeUUID(ad.title)
        newAdminAds[uuid] = ad
    end

    -- Delete removed admin ads
    for uuid, _ in pairs(oldAdminUUIDs) do
        if not newAdminAds[uuid] then
            SC_Board:delAdBoard(boardID, uuid)
            log("Removed: " .. uuid)
        end
    end

    -- Add or update admin ads
    for uuid, ad in pairs(newAdminAds) do
        local existingAd = existing[uuid]
        if not existingAd or existingAd.text ~= ad.text or existingAd.title ~= ad.title then
            -- Delete first if updating
            if existingAd then
                SC_Board:delAdBoard(boardID, uuid)
            end
            SC_Board:addAdBoard(boardID, uuid, ad.title, ad.text, true)
            log("Synced: " .. ad.title)
        end
    end

    prevHash = contentHash
    log("Sync complete (" .. #ads .. " ads)")
end

-- ----- Periodic check -------------------------------------------------------

local function tickCheck()
    local now = getTimestampMs()
    if now - lastCheckTime < CHECK_INTERVAL_MS then return end
    lastCheckTime = now
    sync()
end

-- ----- Init -----------------------------------------------------------------

local function onServerStarted()
    -- Delay initial sync to let SC_Board load ModData
    local delay = 0
    local function waitAndSync()
        delay = delay + 1
        if delay >= 30 then
            Events.OnTick.Remove(waitAndSync)
            sync()
            log("Initialized")
        end
    end
    Events.OnTick.Add(waitAndSync)
end

Events.OnServerStarted.Add(onServerStarted)
Events.OnTick.Add(tickCheck)
log("AdminBoard module ready")
