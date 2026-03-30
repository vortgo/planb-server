local FUEL_MAX = 14000

local function log(msg)
    print("[FuelPump] " .. tostring(msg))
end

local function findPumpAt(x, y, z)
    local square = getSquare(x, y, z)
    if not square then return nil end
    for i = 0, square:getObjects():size() - 1 do
        local obj = square:getObjects():get(i)
        if obj and obj.getPipedFuelAmount and obj:getPipedFuelAmount() >= 0 then
            return obj
        end
    end
    return nil
end

local function onClientCommand(module, command, player, args)
    if module ~= "SafeZoneFuel" then return end

    local level = player:getAccessLevel()
    if level ~= "Admin" and level ~= "admin" then
        log("WARN: non-admin " .. player:getUsername() .. " attempted fuel command")
        return
    end

    local x = tonumber(args.x)
    local y = tonumber(args.y)
    local z = tonumber(args.z)
    if not x or not y or not z then return end

    local pump = findPumpAt(x, y, z)
    if not pump then
        log("No fuel pump found at " .. x .. "," .. y .. "," .. z)
        return
    end

    local username = player:getUsername()

    if command == "refill" then
        local before = pump:getPipedFuelAmount()
        pump:setPipedFuelAmount(FUEL_MAX)
        log(username .. " refilled pump at " .. x .. "," .. y .. " (" .. before .. " -> " .. FUEL_MAX .. ")")

    elseif command == "drain" then
        local before = pump:getPipedFuelAmount()
        pump:setPipedFuelAmount(0)
        log(username .. " drained pump at " .. x .. "," .. y .. " (" .. before .. " -> 0)")
    end
end

local function onServerStarted()
    Events.OnClientCommand.Add(onClientCommand)
    log("FuelPump server initialized")
end

Events.OnServerStarted.Add(onServerStarted)
