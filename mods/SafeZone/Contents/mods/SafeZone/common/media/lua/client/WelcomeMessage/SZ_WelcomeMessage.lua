if not isClient() then return end

SZ_WelcomeMessageUI = ISCollapsableWindow:derive("SZ_WelcomeMessageUI")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local UI_BORDER_SPACING = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6

local function getSV(key)
    if SandboxVars and SandboxVars.SafeZone then
        return SandboxVars.SafeZone[key]
    end
    return nil
end

function SZ_WelcomeMessageUI:new(x, y, width, height)
    local o = {}
    o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor = {r=0, g=0.1, b=0.1, a=0.8}
    return o
end

function SZ_WelcomeMessageUI:create()
    local y = self:titleBarHeight() + UI_BORDER_SPACING

    self.titleLabel = ISLabel:new(0, y, FONT_HGT_LARGE,
        getSV("WelcomeTitle") or "Welcome!", 1, 1, 1, 1, UIFont.Large, true)
    self.titleLabel:setX((self:getWidth() - self.titleLabel:getWidth()) / 2)
    self:addChild(self.titleLabel)

    y = y + FONT_HGT_LARGE + UI_BORDER_SPACING * 2

    local x = UI_BORDER_SPACING + 1
    self.rich = ISRichTextPanel:new(x, y, self.width - x * 2, 300)
    self.rich.anchorLeft = true
    self.rich.anchorRight = true
    self.rich.marginLeft = 0
    self.rich.marginRight = 0
    self.rich:initialise()
    self.rich:instantiate()
    self.rich:noBackground()
    self.rich.backgroundColor = {r=0, g=0.1, b=0.1, a=0.4}
    self.rich.borderColor = {r=1, g=1, b=1, a=0.2}
    self:addChild(self.rich)

    y = y + self.rich:getHeight() + UI_BORDER_SPACING
    x = UI_BORDER_SPACING + 1

    -- Discord URL row
    local discordUrl = getSV("WelcomeDiscordURL") or ""
    self.discordLabel = ISLabel:new(x, y, FONT_HGT_MEDIUM, "Discord:", 0.5, 0.75, 1, 1, UIFont.Medium, true)
    self:addChild(self.discordLabel)
    x = x + self.discordLabel:getWidth() + UI_BORDER_SPACING

    self.discordUrlLabel = ISLabel:new(x, y, FONT_HGT_MEDIUM, discordUrl, 0.9, 0.9, 0.5, 1, UIFont.Medium, true)
    self:addChild(self.discordUrlLabel)
    x = x + self.discordUrlLabel:getWidth() + UI_BORDER_SPACING

    self.btnDiscordOpen = ISButton:new(x, y, 100, 25, getText("IGUI_SZ_WM_Open"), self, function(target)
        local url = getSV("WelcomeDiscordURL")
        if url and url ~= "" then
            openUrl(url)
        end
    end)
    self.btnDiscordOpen:initialise()
    self.btnDiscordOpen:instantiate()
    self.btnDiscordOpen:enableAcceptColor()
    self.btnDiscordOpen:setWidthToTitle(100, false)
    self:addChild(self.btnDiscordOpen)

    x = x + UI_BORDER_SPACING + self.btnDiscordOpen:getWidth()
    self.btnDiscordCopy = ISButton:new(x, y, 100, 25, getText("IGUI_SZ_WM_Copy"), self, function(target)
        local url = getSV("WelcomeDiscordURL")
        if url and url ~= "" then
            Clipboard.setClipboard(url)
            getPlayer():addLineChatElement("Discord URL copied!", 0.5, 1, 0.5)
        end
    end)
    self.btnDiscordCopy:initialise()
    self.btnDiscordCopy:instantiate()
    self.btnDiscordCopy:setWidthToTitle(100, false)
    self:addChild(self.btnDiscordCopy)

    y = y + UI_BORDER_SPACING + self.btnDiscordOpen:getHeight()
    x = UI_BORDER_SPACING + 1

    -- Server URL row
    local serverUrl = getSV("WelcomeServerURL") or ""
    self.serverLabel = ISLabel:new(x, y, FONT_HGT_MEDIUM, getText("IGUI_SZ_WM_Server"), 0.75, 0.5, 1, 1, UIFont.Medium, true)
    self:addChild(self.serverLabel)
    x = x + self.serverLabel:getWidth() + UI_BORDER_SPACING

    self.serverUrlLabel = ISLabel:new(x, y, FONT_HGT_MEDIUM, serverUrl, 0.9, 0.9, 0.5, 1, UIFont.Medium, true)
    self:addChild(self.serverUrlLabel)
    x = x + self.serverUrlLabel:getWidth() + UI_BORDER_SPACING

    self.btnServerOpen = ISButton:new(x, y, 100, 25, getText("IGUI_SZ_WM_Open"), self, function(target)
        local url = getSV("WelcomeServerURL")
        if url and url ~= "" then
            openUrl(url)
        end
    end)
    self.btnServerOpen:initialise()
    self.btnServerOpen:instantiate()
    self.btnServerOpen:enableAcceptColor()
    self.btnServerOpen:setWidthToTitle(100, false)
    self:addChild(self.btnServerOpen)

    x = x + UI_BORDER_SPACING + self.btnServerOpen:getWidth()
    self.btnServerCopy = ISButton:new(x, y, 100, 25, getText("IGUI_SZ_WM_Copy"), self, function(target)
        local url = getSV("WelcomeServerURL")
        if url and url ~= "" then
            Clipboard.setClipboard(url)
            getPlayer():addLineChatElement("Server URL copied!", 0.5, 1, 0.5)
        end
    end)
    self.btnServerCopy:initialise()
    self.btnServerCopy:instantiate()
    self.btnServerCopy:setWidthToTitle(100, false)
    self:addChild(self.btnServerCopy)

    y = y + self.btnServerCopy:getHeight() + UI_BORDER_SPACING
    x = UI_BORDER_SPACING + 1

    -- Close + "Don't show again"
    self.btnClose = ISButton:new(x, y, 100, 25, getText("UI_Close"), self, function(target)
        target:close()
    end)
    self.btnClose:initialise()
    self.btnClose:instantiate()
    self.btnClose:enableCancelColor()
    self.btnClose:setWidthToTitle(100, false)
    self:addChild(self.btnClose)

    x = x + UI_BORDER_SPACING + self.btnClose:getWidth()

    self.cbNotAgain = ISTickBox:new(x, y, 100, 25, "", self, function(target, option, enabled)
        local player = getPlayer()
        player:getModData().SZ_seenWelcome = enabled
        player:transmitModData()
    end)
    self.cbNotAgain:initialise()
    self.cbNotAgain:instantiate()
    self.cbNotAgain:addOption(getText("IGUI_SZ_WM_DontShow"))
    self.cbNotAgain:setWidthToFit()
    local player = getPlayer()
    self.cbNotAgain.selected[1] = player:getModData().SZ_seenWelcome
    self:addChild(self.cbNotAgain)

    y = y + UI_BORDER_SPACING + self.btnClose:getHeight()
    self:setHeight(y + BUTTON_HGT + UI_BORDER_SPACING)
    self:setResizable(false)
end

function SZ_WelcomeMessageUI:initialise()
    ISCollapsableWindow.initialise(self)
    self:create()
end

function SZ_WelcomeMessageUI:render()
    ISCollapsableWindow.render(self)

    local ww = self:getWidth()

    self.titleLabel:setX((ww - self.titleLabel:getWidth()) / 2)
    self.btnClose:setX((ww - self.btnClose:getWidth()) / 2)
    self.cbNotAgain:setX(self.btnClose:getX() - self.cbNotAgain:getWidth() - UI_BORDER_SPACING)

    local maxX = self.btnDiscordOpen:getX()
    if self.btnServerOpen:getX() > maxX then
        maxX = self.btnServerOpen:getX()
    end
    self.btnDiscordOpen:setX(maxX)
    self.btnServerOpen:setX(maxX)
    self.btnDiscordCopy:setX(maxX + UI_BORDER_SPACING + self.btnDiscordOpen:getWidth())
    self.btnServerCopy:setX(maxX + UI_BORDER_SPACING + self.btnServerOpen:getWidth())

    self.rich.text = getSV("WelcomeText") or ""
    self.rich:paginate()
end

SZ_WelcomeMessages = {
    panel = nil,
}

function SZ_WelcomeMessages.createUI()
    if SZ_WelcomeMessages.panel ~= nil then
        return
    end
    SZ_WelcomeMessages.panel = SZ_WelcomeMessageUI:new(60, 60, 650, 550)
    SZ_WelcomeMessages.panel:initialise()
    SZ_WelcomeMessages.panel:setX((getCore():getScreenWidth() / 2) - (SZ_WelcomeMessages.panel.width / 2))
    SZ_WelcomeMessages.panel:setY((getCore():getScreenHeight() / 2) - (SZ_WelcomeMessages.panel.height / 2))
end

function SZ_WelcomeMessages.doMsg()
    local player = getPlayer()
    local playerMD = player:getModData()

    if playerMD.SZ_seenWelcome then
        return
    end

    SZ_WelcomeMessages.createUI()
    SZ_WelcomeMessages.panel:addToUIManager()
    SZ_WelcomeMessages.panel:setVisible(true)
end

local function SZ_OnKeyPressed(key)
    if key ~= Keyboard.KEY_F1 then return end

    if SZ_WelcomeMessages.panel ~= nil then
        if SZ_WelcomeMessages.panel:getIsVisible() then
            SZ_WelcomeMessages.panel:removeFromUIManager()
            SZ_WelcomeMessages.panel:setVisible(false)
        else
            SZ_WelcomeMessages.panel:addToUIManager()
            SZ_WelcomeMessages.panel:setVisible(true)
        end
        return
    end

    SZ_WelcomeMessages.createUI()
    if not SZ_WelcomeMessages.panel then return end
    SZ_WelcomeMessages.panel:addToUIManager()
    SZ_WelcomeMessages.panel:setVisible(true)
end

Events.OnGameStart.Add(SZ_WelcomeMessages.doMsg)
Events.OnKeyPressed.Add(SZ_OnKeyPressed)
