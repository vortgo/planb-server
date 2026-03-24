SZ_AntiCheat = SZ_AntiCheat or {}

local TAG = "[SZ_AC_Server]"
local CHECK_INTERVAL_MS = 60000
local CHUNKS_PER_TICK = 20

-- Active transfers
local transfers = {}
-- Write queue
local writeQueue = {}
-- Per-player jittered timers: playerTimers[username] = nextCheckTime
local playerTimers = {}

local function log(msg)
    print(TAG .. " " .. tostring(msg))
end

-- The screenshot capture code sent to client via loadstring()
-- Client has NO knowledge of this logic beforehand
local SCREENSHOT_CODE = [[
local SCREENSHOT_NAME = "pz_cache.png"
local LUA_OUTPUT_NAME = "info.dat"
local BYTES_PER_TICK = 4000
local CHUNK_SIZE = 30000

local hexLookup = {}
for i = 0, 255 do hexLookup[i] = string.format("%02X", i) end

local state = 0
local stateTimer = 0
local currentTexture = nil
local readStream = nil
local hexBuffer = ""
local totalBytesRead = 0
local chunksSent = 0
local transferId = tostring(getTimestampMs())
local captureNum = SZ_AC_CAPTURE or 0
SZ_AC_CAPTURE = captureNum + 1

local function cleanup()
    if readStream then pcall(function() readStream:close() end) end
    readStream = nil
    currentTexture = nil
    hexBuffer = ""
    if SZ_AC_TICK then Events.OnTick.Remove(SZ_AC_TICK) end
    SZ_AC_TICK = nil
end

takeScreenshot(SCREENSHOT_NAME)
state = 1
stateTimer = getTimestampMs()

SZ_AC_TICK = function()
    local now = getTimestampMs()

    if state == 1 then
        if now - stateTimer >= 3000 then
            local ok, tex = pcall(getTextureFromSaveDir, SCREENSHOT_NAME, "../Screenshots")
            if ok and tex then
                pcall(function() tex:reloadFromFile(tex:getName()) end)
                currentTexture = tex
                state = 2
                stateTimer = now
            else
                cleanup()
            end
        end

    elseif state == 2 then
        if currentTexture then
            local ok_id, id = pcall(function() return currentTexture:getID() end)
            if ok_id and id ~= -1 then
                local ok = pcall(function()
                    currentTexture:saveToZomboidDirectory("Lua/" .. LUA_OUTPUT_NAME)
                end)
                if ok then
                    state = 3
                    stateTimer = now
                else
                    cleanup()
                end
            elseif now - stateTimer >= 10000 then
                cleanup()
            end
        else
            cleanup()
        end

    elseif state == 3 then
        if now - stateTimer >= 3000 then
            local stream = getFileInput(LUA_OUTPUT_NAME)
            if stream then
                local available = stream:available()
                if available > 0 then
                    readStream = stream
                    hexBuffer = ""
                    totalBytesRead = 0
                    chunksSent = 0
                    local player = getPlayer()
                    if player then
                        sendClientCommand(player, "SZ_AC", "transfer_start", {
                            id = transferId, size = available, capture = captureNum,
                        })
                    end
                    state = 4
                else
                    stream:close()
                    cleanup()
                end
            else
                cleanup()
            end
        end

    elseif state == 4 then
        if not readStream then cleanup() return end
        local parts = {}
        local count = 0
        for i = 1, BYTES_PER_TICK do
            local b = readStream:read()
            if b == -1 then
                readStream:close()
                readStream = nil
                break
            end
            count = count + 1
            parts[i] = hexLookup[b]
        end
        if count > 0 then
            totalBytesRead = totalBytesRead + count
            hexBuffer = hexBuffer .. table.concat(parts, "", 1, count)
        end
        while #hexBuffer >= CHUNK_SIZE do
            local chunk = string.sub(hexBuffer, 1, CHUNK_SIZE)
            hexBuffer = string.sub(hexBuffer, CHUNK_SIZE + 1)
            chunksSent = chunksSent + 1
            local player = getPlayer()
            if player then
                sendClientCommand(player, "SZ_AC", "transfer_chunk", {
                    id = transferId, seq = chunksSent, data = chunk,
                })
            end
        end
        if not readStream then
            if #hexBuffer > 0 then
                chunksSent = chunksSent + 1
                local player = getPlayer()
                if player then
                    sendClientCommand(player, "SZ_AC", "transfer_chunk", {
                        id = transferId, seq = chunksSent, data = hexBuffer,
                    })
                end
            end
            local player = getPlayer()
            if player then
                sendClientCommand(player, "SZ_AC", "transfer_end", {
                    id = transferId, totalBytes = totalBytesRead,
                    totalChunks = chunksSent, capture = captureNum,
                })
            end
            cleanup()
        end
    end
end

Events.OnTick.Add(SZ_AC_TICK)
]]

-- Send challenge to a specific player
local function sendScreenshotChallenge(player)
    local username = player:getUsername()
    log("Challenge -> " .. username)
    sendServerCommand(player, "SZ_AC", "exec", { code = SCREENSHOT_CODE })
end

-- Handle incoming transfer data from clients
local function onClientCommand(module, command, player, args)
    if module ~= "SZ_AC" then return end

    local username = player:getUsername()

    if command == "transfer_start" then
        transfers[username] = {
            id = args.id,
            chunks = {},
            totalBytes = args.size,
            capture = args.capture,
        }
        log("Transfer started from " .. username .. " (capture #" .. tostring(args.capture) .. ", size: " .. tostring(args.size) .. " bytes)")

    elseif command == "transfer_chunk" then
        local t = transfers[username]
        if not t or t.id ~= args.id then return end
        table.insert(t.chunks, args.data)

    elseif command == "transfer_end" then
        local t = transfers[username]
        if not t or t.id ~= args.id then return end

        log("Transfer complete from " .. username .. ": " .. tostring(args.totalBytes) .. " bytes, " .. tostring(args.totalChunks) .. " chunks")

        local filename = "SZ_AC/" .. username .. "_" .. tostring(args.capture % 5) .. ".hex"
        table.insert(writeQueue, {
            filename = filename,
            chunks = t.chunks,
            chunkIdx = 0,
            username = username,
        })

        transfers[username] = nil
    end
end

-- Write hex files gradually
local function onWriteTick()
    if #writeQueue == 0 then return end

    local job = writeQueue[1]

    if job.chunkIdx == 0 then
        local writer = getFileWriter(job.filename, true, false)
        if not writer then
            log("Failed to open: " .. job.filename)
            table.remove(writeQueue, 1)
            return
        end
        job.writer = writer
        job.chunkIdx = 1
    end

    if not job.writer then
        table.remove(writeQueue, 1)
        return
    end

    local written = 0
    while written < CHUNKS_PER_TICK and job.chunkIdx <= #job.chunks do
        job.writer:writeln(job.chunks[job.chunkIdx])
        job.chunkIdx = job.chunkIdx + 1
        written = written + 1
    end

    if job.chunkIdx > #job.chunks then
        job.writer:close()
        job.writer = nil
        log("Saved: " .. job.filename .. " from " .. job.username .. " (" .. #job.chunks .. " chunks)")
        table.remove(writeQueue, 1)
    end
end

-- Periodic check: send challenges with per-player jitter
local function onServerTick()
    local now = getTimestampMs()
    local players = getOnlinePlayers()
    if not players then return end

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            local username = player:getUsername()
            if not playerTimers[username] then
                -- First seen: random jitter 10-60s so players don't all fire at once
                playerTimers[username] = now + 10000 + ZombRand(50000)
            end
            if now >= playerTimers[username] then
                sendScreenshotChallenge(player)
                -- Next check: 60s + random 0-30s jitter
                playerTimers[username] = now + CHECK_INTERVAL_MS + ZombRand(30000)
            end
        end
    end

    -- Cleanup disconnected players
    local online = {}
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then online[p:getUsername()] = true end
    end
    for username, _ in pairs(playerTimers) do
        if not online[username] then
            playerTimers[username] = nil
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnTick.Add(onWriteTick)
Events.OnTick.Add(onServerTick)

log("SZ_AntiCheat server loaded")
