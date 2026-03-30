local function isFuelPump(obj)
    return obj and obj.getPipedFuelAmount and obj:getPipedFuelAmount() >= 0
end

local function findFuelPump(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if isFuelPump(obj) then
            return obj
        end
        -- Проверяем объекты на том же тайле
        local square = obj:getSquare()
        if square then
            for i = 0, square:getObjects():size() - 1 do
                local sqObj = square:getObjects():get(i)
                if isFuelPump(sqObj) then
                    return sqObj
                end
            end
        end
    end
    return nil
end

local function onRefillPump(playerNum, pump)
    local playerObj = getSpecificPlayer(playerNum)
    sendClientCommand(playerObj, "SafeZoneFuel", "refill", {
        x = pump:getSquare():getX(),
        y = pump:getSquare():getY(),
        z = pump:getSquare():getZ(),
    })
end

local function onDrainPump(playerNum, pump)
    local playerObj = getSpecificPlayer(playerNum)
    sendClientCommand(playerObj, "SafeZoneFuel", "drain", {
        x = pump:getSquare():getX(),
        y = pump:getSquare():getY(),
        z = pump:getSquare():getZ(),
    })
end

local function onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local level = playerObj:getAccessLevel()
    if level ~= "Admin" and level ~= "admin" then return end

    local pump = findFuelPump(worldobjects)
    if not pump then return end

    local current = pump:getPipedFuelAmount()

    context:addOption("Fuel: Refill (" .. current .. " -> 14000)", player, onRefillPump, pump)
    context:addOption("Fuel: Drain (" .. current .. " -> 0)", player, onDrainPump, pump)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
