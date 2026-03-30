if not isClient() then return end

SZ_VehicleSpawnPanel = ISPanel:derive("SZ_VehicleSpawnPanel")
SZ_VehicleSpawnPanel.instance = nil

function SZ_VehicleSpawnPanel:create()
    local label = ISLabel:new(0, 0, 40, getText("IGUI_SZ_VS_SpawnActive"),
        0, 1, 0, 1, UIFont.Large, true)
    label:setX((self:getWidth() - label:getWidth()) / 2)
    self:addChild(label)

    local closeBtn = ISButton:new((label:getX() + label:getWidth()) + 10, 5, 80, 30,
        getText("IGUI_SZ_VS_CloseMode"), self, SZ_VehicleSpawnPanel.close)
    closeBtn:enableCancelColor()
    self:addChild(closeBtn)
end

function SZ_VehicleSpawnPanel:initialise()
    ISPanel.initialise(self)
    self:create()
end

function SZ_VehicleSpawnPanel:prerender()
    self:drawRect(0, 0, self:getWidth(), self:getHeight(), 1, 0, 0.7, 0)
end

function SZ_VehicleSpawnPanel.show()
    if not SZ_VehicleSpawnPanel.instance then
        SZ_VehicleSpawnPanel.instance = SZ_VehicleSpawnPanel:new(0, 0, getCore():getScreenWidth(), 40)
        SZ_VehicleSpawnPanel.instance:initialise()
    end
    SZ_VehicleSpawnPanel.instance:addToUIManager()
    SZ_VehicleSpawnPanel.instance:setVisible(true)
    SZ_VehicleSpawnPanel.instance:bringToTop()
end

function SZ_VehicleSpawnPanel.hide()
    if SZ_VehicleSpawnPanel.instance then
        SZ_VehicleSpawnPanel.instance:setVisible(false)
        SZ_VehicleSpawnPanel.instance:removeFromUIManager()
    end
end

function SZ_VehicleSpawnPanel.close()
    SZ_VehicleSpawnPanel.hide()
    SZ_VehicleSpawnerWindow.show()
end
