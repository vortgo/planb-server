if not isServer() then return end

-- =========================================================================
-- Library — periodic book respawn on marked shelves, dedup
-- =========================================================================

local SHELVES_FILE = "SafeZone_library_shelves.txt"
local RESTOCK_INTERVAL_MS = 5 * 60 * 1000
local lastRestockTime = 0

local shelves = {} -- {{x=,y=,z=}, ...}
local shelvesIndex = {} -- "x,y,z" -> true

local LIBRARY_BOOKS = {
    "Base.BookCarpentry1",
    "Base.BookCarving1",
    "Base.BookCooking1",
    "Base.BookElectrician1",
    "Base.BookFarming1",
    "Base.BookFirstAid1",
    "Base.BookFishing1",
    "Base.BookFlintKnapping1",
    "Base.BookForaging1",
    "Base.BookGlassmaking1",
    "Base.BookMasonry1",
    "Base.BookMechanic1",
    "Base.BookMetalWelding1",
    "Base.BookBlacksmith1",
    "Base.BookPottery1",
    "Base.BookTailoring1",
    "Base.BookTrapping1",
    "Base.BookAiming1",
    "Base.BookReloading1",
    "Base.BookHusbandry1",
    "Base.BookButchering1",
    "Base.BookTracking1",
    "Base.BookLongBlade1",
    "Base.BookMaintenance1",
}

local function log(msg)
    print("[Library] " .. tostring(msg))
end

-- ----- Persistence -------------------------------------------------------

local function shelfKey(x, y, z)
    return x .. "," .. y .. "," .. z
end

local function loadShelves()
    shelves = {}
    local reader = getFileReader(SHELVES_FILE, true)
    if not reader then return end
    local line = reader:readLine()
    while line ~= nil do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then
            local sx, sy, sz = line:match("([^,]+),([^,]+),([^,]+)")
            local x, y, z = tonumber(sx), tonumber(sy), tonumber(sz)
            if x and y and z then
                table.insert(shelves, {x = x, y = y, z = z})
            end
        end
        line = reader:readLine()
    end
    reader:close()
    log("Loaded " .. #shelves .. " shelves")
end

local function saveShelves()
    local writer = getFileWriter(SHELVES_FILE, true, false)
    for _, s in ipairs(shelves) do
        writer:write(s.x .. "," .. s.y .. "," .. s.z .. "\r\n")
    end
    writer:close()
    log("Saved " .. #shelves .. " shelves to file")
end

-- ----- Helpers -----------------------------------------------------------

local function findContainerAt(x, y, z)
    local square = getSquare(x, y, z)
    if not square then return nil, nil end
    for i = 0, square:getObjects():size() - 1 do
        local obj = square:getObjects():get(i)
        if obj:getContainer() then
            return obj, obj:getContainer()
        end
    end
    return nil, nil
end

-- ----- Command handler ---------------------------------------------------

local function onClientCommand(module, command, player, args)
    if module ~= "SafeZoneLibrary" then return end

    local username = player:getUsername()

    -- destroyBook — any player can return a library book
    if command == "destroyBook" then
        local itemId = tonumber(args.itemId)
        if not itemId then return end
        local inv = player:getInventory()
        local items = inv:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item:getID() == itemId and item:getModData().SZLibrary then
                local fullType = item:getFullType()
                sendRemoveItemFromContainer(inv, item)
                inv:Remove(item)
                log(username .. " returned library book: " .. fullType)
                return
            end
        end
        return
    end

    -- Admin-only commands below
    local level = player:getAccessLevel()
    log("Command '" .. command .. "' from " .. username .. " (level: '" .. tostring(level) .. "')")
    if level ~= "Admin" and level ~= "admin" then
        log("WARN: non-admin " .. username .. " attempted library command: " .. command)
        return
    end

    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z)
    if not x or not y or not z then return end

    if command == "mark" then
        log("mark: looking for container at " .. x .. "," .. y .. "," .. z)
        local obj, _ = findContainerAt(x, y, z)
        if not obj then
            log("mark: No container at " .. x .. "," .. y .. "," .. z)
            return
        end
        log("mark: found object, class=" .. tostring(obj:getObjectName()) .. " type=" .. tostring(obj:getType()))
        local ok, err = pcall(function()
            obj:getModData().SZLibraryShelf = true
        end)
        if ok then
            obj:transmitModData()
            log("mark: modData set successfully")
        else
            log("mark: modData FAILED: " .. tostring(err) .. ", trying rawset")
            local ok2, err2 = pcall(function()
                local md = obj:getModData()
                rawset(md, "SZLibraryShelf", true)
            end)
            if ok2 then
                obj:transmitModData()
                log("mark: rawset worked")
            else
                log("mark: rawset also FAILED: " .. tostring(err2))
            end
        end

        -- Avoid duplicates
        local key = shelfKey(x, y, z)
        for _, s in ipairs(shelves) do
            if shelfKey(s.x, s.y, s.z) == key then
                log(username .. " shelf already marked at " .. key)
                return
            end
        end
        table.insert(shelves, {x = x, y = y, z = z})
        shelvesIndex[key] = true
        log("mark: calling saveShelves, shelves count: " .. #shelves)
        local ok, err = pcall(saveShelves)
        if not ok then
            log("mark: saveShelves ERROR: " .. tostring(err))
        end
        log(username .. " marked shelf at " .. key)

    elseif command == "unmark" then
        local obj, container = findContainerAt(x, y, z)
        if obj then
            obj:getModData().SZLibraryShelf = nil
            obj:transmitModData()

            -- Remove library books from this shelf
            if container then
                local toRemove = {}
                local items = container:getItems()
                for i = 0, items:size() - 1 do
                    local item = items:get(i)
                    if item:getModData().SZLibrary then
                        table.insert(toRemove, item)
                    end
                end
                for _, item in ipairs(toRemove) do
                    sendRemoveItemFromContainer(container, item)
                    container:Remove(item)
                end
                if #toRemove > 0 then
                    pcall(obj.sendObjectChange, obj, "containers")
                    if ItemPicker and ItemPicker.updateOverlaySprite then
                        ItemPicker.updateOverlaySprite(obj)
                    end
                end
            end
        end

        local key = shelfKey(x, y, z)
        for i = #shelves, 1, -1 do
            if shelfKey(shelves[i].x, shelves[i].y, shelves[i].z) == key then
                table.remove(shelves, i)
            end
        end
        shelvesIndex[key] = nil
        saveShelves()
        log(username .. " unmarked shelf at " .. key)
    end
end

-- ----- Restock -----------------------------------------------------------

local function restockLibrary()
    if #shelves == 0 then return end

    -- Collect all containers from loaded shelves
    local shelfContainers = {} -- {container, obj}
    for _, s in ipairs(shelves) do
        local obj, container = findContainerAt(s.x, s.y, s.z)
        if obj and container then
            table.insert(shelfContainers, {container = container, obj = obj})
        end
    end

    if #shelfContainers == 0 then return end

    -- Scan: which books exist and where (for dedup)
    local bookFound = {}   -- bookType -> {{container, item}, ...}
    for _, sc in ipairs(shelfContainers) do
        local items = sc.container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item:getModData().SZLibrary then
                local ft = item:getFullType()
                if not bookFound[ft] then bookFound[ft] = {} end
                table.insert(bookFound[ft], {container = sc.container, item = item})
            end
        end
    end

    -- Dedup: remove extra copies
    local dupsRemoved = 0
    local dedupSyncNeeded = {}
    for ft, entries in pairs(bookFound) do
        if #entries > 1 then
            for i = 2, #entries do
                sendRemoveItemFromContainer(entries[i].container, entries[i].item)
                entries[i].container:Remove(entries[i].item)
                dedupSyncNeeded[entries[i].container] = true
                dupsRemoved = dupsRemoved + 1
            end
        end
    end

    -- Spawn missing
    local spawned = 0
    local syncNeeded = {} -- obj -> true
    for _, bookType in ipairs(LIBRARY_BOOKS) do
        if not bookFound[bookType] or #bookFound[bookType] == 0 then
            local sc = shelfContainers[ZombRand(#shelfContainers) + 1]
            local added = sc.container:AddItem(bookType)
            if added then
                added:getModData().SZLibrary = true
                sendAddItemToContainer(sc.container, added)
                syncNeeded[sc.obj] = true
                spawned = spawned + 1
            end
        end
    end

    -- Sync visuals for all changed shelves
    for _, sc in ipairs(shelfContainers) do
        if syncNeeded[sc.obj] or dedupSyncNeeded[sc.container] then
            pcall(sc.obj.sendObjectChange, sc.obj, "containers")
            if ItemPicker and ItemPicker.updateOverlaySprite then
                ItemPicker.updateOverlaySprite(sc.obj)
            end
        end
    end

    if spawned > 0 or dupsRemoved > 0 then
        log("Restock: spawned " .. spawned .. ", removed " .. dupsRemoved .. " duplicates")
    end
end

local function tickRestock()
    local now = getTimestampMs()
    if now - lastRestockTime < RESTOCK_INTERVAL_MS then return end
    lastRestockTime = now
    restockLibrary()
end

-- ----- Chunk load restock ------------------------------------------------

local function buildShelvesIndex()
    shelvesIndex = {}
    for _, s in ipairs(shelves) do
        shelvesIndex[shelfKey(s.x, s.y, s.z)] = true
    end
end

local function restockShelf(obj, container)
    -- Collect existing library books on this shelf
    local existing = {}
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getModData().SZLibrary then
            local ft = item:getFullType()
            if existing[ft] then
                -- Duplicate on same shelf — remove
                container:Remove(item)
            else
                existing[ft] = true
            end
        end
    end

    -- NOTE: we don't spawn missing books here because dedup requires
    -- checking ALL loaded shelves. Only the periodic tick does full restock.
    -- But we do ensure modData flag is set on the object.
    if not obj:getModData().SZLibraryShelf then
        obj:getModData().SZLibraryShelf = true
        obj:transmitModData()
    end
end

local function onLoadGridsquare(square)
    if not square then return end
    if #shelves == 0 then return end

    local key = shelfKey(square:getX(), square:getY(), square:getZ())
    -- Square coords don't match shelf coords directly — shelves store object coords
    -- so we check all objects on this square
    for i = 0, square:getObjects():size() - 1 do
        local obj = square:getObjects():get(i)
        if obj:getContainer() then
            local sq = obj:getSquare()
            local objKey = shelfKey(sq:getX(), sq:getY(), sq:getZ())
            if shelvesIndex[objKey] then
                restockShelf(obj, obj:getContainer())
            end
        end
    end
end

-- ----- Init --------------------------------------------------------------

local function onServerStarted()
    loadShelves()
    buildShelvesIndex()
    Events.OnClientCommand.Add(onClientCommand)
    Events.LoadGridsquare.Add(onLoadGridsquare)
    log("Library initialized (" .. #shelves .. " shelves, " .. #LIBRARY_BOOKS .. " books)")
end

Events.OnServerStarted.Add(onServerStarted)
Events.OnTick.Add(tickRestock)
log("Library module ready")
