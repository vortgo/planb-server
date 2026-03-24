if not isServer() then return end

SZ_VehicleSpawnerServer = {}

---@param module string
---@param command string
---@param player IsoPlayer
---@param params table?
function SZ_VehicleSpawnerServer.OnClientCommand(module, command, player, params)
    if module ~= 'SZVehicleSpawner' then return end
    if (not params) or (not player) then return end
    if not player:getRole():hasCapability(Capability.ManipulateVehicle) then
        DebugLog.log(DebugType.Multiplayer, "player: \""..player:getUsername().."\" tried to spawn vehicle without admin access!")
        return
    end

    if command == 'spawnVehicle' then
        local model = params.vehicleModel
        if not model or model == "" then return end

        local square = getCell():getGridSquare(params.posX, params.posY, params.posZ)
        if not square then return end

        local direction = params.vehicleDirection or 0
        if direction == 0 then
            direction = ZombRand(1, 5)
        end
        if direction == 1 then
            direction = IsoDirections.W
        elseif direction == 2 then
            direction = IsoDirections.E
        elseif direction == 3 then
            direction = IsoDirections.N
        elseif direction == 4 then
            direction = IsoDirections.S
        end

        local noFuel = params.noFuel
        local noBattery = params.noBattery
        local keyGlovebox = params.keyGlovebox

        local vehicle = addVehicleDebug(model, direction, nil, square)
        if not vehicle then return end

        -- Configure parts based on condition/fuel/battery settings
        if not string.contains(string.lower(model), "burnt") then
            local totalParts = vehicle:getPartCount()
            for i = 1, totalParts do
                local part = vehicle:getPartByIndex(i - 1)
                local partName = part:getId()
                if part ~= nil and partName ~= nil then
                    -- Battery charge
                    if string.contains(string.lower(partName), "battery") then
                        local amount = ZombRand(1, 101)
                        if noBattery then
                            amount = 0
                        end
                        if amount > 0 then
                            amount = 1 - (amount / 100)
                        end
                        part:getInventoryItem():setUsedDelta(amount)
                        vehicle:transmitPartUsedDelta(part)
                    end
                    -- Fuel
                    if string.contains(string.lower(partName), "tank") then
                        local amount = ZombRand(1, 101)
                        if noFuel then
                            amount = 0
                        end
                        local capacity = part:getContainerCapacity()
                        if amount > 0 then
                            amount = capacity * amount / 100
                        end
                        part:setContainerContentAmount(amount)
                        vehicle:transmitPartModData(part)
                    end
                    -- Engine
                    if string.lower(partName) == "engine" then
                        local engineCondition = 100
                        if tonumber(params.vehicleCondition) ~= 100 and tonumber(params.vehicleCondition) > 40 then
                            engineCondition = ZombRand(40, 81)
                        elseif tonumber(params.vehicleCondition) < 41 then
                            engineCondition = ZombRand(1, 41)
                        end
                        local engineL = vehicle:getScript():getEngineLoudness() or 100
                        local engineP = vehicle:getScript():getEngineForce()
                        vehicle:setEngineFeature(engineCondition, engineL, engineP)
                        vehicle:transmitEngine()
                    end
                    -- Glovebox key
                    if string.lower(partName) == "glovebox" and keyGlovebox then
                        local item = vehicle:createVehicleKey()
                        part:getItemContainer():AddItem(item)
                        for j = 0, 4 do
                            local door = vehicle:getPassengerDoor(j)
                            if not door then break end
                            door:getDoor():setLockBroken(false)
                            door:getDoor():setLocked(false)
                            vehicle:transmitPartDoor(door)
                        end
                    end
                    -- Part condition
                    local condition = 100
                    if tonumber(params.vehicleCondition) ~= 100 and tonumber(params.vehicleCondition) > 40 then
                        condition = ZombRand(40, 81)
                    elseif tonumber(params.vehicleCondition) < 41 then
                        condition = ZombRand(1, 41)
                    end
                    part:setCondition(condition)
                    vehicle:transmitPartCondition(part)
                end
            end
        end

        print("[SZ_VehicleSpawner] " .. player:getUsername() .. " spawned " .. model)
    end
end

Events.OnClientCommand.Add(SZ_VehicleSpawnerServer.OnClientCommand)
