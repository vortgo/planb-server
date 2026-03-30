-- By 🆂🅲🆁🅸🅱🅻
-- Discord: scribl

-- Я не против если вы будете исследовать мои модификации. Не копируйте модификацию!
-- I don't mind if you explore my modifications. Do not copy the modification!

require "ISUI/ISCollapsableWindow"
ISBoardCreate = ISCollapsableWindow:derive("ISBoardCreate");

function ISBoardCreate:prerender()
    ISCollapsableWindow.prerender(self);
end

function ISBoardCreate:getBoardID(x,y,z)
    if x == nil or x <= 0 then x = 0; end
    if y == nil or y <= 0 then y = 0; end
    if z == nil or z <= 0 then z = 0; end
    return x..y..z;
end

function ISBoardCreate:render()
    ISCollapsableWindow.render(self);
end

function ISBoardCreate:fullStylesBoard()
    -- TODO: Добавить рендер текстурок в tooltip
    --local styleBoardtoolTip = { defaultTooltip = "" };
    for i, v in ipairs(SC_BoardStyles) do
        self.styleBoard:addOption(v.name, v.name);
        --table.insert( styleBoardtoolTip[v], getTexture("media/ui/boards/"..v.."/SC_Board_Background_"..v..".png");)
    end
    self.styleBoard.selected = 1;
    --self.styleBoard:setToolTipMap(styleBoardtoolTip);
end

function ISBoardCreate:onSelectNewSquare()
    local p = getPlayer();
	self.cursor = ISSelectCursor:new(p, self, self.onSquareSelected);
	getCell():setDrag(self.cursor, p:getPlayerNum());
end

function ISBoardCreate:onSquareSelected(square)
    self.cursor = nil;
    if not square then return; end
	self.board.x = square:getX();
	self.board.y = square:getY();
	self.board.z = square:getZ();
    local text = "X = "..self.board.x.."     ver. 1.0.0\nY = "..self.board.y.."     Board ID:\nZ = "..self.board.z.."            "..self:getBoardID(self.board.x, self.board.y, self.board.z);
    self.posLabel:setName(text);
    self.createBoard:setEnable(true);
    if SC_Board:isBoard(self.board.x, self.board.y, self.board.z) then
        self.createBoard:setEnable(false);
    end
end

function ISBoardCreate:onClick(btn)
    if btn.internal == "SEND" then
        --(x,y,z, limitAds, title, marker, styleBoard, isBlocked)
        --SC_Board.Permissions:IsCreatePossible()
        if SC_Board:isBoard(self.board.x, self.board.y, self.board.z) then return; end
        SC_Board:addBoard(
            self.board.x,
            self.board.y,
            self.board.z,
            tonumber(self.limitAds:getText()),
            self.nameBoard:getText(),
            tonumber(self.typeMarker.selected),
            tonumber(self.styleBoard.selected),
            self.boardForOnlyAdmins:isSelected(1)
        );
        if not isAdmin() then
            SC_Board.Permissions:Create(self.board.x..self.board.y..self.board.z);
        end
        self:close();
        return;
    end
    local value = tonumber(self.limitAds:getText());
    if btn.internal == "UP" then
        if value >= 100 then self.limitAds:setText("100"); return; end
        self.limitAds:setText(""..value + 1);
        return;
    end
    if btn.internal == "DOWN" then
        if value == 1 then self.limitAds:setText("1"); return; end
        self.limitAds:setText(""..value - 1);
        return;
    end
end

function ISBoardCreate:createChildren()
    ISCollapsableWindow.createChildren(self)
    
    local x, y = 8, 35;
    local text = "X = "..self.board.x.."     ver. 1.0.0\nY = "..self.board.y.."     Board ID:\nZ = "..self.board.z.."            "..self:getBoardID(self.board.x, self.board.y, self.board.z);
    self.posLabel = ISLabel:new(x, y, getTextManager():getFontHeight(UIFont.NewSmall), text, 1, 1, 1, 1, UIFont.NewSmall, true);
    self.posLabel:initialise();
    self.posLabel:instantiate();
    self:addChild(self.posLabel);

	self.pickNewSq = ISButton:new(x, self.posLabel:getBottom() + 20, self.width-x*2, 20, getText("UI_SC_SelectSq"), self, ISBoardCreate.onSelectNewSquare);
	self.pickNewSq:initialise();
	self.pickNewSq:instantiate();
	self:addChild(self.pickNewSq);

    self.typeMarker = ISComboBox:new(x, self.pickNewSq:getBottom() + 10 , self.width-x*2, 20, self);
	self.typeMarker:initialise();
    self.typeMarker:addOption(getText("UI_SC_MarkerLeft"));
	self.typeMarker:addOption(getText("UI_SC_MarkerRight"));
    self.typeMarker:addOption(getText("UI_SC_NotMarker"));
    self.typeMarker:setToolTipMap({ defaultTooltip = getText("UI_SC_MarkerInfo") });
    self.typeMarker.selected = 1;
	self:addChild(self.typeMarker);

    self.styleBoard = ISComboBox:new(x, self.typeMarker:getBottom() + 10 , self.width-x*2, 20, self);
	self.styleBoard:initialise();
    self.styleBoard:setToolTipMap({ defaultTooltip = getText("UI_SC_StyleBoardInfo") });
    self:fullStylesBoard();
    self.styleBoard.selected = 1;
	self:addChild(self.styleBoard);

    self.limitAds = ISTextEntryBox:new("10", x, self.styleBoard:getBottom() + 10, self.width-x*2-41, 20);
    self.limitAds.font = UIFont.NewSmall;
    self.limitAds.tooltip = getText("UI_SC_LimitInfo");
	self.limitAds:initialise();
	self.limitAds:instantiate();
    self.limitAds:setEditable(false);
    self:addChild(self.limitAds);

    self.limitAdsUP = ISButton:new(self.limitAds:getX()+self.limitAds:getWidth(), self.limitAds:getY(), 20, 20, "", self, self.onClick);
    self.limitAdsUP.internal = "UP";
    self.limitAdsUP.tooltip = getText("UI_SC_LimitInfo");
    self.limitAdsUP:setImage(getTexture("media/textures/highlights/dir_arrow_up.png"));
    self.limitAdsUP:initialise();
	self.limitAdsUP:instantiate();
    self:addChild(self.limitAdsUP);

    self.limitAdsDown = ISButton:new(self.limitAdsUP:getX()+self.limitAdsUP:getWidth(), self.limitAdsUP:getY(), 20, 20, "", self, self.onClick);
    self.limitAdsDown.internal = "DOWN";
    self.limitAdsDown.tooltip = getText("UI_SC_LimitInfo");
    self.limitAdsDown:setImage(getTexture("media/textures/highlights/dir_arrow_down.png"));
    self.limitAdsDown:initialise();
	self.limitAdsDown:instantiate();
    self:addChild(self.limitAdsDown);

    self.nameBoard = ISTextEntryBox:new("", x, self.limitAds:getBottom() + 10, self.width-x*2, 20);
    self.nameBoard.font = UIFont.NewSmall;
	self.nameBoard:initialise();
	self.nameBoard:instantiate();
    self.nameBoard.tooltip = getText("UI_SC_BoardName");
    self:addChild(self.nameBoard);

    self.boardForOnlyAdmins = ISTickBox:new(x, self.nameBoard:getBottom() + 10, 20, self.width-x*2, "", nil, nil)
    self.boardForOnlyAdmins.tooltip = getText("UI_SC_OnlyAdminsBoard");
    self.boardForOnlyAdmins:initialise()
    self:addChild(self.boardForOnlyAdmins)
    self.boardForOnlyAdmins:addOption(getText("UI_SC_OnlyAdmins"));
    
    if not isAdmin() then
        self.boardForOnlyAdmins:setVisible(false);
    end

    --local infoLabel = ISLabel:new(x, self.boardForOnlyAdmins:getBottom()+10, getTextManager():getFontHeight(UIFont.NewSmall), getText("UI_SC_InfoAtCreate"), 1, 1, 1, 1, UIFont.NewSmall, true);
    --infoLabel:initialise();
    --infoLabel:instantiate();
    --self:addChild(infoLabel);

    self.createBoard = ISButton:new(x, self.boardForOnlyAdmins:getBottom() + 20, self.width-x*2, 20, getText("UI_SC_Create"), self, self.onClick);
    self.createBoard.internal = "SEND";
    self.createBoard:initialise();
	self.createBoard:instantiate();
    self:addChild(self.createBoard);

    self:setHeight(self.createBoard:getY() + self.createBoard:getHeight() + 10);
end

function ISBoardCreate:show()
    self:addToUIManager();
    self:setVisible(true);
end

function ISBoardCreate:close()
    self:setVisible(false);
    self:removeFromUIManager();
end

function ISBoardCreate:new(boardX,boardY,boardZ)
    local o = {};
    local windowWidth = 150;
    local windowHeight = 200;
    local sWidth = getCore():getScreenWidth()-300;
    local sHeight = getCore():getScreenHeight();
    local x = (sWidth - windowWidth)/2;
    local y = (sHeight - windowHeight)/2;
    o = ISCollapsableWindow:new(x, y, windowWidth, windowHeight);
    setmetatable(o, self);
    self.__index = self;
    o.width = windowWidth;
	o.height = windowHeight;
    o.char = getPlayer();
    o.resizable = false;
    o.title = getText("UI_SC_AddBoard");
    o.board = { x = boardX, y = boardY, z = boardZ };
    return o;
end