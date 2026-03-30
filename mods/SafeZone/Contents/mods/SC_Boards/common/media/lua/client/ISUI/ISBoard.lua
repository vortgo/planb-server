-- By 🆂🅲🆁🅸🅱🅻
-- Discord: scribl

-- Я не против если вы будете исследовать мои модификации. Не копируйте модификацию!
-- I don't mind if you explore my modifications. Do not copy the modification!

-- TODO Добавить отключение маркеров.
-- TODO Заебал, добавь уже
-- TODO Какой сука смысл писать todo если ты их не читаешь -____________- АЛЛО

require "ISUI/ISPanel";
ISBoard = ISPanel:derive("ISBoard");

function ISBoard:setAds(ads)
    self.boardAds = ads;
    self:fullListAds();
end

function ISBoard:getBoardID(x,y,z)
    if x == nil or x <= 0 then x = 0; end
    if y == nil or y <= 0 then y = 0; end
    if z == nil or z <= 0 then z = 0; end
    return x..y..z;
end

function ISBoard:getDistance(srcX, srcY, dstX, dstY)
    local srcVector = Vector2.new(srcX, srcY);
    local dstVector = Vector2.new(dstX, dstY);
    return srcVector:distanceTo(dstVector);
end

function ISBoard:getDistanceToPlayer()
    return self:getDistance(self.board.x, self.board.y, luautils.round(self.character:getX()), luautils.round(self.character:getY()));
end

function ISBoard:prerender()
    if self.backgroundBoardImage ~= nil then
        self:drawTextureScaledAspect(self.backgroundBoardImage, 0, 0, self.width-0, self.height, 1, self.textureColor.r, self.textureColor.g, self.textureColor.b); --(texture, x, y, w, h, a, r, g, b)
    end
    ISPanel.prerender(self);
end

function ISBoard:render()
    ISPanel.render(self);
    if self.board.title ~= nil then
        self:drawTextCentre(self.board.title, self:getWidth()/2, 5, 1, 1, 1, 1, UIFont.Large); --(str, x, y, r, g, b, a, font)
    end
    if self.delayCheak >= 5 then
        self.delayCheak = 0;
        if self:getDistanceToPlayer() >= self.maxDistanceToBoard then
            self:destroy();
        end
    end
    self.delayCheak = self.delayCheak + 1;
end

function ISBoard:getRandomTexture()
    return getTexture("media/ui/boards/"..self.boardStyle.."/ads/SC_Board_Dynamic_"..ZombRand(1, self.numTexture or 1)..".png");
end

function ISBoard:OnMouseDownAdItem(ad)
    self.selectedAdvert = ad;
    self.buttonDeleteAd:setVisible(false);
    if SC_isAdmin() or ( not self.board.isBlocked and not ad.isBlocked ) then
        self.buttonDeleteAd:setVisible(true);
    end
    if ad.title == nil then ad.title = ""; end
    if ad.text == nil then ad.text = ""; end
    self.cPanels.textAd.text = " <SIZE:medium> <CENTRE> "..ad.title.." <BR>  <LEFT> "..ad.text
    self.cPanels.textAd:paginate();
end

function ISBoard:updateListAds(uuid, ad)
    self.boardAds[uuid] = ad;
    if self.selectedAdvert then
        if self.selectedAdvert.uuid == uuid then
            self.selectedAdvert = nil;
            self.buttonDeleteAd:setVisible(false);
            self.cPanels.textAd.text = getText("UI_SC_AdRemoved");
            self.cPanels.textAd:paginate();
        end
    end

    self:fullListAds();
end

function ISBoard:fullListAds()
    self.listboxAds:clear();
    
    for _i, curAd in pairs(self.boardAds) do
        if curAd ~= nil then
            self.listboxAds:addItem(curAd.title, curAd);
        end
    end
    self.listboxAds.selected = -1;
    self.listboxAds:sort();

    self.buttonAddAd:setVisible(false);
    if SC_isAdmin() or not ( self.listboxAds.count >= self.board.limit ) then
        self.buttonAddAd:setVisible(true);
    end

end

function ISBoard:doDrawItem(y, item, alt)
    local isMouseOver = self.mouseoverselected == item.index and not self:isMouseOverScrollBar()
	if self.selected == item.index then
		self:drawRect(0, (y), self:getWidth(), item.height-1, 0.3, 0.7, 0.35, 0.15);
	elseif isMouseOver then
		self:drawRect(1, y + 1, self:getWidth() - 2, item.height - 2, 0.95, 0.05, 0.05, 0.05);
	end
	--self:drawRectBorder(0, (y), self:getWidth(), item.height, 0.5, self.listboxAds.borderColor.r, self.listboxAds.borderColor.g, self.listboxAds.borderColor.b)
    --self:drawRectBorder(0, (y), self:getWidth(), item.height, 0.5, 1, 0, 0)
	local fontHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight();
	local textY = y + (item.height - fontHgt) / 2

    if SandboxVars.SCBoard.VisualMsgFromAdmin and item.item.isBlocked then
        self:drawRect(0, (y), self:getWidth(), item.height-1, 0.1, 1, 0.5, 0.5);
    end
    self:drawText(item.text, 15, textY, 0.9, 0.9, 0.9, 0.9, UIFont.Medium);

	y = y + item.height
	return y
end

function ISBoard:closeChildrenPanels()
    for key, panel in pairs(self.cPanels) do
        self.cPanels[key]:setVisible(false);
    end
end

function ISBoard:onClickExt(btn)
    -- Для мододелов, можете переопредилить :) For modders, you can redefine it :)
    return;
end

function ISBoard:onClick(btn)
    if btn.internal == "SENDAD" then
        local title = self.cPanels.AddNew.textTitle:getText();
        local text = self.cPanels.AddNew.textAds:getText();

        if title == nil or title == "" or title == " " then return; end
        if text == nil or text == "" or text == " " then return; end

        SC_Board:addAdBoard(
            self.boardID,
            string.sub("A"..getRandomUUID(), 1, 8),
            title,
            text,
            ( self.cPanels.AddNew.OnlyAdmin and self.cPanels.AddNew.OnlyAdmin:isSelected(1) ) or false
        );
        self.cPanels.AddNew.textTitle:setText("");
        self.cPanels.AddNew.textAds:setText("");
        self.buttonBoardNews:forceClick();
        return;
    end
    if btn.internal == "REMOVEAD" then
        if self.selectedAdvert == nil then return; end;
        SC_Board:delAdBoard(
            self.boardID,
            self.selectedAdvert.uuid
        );
        self.cPanels.textAd.text = getText("UI_SC_AdRemoved");
        self.cPanels.textAd:paginate();
        return;
    end
    if btn.internal == "SHOWADS" then
        self:closeChildrenPanels();
        self.cPanels.textAd:setVisible(true);
        self.listboxAds:setVisible(true);
        self.cPanels.textAd.text = "";
        self.listboxAds.selected = -1;
        self.cPanels.textAd:paginate();
        self.buttonDeleteAd:setVisible(false);
        return;
    end
    if btn.internal == "ADDNEWAD" then
        self:closeChildrenPanels();
        self.listboxAds:setVisible(false);
        self.buttonDeleteAd:setVisible(false);
        self.cPanels.AddNew:setVisible(true);
        return;
    end

    self:onClickExt(btn);
end

function ISBoard:dynamicElementIsCollision(sq1, sq2)
    -- Да-да, я знаю что могу сделать в центре квадрата окружность и проверить сложенные размеры радиусов
    -- Но будет так, другие способы тоже есть, НО МНЕ НРАВИТСЯ ТАК.
    -- Ты можешь написать свой код который будет лучше работать и передать его мне, я вставлю.
    -- Yes, yes, I know that I can make a circle in the center of the square and check the added dimensions of the radii
    -- But it will be like this, there are other ways too, BUT I LIKE IT THIS WAY.
    -- You can write your own code that will work better and give it to me, I will insert it.
    local sq1_left = sq1.x;
    local sq1_right = sq1.x + sq1.width+5;
    local sq1_top = sq1.y; 
    local sq1_bottom = sq1.y + sq1.height+5;
    local sq2_left = sq2.x;
    local sq2_right = sq2.x + sq2.width+5;
    local sq2_top = sq2.y;
    local sq2_bottom = sq2.y + sq2.height+5;
    local x_collide = sq1_right >= sq2_left and sq1_left <= sq2_right;
    local y_collide = sq1_bottom >= sq2_top and sq1_top <= sq2_bottom;
    if x_collide and y_collide then
        local top_collision = sq1_bottom >= sq2_top and sq1_top <= sq2_top;
        local bottom_collision = sq1_top <= sq2_bottom and sq1_bottom >= sq2_bottom;
        local left_collision = sq1_right >= sq2_left and sq1_left <= sq2_left;
        local right_collision = sq1_left <= sq2_right and sq1_right >= sq2_right;
        
        return top_collision or bottom_collision or left_collision or right_collision;   
    end
    return false; 
end

function ISBoard:createDynamicTexture()
    if not SandboxVars.SCBoard.BackgroundDynamicVisual then return; end
    for i = 1, self.numDynamicElements do
        local calcCollision = true;
        local texture = self:getRandomTexture();
        local textureWidth = texture:getWidthOrig();
        local textureHeight = texture:getHeightOrig();
        local maxX = self:getWidth()-textureWidth-5-60;
        local maxY = self:getHeight()-textureHeight-5-60;
        local randomX, randomY = 0, 0;
        while calcCollision do
            local wasCollision = false;
            randomX = ZombRand(65, maxX);
            randomY = ZombRand(65, maxY);
            for i, v in ipairs(self.dynamicBackground) do
                local sq1,sq2 = {}, {};
                sq1 = { x = v.x, y = v.y, width = v.width, height = v.height };
                sq2 = { x = randomX, y = randomY, width = textureWidth , height = textureHeight };
                if self:dynamicElementIsCollision(sq1,sq2) then
                    wasCollision = true;
                    self.safeCalculation = self.safeCalculation + 1;
                end
            end
            if not wasCollision or self.safeCalculation >=6 then
                calcCollision = false;
            end
        end
        
        local paper = {};
        paper = ISBoardDynamicElement:new(randomX, randomY, texture:getWidthOrig(), texture:getHeightOrig(), texture);
        paper:initialise();
        self:addChild(paper);
        table.insert(self.dynamicBackground, paper);
    end
end

function ISBoard:cChildsAddNew()
    local o,j = {},{};
    local width = self.cPanels.AddNew:getWidth()
    --self.cPanels.add
    o = ISTextEntryBox:new("", 0, 0, width, 20); --(title, x, y, width, height)
    o.font = UIFont.Large;
    self:setDefaultsPanels(o);
	o:initialise();
	o:instantiate();
    self.cPanels.AddNew.textTitle = o;
    self.cPanels.AddNew:addChild(o);

    j = ISTextEntryBox:new("", 0, o:getBottom() + 10, width, self.cPanels.AddNew:getHeight()-o:getHeight()-50);
    o = nil;
	j:initialise();
	j:instantiate();
    self:setDefaultsPanels(j);
    self.cPanels.AddNew:addChild(j);
    self.cPanels.AddNew.textAds = j;
    self.cPanels.AddNew.textAds:setMultipleLine(true);
    self.cPanels.AddNew.textAds:setMaxLines(100);
	self.cPanels.AddNew.textAds:addScrollBars();

    if SC_isAdmin() then
        self.cPanels.AddNew.textAds:setHeight(j:getHeight()-40);
        local m = ISPanel:new(0, j:getBottom()+10, width, 30); -- (x, y, width, height)
        self:setDefaultsPanels(m);
        m:initialise();
        self.cPanels.AddNew:addChild(m);
        local i = ISTickBox:new(8, m:getY()+5, 20, width, "", nil, nil)
        i:initialise();
        i:instantiate();
        self.cPanels.AddNew:addChild(i);
        self.cPanels.AddNew.OnlyAdmin = i;
        self.cPanels.AddNew.OnlyAdmin:addOption(getText("UI_SC_OnlyAdminsAd"));

        i,m = nil, nil;
    end
    j = nil;

    o = ISButton:new(0, self.cPanels.AddNew:getHeight()-30, width, 30, getText("UI_SCBoard_BtnSendToServer"), self, self.onClick);
    self:setDefaultsButton(o);
    --o.tooltip = "Add new ADS";
    o.internal = "SENDAD";
    o:initialise();
    o:instantiate();
    self.cPanels.AddNew:addChild(o);
    o = nil;
end

function ISBoard:createChildrenExt()
    -- Для мододелов, можете переопредилить :) For modders, you can redefine it :)
    return;
end

function ISBoard:createChildren()
    if self.boardIsAnimated then
        self:createDynamicTexture()
    end

    local y = self.fontHgt + 5 * 2;

    self.listboxAds = ISScrollingListBox:new(40, y, ( (self.width-90) / 8 ) * 3, self.height-y-10); -- w h
    self:setDefaultsPanels(self.listboxAds);
    self.listboxAds:initialise();
    self.listboxAds:instantiate();

    self.listboxAds:setFont(UIFont.Medium, 2);
    self.listboxAds.itemheight = 30;
    self.listboxAds.drawBorder = true;
    self.listboxAds.onmousedown = self.OnMouseDownAdItem;
    self.listboxAds.target = self;
    
    self.listboxAds.doDrawItem = self.doDrawItem
    --self.listboxAds:setOnMouseDoubleClick(self, ISPostDeathUI.onDblClickCustom)

    self:addChild(self.listboxAds);
    self.listboxAds:addScrollBars();

    
    local xForPanels = self.listboxAds:getRight()+10
    local widthForPanels = ( (self.width-90) / 8 ) * 5;
    local heightForPanels = self.height-y-10;

    self.cPanels.textAd = ISRichTextPanel:new(xForPanels, y, widthForPanels, heightForPanels);
    self:setDefaultsPanels(self.cPanels.textAd);
    self.cPanels.textAd.moveWithMouse = true;
    self.cPanels.textAd.autosetheight = false;
    self.cPanels.textAd:initialise();
    self.cPanels.textAd:setMargins(10,10,10,10);
	self:addChild(self.cPanels.textAd);
    self.cPanels.textAd:paginate();
    self.cPanels.textAd:addScrollBars();

    self.cPanels.AddNew = ISPanel:new(xForPanels, y, widthForPanels, heightForPanels);
    self.cPanels.AddNew.backgroundColor = {r=0, g=0, b=0, a=0};
    self.cPanels.AddNew.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
    self.cPanels.AddNew.moveWithMouse = true;
    self.cPanels.AddNew:initialise();
    self:addChild(self.cPanels.AddNew);
    self.cPanels.AddNew:setVisible(false);
    self:cChildsAddNew();

    self.buttonBoardNews = ISButton:new(0, self.listboxAds:getY(), 30, 30, "", self, self.onClick);
    self.buttonBoardNews:setImage(getTexture("media/ui/icons/SC_Board_Button_Advert.png"));
    self.buttonBoardNews:forceImageSize(20, 20);
    self:setDefaultsButton(self.buttonBoardNews);
    self.buttonBoardNews.tooltip = getText("UI_SCBoard_BtnNews");
    self.buttonBoardNews.internal = "SHOWADS";
    self.buttonBoardNews:initialise();
    self.buttonBoardNews:instantiate();
    self:addChild(self.buttonBoardNews);

    -- Disabled btn for next updates
    self.buttonBoardOrders = ISButton:new(0, self.buttonBoardNews:getBottom() + 10, 30, 30, "", self, self.onClick);
    self.buttonBoardOrders:setImage(getTexture("media/ui/icons/SC_Board_Button_Orders.png"));
    self.buttonBoardOrders:forceImageSize(20, 20);
    self:setDefaultsButton(self.buttonBoardOrders);
    self.buttonBoardOrders.tooltip = getText("UI_SCBoard_BtnOrders");
    self.buttonBoardOrders.internal = "SHOWORD";
    self.buttonBoardOrders:initialise();
    self.buttonBoardOrders:instantiate();
    self:addChild(self.buttonBoardOrders);
    self.buttonBoardOrders:setVisible(false);

    --[[ Right Panel ]]
    local x = self.width-30;
    self.buttonClose = ISButton:new(x, self.listboxAds:getY(), 30, 30, "", self, self.destroy);
    self.buttonClose:setImage(getTexture("media/ui/icons/SC_Board_Button_Exit.png"));
    self.buttonClose:forceImageSize(15, 15);
    self:setDefaultsButton(self.buttonClose);
    self.buttonClose.tooltip = getText("UI_SCBoard_BtnClose");
    self.buttonClose:initialise();
    self.buttonClose:instantiate();
    self:addChild(self.buttonClose);

    self.buttonAddAd = ISButton:new(x, self.buttonClose:getBottom()+50, 30, 30, "", self, self.onClick);
    self.buttonAddAd:setImage(getTexture("media/ui/icons/SC_Board_Button_Plus.png"));
    self.buttonAddAd:forceImageSize(20, 20);
    self:setDefaultsButton(self.buttonAddAd);
    self.buttonAddAd.tooltip = getText("UI_SCBoard_BtnAddNewAds");
    self.buttonAddAd.internal = "ADDNEWAD";
    self.buttonAddAd:initialise();
    self.buttonAddAd:instantiate();
    self:addChild(self.buttonAddAd);

    self.buttonDeleteAd = ISButton:new(x, self.buttonAddAd:getBottom()+10, 30, 30, "", self, self.onClick);
    self.buttonDeleteAd:setImage(getTexture("media/ui/icons/SC_Board_Button_Trash.png"));
    self.buttonDeleteAd:forceImageSize(20, 20);
    self:setDefaultsButton(self.buttonDeleteAd);
    self.buttonDeleteAd.tooltip = getText("UI_SCBoard_BtnRemoveCurrentAd");
    self.buttonDeleteAd.internal = "REMOVEAD";
    self.buttonDeleteAd:initialise();
    self.buttonDeleteAd:instantiate();
    self:addChild(self.buttonDeleteAd);
    self.buttonDeleteAd:setVisible(false);

    if self.board.isBlocked and not SC_isAdmin() then
        self.buttonAddAd:setVisible(false);
        self.buttonDeleteAd:setVisible(false);
    end
    self:createChildrenExt();
end

function ISBoard:setDefaultsPanels(panel)
    panel.backgroundColor = {r=0, g=0, b=0, a=0.6};
    panel.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
end

function ISBoard:setDefaultsButton(buttn)
    buttn.backgroundColor = {r=0, g=0, b=0, a=0.5};
    buttn.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
end

function ISBoard:destroy()
    ISTimedActionQueue.clear(getPlayer());
    self:setVisible(false);
    self:removeFromUIManager();
end
function ISBoard:getCurrentBoard()
    return self.boardID;
end

function ISBoard:new(board)
    local o = {};
    local windowWidth = 890;
    local windowHeight = 620;
    local x = ( getCore():getScreenWidth() - windowWidth)/2;
    local y = ( getCore():getScreenHeight() - windowHeight)/2;

    o = ISPanel:new(x, y, windowWidth, windowHeight);
    o.moveWithMouse = true;
    o.backgroundColor = {r=1, g=0, b=0, a=0};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
    o.textureColor = {r=1.0, g=1.0, b=1.0, a=1.0};

    setmetatable(o, self);
    self.__index = self;

    o.board = board;
    o.boardAds = {};
    o.delayCheak = 0;
    o.safeCalculation = SandboxVars.SCBoard.safeCalculation or 6;
    o.maxDistanceToBoard = SandboxVars.SCBoard.MaxDistanceToBoard
    o.selectedAdvert = {};
    o.dynamicBackground = {};
    o.cPanels = {}
    o.character = getPlayer();
    o.moduleName = "SCOBoard";
    o.boardID = self:getBoardID(board.x,board.y,board.z);
    o.fontHgt = getTextManager():getFontFromEnum(UIFont.Large):getLineHeight();
    o.boardStyle = SC_BoardStyles[board.styleBoard].name;
    if o.boardStyle then
        o.backgroundBoardImage = getTexture("media/ui/boards/"..o.boardStyle.."/SC_Board_Background.png");
    end
    o.boardIsAnimated = SC_BoardStyles[board.styleBoard].isAnimated
    if o.boardIsAnimated then
        o.numTexture = SC_BoardStyles[board.styleBoard].numTexture
        o.numDynamicElements = SC_BoardStyles[board.styleBoard].numDynamicElements
    end
    
    if o.board.title then
        o.sizeTitleLabel = getTextManager():MeasureStringX(UIFont.Large, o.board.title) + 20;
    end

    return o;
end