local SCRIPTS_DIR = "SafeZone_scripts"

local function log(msg)
    print("[ScriptLoader] " .. tostring(msg))
end

local function readFile(filePath)
    local reader = getFileReader(filePath, false)
    if not reader then return nil end

    local lines = {}
    local line = reader:readLine()
    while line ~= nil do
        table.insert(lines, line)
        line = reader:readLine()
    end
    reader:close()
    return table.concat(lines, "\n")
end

local function executeScript(filePath)
    local code = readFile(filePath)
    if not code then
        log("ERROR: cannot read " .. filePath)
        return false
    end

    local fn, err = loadstring(code, "@" .. filePath)
    if not fn then
        log("ERROR parsing " .. filePath .. ": " .. tostring(err))
        return false
    end

    local ok, result = pcall(fn)
    if not ok then
        log("ERROR executing " .. filePath .. ": " .. tostring(result))
        return false
    end

    log("Loaded: " .. filePath)
    return true
end

local function loadAll()
    local indexPath = SCRIPTS_DIR .. "/init.lua"
    local indexCode = readFile(indexPath)

    if not indexCode then
        log("No " .. indexPath .. " found, skipping")
        return 0
    end

    local fn, err = loadstring(indexCode, "@" .. indexPath)
    if not fn then
        log("ERROR parsing " .. indexPath .. ": " .. tostring(err))
        return 0
    end

    local ok, fileList = pcall(fn)
    if not ok then
        log("ERROR executing " .. indexPath .. ": " .. tostring(fileList))
        return 0
    end

    if type(fileList) ~= "table" then
        log("ERROR: " .. indexPath .. " must return a table of filenames")
        return 0
    end

    local count = 0
    for _, filename in ipairs(fileList) do
        local path = SCRIPTS_DIR .. "/" .. filename
        if executeScript(path) then
            count = count + 1
        end
    end
    log("Loaded " .. count .. " scripts")

    -- Load external config AFTER all scripts (EventConfig must exist)
    if SafeZoneConfig and SafeZoneConfig.loadExternal then
        SafeZoneConfig.loadExternal()
    end

    return count
end

local function onServerStarted()
    loadAll()
    log("ScriptLoader initialized")
end

Events.OnServerStarted.Add(onServerStarted)
log("ScriptLoader ready")
