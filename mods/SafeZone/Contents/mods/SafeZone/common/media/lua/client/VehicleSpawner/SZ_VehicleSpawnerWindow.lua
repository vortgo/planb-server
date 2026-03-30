if not isClient() then return end

local function GenerateVehicleLists()
    local allVehicleScripts = getScriptManager():getAllVehicleScripts()
    local all, burned, smashed, burned_and_smashed, usable_vehicles, vehicle_trailer = {}, {}, {}, {}, {}, {}

    for i = 1, allVehicleScripts:size() do
        local script = allVehicleScripts:get(i-1)
        local name = string.lower(script:getName())
        local scriptFullName, scriptName = script:getFullName(), script:getName()

        table.insert(all, {scriptFullName, scriptName})

        if string.contains(name, "burnt") then
            table.insert(burned, {scriptFullName, scriptName})
            table.insert(burned_and_smashed, {scriptFullName, scriptName})
        end

        if string.contains(name, "smashed") then
            table.insert(smashed, {scriptFullName, scriptName})
            table.insert(burned_and_smashed, {scriptFullName, scriptName})
        end

        if not string.contains(name, "burnt") and not string.contains(name, "smashed") and script:getPassengerCount() > 0 then
            table.insert(usable_vehicles, {scriptFullName, scriptName})
        end

        if not string.contains(name, "burnt") and not string.contains(name, "smashed") and script:getPassengerCount() == 0 then
            table.insert(vehicle_trailer, {scriptFullName, scriptName})
        end
    end

    table.sort(all, function(a, b) return a[1] < b[1] end)
    table.sort(burned, function(a, b) return a[1] < b[1] end)
    table.sort(smashed, function(a, b) return a[1] < b[1] end)
    table.sort(burned_and_smashed, function(a, b) return a[1] < b[1] end)
    table.sort(usable_vehicles, function(a, b) return a[1] < b[1] end)
    table.sort(vehicle_trailer, function(a, b) return a[1] < b[1] end)

    return {
        all = {"All vehicles", all},
        burned = {"Only Burned", burned},
        smashed = {"Only Smashed", smashed},
        burned_and_smashed = {"Burned and Smashed", burned_and_smashed},
        usable_vehicles = {"Usable Vehicles", usable_vehicles},
        vehicle_trailer = {"Trailers", vehicle_trailer},
    }
end

local cursor = nil

SZ_VehicleSpawnerWindow = ISPanel:derive("SZ_VehicleSpawnerWindow")
SZ_VehicleSpawnerWindow.instance = nil

function SZ_VehicleSpawnerWindow:initialise()
    ISPanel.initialise(self)
    self:create()
    self.moveWithMouse = true
end

function SZ_VehicleSpawnerWindow:create()
    if not getPlayer():getRole():hasCapability(Capability.UseDebugContextMenu) and not isDebugEnabled() then
        return true
    end

    local vehicleLists = GenerateVehicleLists()

    self:addChild(ISLabel:new(10, 10, 20, getText("IGUI_SZ_VS_Title"), 1, 1, 1, 1, UIFont.Large, true))

    self:addChild(ISLabel:new(10, 45, 20, getText("IGUI_SZ_VS_Direction"), 1, 1, 1, 1, UIFont.Small, true))

    self.directionCombo = ISComboBox:new(150, 40, 120, 25, self)
    self.directionCombo:addOptionWithData(getText("IGUI_SZ_VS_Random"), 0)
    self.directionCombo:addOptionWithData(getText("IGUI_SZ_VS_West"), 1)
    self.directionCombo:addOptionWithData(getText("IGUI_SZ_VS_East"), 2)
    self.directionCombo:addOptionWithData(getText("IGUI_SZ_VS_North"), 3)
    self.directionCombo:addOptionWithData(getText("IGUI_SZ_VS_South"), 4)
    self:addChild(self.directionCombo)

    self:addChild(ISLabel:new(10, 80, 20, getText("IGUI_SZ_VS_Condition"), 1, 1, 1, 1, UIFont.Small, true))

    self.conditionCombo = ISComboBox:new(150, 75, 120, 25, self)
    self.conditionCombo:addOptionWithData(getText("IGUI_SZ_VS_Random"), ZombRand(0,101))
    self.conditionCombo:addOptionWithData(getText("IGUI_SZ_VS_Perfect"), 100)
    self.conditionCombo:addOptionWithData(getText("IGUI_SZ_VS_Average"), 80)
    self.conditionCombo:addOptionWithData(getText("IGUI_SZ_VS_Low"), 40)
    self:addChild(self.conditionCombo)

    self.closeBtn = ISButton:new(self:getWidth() - 170, self:getHeight() - 40, 80, 30,
        getText("UI_Close"), self, SZ_VehicleSpawnerWindow.onClose)
    self.closeBtn:enableCancelColor()
    self:addChild(self.closeBtn)
    self.spawnBtn = ISButton:new(self:getWidth() - 85, self:getHeight() - 40, 80, 30,
        getText("IGUI_SZ_VS_Spawn"), self, SZ_VehicleSpawnerWindow.onSpawn)
    self.spawnBtn:enableAcceptColor()
    self:addChild(self.spawnBtn)

    self.noFuelCheck = ISTickBox:new(10, 115, 20, 20, "", self, nil)
    self.noFuelCheck:initialise()
    self.noFuelCheck:addOption(getText("IGUI_SZ_VS_NoFuel"))
    self:addChild(self.noFuelCheck)

    self.noBatteryCheck = ISTickBox:new(10, 140, 20, 20, "", self, nil)
    self.noBatteryCheck:initialise()
    self.noBatteryCheck:addOption(getText("IGUI_SZ_VS_NoBattery"))
    self:addChild(self.noBatteryCheck)

    self.keyGloveboxCheck = ISTickBox:new(10, 165, 20, 20, "", self, nil)
    self.keyGloveboxCheck:initialise()
    self.keyGloveboxCheck:addOption(getText("IGUI_SZ_VS_KeyGlovebox"))
    self:addChild(self.keyGloveboxCheck)

    self:addChild(ISLabel:new(10, 200, 1, "-----------------------------------------------------------------", 1, 1, 1, 1, UIFont.Small, true))
    self:addChild(ISLabel:new(10, 210, 20, getText("IGUI_SZ_VS_TypeLabel"), 1, 1, 1, 1, UIFont.Small, true))

    self.vehicleType = ISTickBox:new(10, 240, 20, 20, "", self, nil)
    self.vehicleType:initialise()
    self.vehicleType.onlyOnePossibility = true
    self.vehicleType:addOption(getText("IGUI_SZ_VS_Manual"))
    self.vehicleType.selected[1] = false
    self.vehicleType:addOption(getText("IGUI_SZ_VS_ByType"))
    self.vehicleType.selected[2] = true
    self:addChild(self.vehicleType)

    self.manualCombo = ISComboBox:new(150, 235, 350, 25, self)
    for _, v in pairs(vehicleLists.all[2]) do
        local txt = v[1] .. " - " .. getText("IGUI_VehicleName" .. v[2])
        self.manualCombo:addOptionWithData(txt, v[1])
    end
    self.manualCombo:initialise()
    self.manualCombo:setEditable(true)
    self:addChild(self.manualCombo)

    self.typeCombo = ISComboBox:new(150, 260, 350, 25, self)
    for k, v in pairs(vehicleLists) do
        self.typeCombo:addOptionWithData(v[1], k)
    end
    self:addChild(self.typeCombo)
end

function SZ_VehicleSpawnerWindow.show()
    cursor = nil

    if not SZ_VehicleSpawnerWindow.instance then
        local w = 600
        local h = 500
        local x = getCore():getScreenWidth()/2 - w/2
        local y = getCore():getScreenHeight()/2 - h/2
        SZ_VehicleSpawnerWindow.instance = SZ_VehicleSpawnerWindow:new(x, y, w, h)
        SZ_VehicleSpawnerWindow.instance:initialise()
    end

    SZ_VehicleSpawnerWindow.instance:addToUIManager()
    SZ_VehicleSpawnerWindow.instance:setVisible(true)
    SZ_VehicleSpawnerWindow.instance:bringToTop()
end

function SZ_VehicleSpawnerWindow.hide()
    if SZ_VehicleSpawnerWindow.instance then
        SZ_VehicleSpawnerWindow.instance:setVisible(false)
        SZ_VehicleSpawnerWindow.instance:removeFromUIManager()
    end
end

function SZ_VehicleSpawnerWindow.onClose(button)
    SZ_VehicleSpawnerWindow.hide()
    cursor = nil
end

function SZ_VehicleSpawnerWindow.SpawnVehicles(x, y)
    if not getPlayer():getRole():hasCapability(Capability.UseDebugContextMenu) and not isDebugEnabled() then
        return true
    end
    if not cursor then return end

    local vehicleLists = GenerateVehicleLists()
    local vehicle = {}
    vehicle.direction = SZ_VehicleSpawnerWindow.instance.directionCombo.options[SZ_VehicleSpawnerWindow.instance.directionCombo.selected].data
    vehicle.condition = SZ_VehicleSpawnerWindow.instance.conditionCombo.options[SZ_VehicleSpawnerWindow.instance.conditionCombo.selected].data
    vehicle.noFuel = SZ_VehicleSpawnerWindow.instance.noFuelCheck:isSelected(1)
    vehicle.noBattery = SZ_VehicleSpawnerWindow.instance.noBatteryCheck:isSelected(1)
    vehicle.keyGlovebox = SZ_VehicleSpawnerWindow.instance.keyGloveboxCheck:isSelected(1)

    if SZ_VehicleSpawnerWindow.instance.vehicleType.selected[1] then
        vehicle.model = SZ_VehicleSpawnerWindow.instance.manualCombo.options[SZ_VehicleSpawnerWindow.instance.manualCombo.selected].data
    else
        local vtype = SZ_VehicleSpawnerWindow.instance.typeCombo.options[SZ_VehicleSpawnerWindow.instance.typeCombo.selected].data
        local rand = ZombRand(1, #vehicleLists[vtype][2] + 1)
        vehicle.model = vehicleLists[vtype][2][rand][1]
    end

    local wx, wy = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), getPlayer():getZ() or 0)

    local args = {
        posX = math.floor(wx),
        posY = math.floor(wy),
        posZ = getPlayer():getZ(),
        vehicleModel = vehicle.model,
        vehicleDirection = vehicle.direction,
        vehicleCondition = vehicle.condition,
        noFuel = vehicle.noFuel,
        noBattery = vehicle.noBattery,
        keyGlovebox = vehicle.keyGlovebox
    }
    sendClientCommand(getPlayer(), 'SZVehicleSpawner', 'spawnVehicle', args)
end

function SZ_VehicleSpawnerWindow.onSpawn(button)
    cursor = true
    SZ_VehicleSpawnerWindow.hide()
    SZ_VehicleSpawnPanel.show()
end

local function showRightClickOption(player, context, worldobjects, test, x, y)
    local playerObj = getPlayer()
    if not playerObj:getRole():hasCapability(Capability.UseDebugContextMenu) and not isDebugEnabled() then
        return true
    end

    local opt = context:addOption(getText("IGUI_SZ_VS_ContextMenu"), playerObj, function()
        SZ_VehicleSpawnerWindow.show()
    end)
    opt.iconTexture = getTexture("media/ui/BugIcon.png")
end

Events.OnFillWorldObjectContextMenu.Add(showRightClickOption)
Events.OnMouseDown.Add(SZ_VehicleSpawnerWindow.SpawnVehicles)
