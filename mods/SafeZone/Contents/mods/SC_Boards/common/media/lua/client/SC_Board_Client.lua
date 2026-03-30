-- By 🆂🅲🆁🅸🅱🅻
-- Discord: scribl

-- Я не против если вы будете исследовать мои модификации. Не копируйте модификацию!
-- I don't mind if you explore my modifications. Do not copy the modification!

if isServer() then return; end
SC_Board = SC_Board or require("SC_Board_Class"):new();
SC_Board.Permissions = SC_Board.Permissions or require("SC_Board_Permissions"):new();

function SC_isAdmin()
    if isAdmin() then return true end
    local player = getPlayer()
    if not player then return false end
    local level = player:getAccessLevel()
    if level and level ~= "" and level ~= "None" and level ~= "none" then
        return true
    end
    return false
end

Events.OnGameStart.Add(function() SC_Board:OnGameStart(); end);
Events.LoadGridsquare.Add(function(sq) SC_Board:LoadGridsquare(sq); end);
Events.OnInitGlobalModData.Add(function() SC_Board.Permissions:OnInitGlobalModData(); end)
Events.OnServerCommand.Add(function(module, command, args) SC_Board:OnServerCommand(module, command, args); end);

-- ISBoard Доска объявлений
-- ISBoardCreate Для создания досок
-- ISBoardDynamicElement Бумажки на заднем фоне
-- ISReadAdBoard Анимация чтения доски
-- SC_Board_Permissions Права на создания и удалени доски игроками

function SC_Board.AddBoard(worldobjects, player, x, y, z)
    SC_Board.ISBoardCreate = ISBoardCreate:new(x,y,z);
    SC_Board.ISBoardCreate:initialise();
    SC_Board.ISBoardCreate:show();
end

function SC_Board.onConfirmRemoveBoard(this, button, board)
    if button.internal == "YES" then
        SC_Board:delBoard(board.x, board.y, board.z);
        if not SC_isAdmin() then
            SC_Board.Permissions:Delete(board.x..board.y..board.z);
        end
    end
    SC_Board.Modal = nil;
end

function SC_Board.RemoveDialog(worldobjects, player, x, y, z)
    SC_Board.Modal = ISModalDialog:new(getCore():getScreenWidth() / 2 - 175,getCore():getScreenHeight() / 2 - 75, 350, 150, getText("UI_SC_RemoveInfo"), true, self, SC_Board.onConfirmRemoveBoard, player, { x = x, y = y, z = z });
    SC_Board.Modal:initialise();
    SC_Board.Modal:addToUIManager();
end

function SC_Board.UpdateSpecificAd(boardID, uuid, ad)
    if not SC_Board.ISBoard then return; end
    if SC_Board.ISBoard:getCurrentBoard() ~= boardID then return; end
    SC_Board.ISBoard:updateListAds(uuid, ad);
end

function SC_Board.LoadingAds(ads)
    if not SC_Board.ISBoard:isVisible() then return; end
    if ads == nil then return; end
    SC_Board.ISBoard:setAds(ads);
end

function SC_Board.ShowBoard(worldobjects, player, x, y, z)
    player = getSpecificPlayer(player) or getPlayer();
    local sq = getSquare(x,y,z);
    if not sq then return; end
    local boardID = SC_Board:getID(x, y, z);
    SC_Board.ISBoard = ISBoard:new(SC_Board:getBoard(boardID));
    if luautils.walkAdj(player, sq) then
        ISTimedActionQueue.add(ISReadAdBoard:new(player));
    end
    SC_Board:getBoardAds(boardID);
end

function SC_Board.OnFillWorldObjectContextMenu(player, context, worldobjects, test)
    print("[SC_Board] ContextMenu called, isAdmin=" .. tostring(SC_isAdmin()) .. " EnableBoards=" .. tostring(SandboxVars.SCBoard and SandboxVars.SCBoard.EnableBoards))
    if not SandboxVars.SCBoard or not SandboxVars.SCBoard.EnableBoards then
        print("[SC_Board] EnableBoards is false or nil, returning")
        return
    end
    local sq = {};
    local x,y,z = 0,0,0;
    for i,v in ipairs(worldobjects) do
		local sq = v:getSquare();
        if sq then
            x = sq:getX();
            y = sq:getY();
            z = sq:getZ();
            break; 
        end
    end

    if SC_Board:isBoard(x, y, z) then
        local BoardContextMenu = context:addOption(getText("ContextMenu_ShowBoard"), worldobjects, SC_Board.ShowBoard, player, x, y, z);
        BoardContextMenu.iconTexture = getTexture("media/ui/icons/SC_Board_ContextMenu.png");
        if SC_isAdmin() or SC_Board.Permissions:IsDeletePossible(x..y..z) then
            local BoardContextMenuSub = context:addOption(getText("ContextMenu_RemoveOBoard"), worldobjects, SC_Board.RemoveDialog, player, x, y, z);
            BoardContextMenuSub.iconTexture = getTexture("media/ui/icons/SC_Board_ContextMenu.png");
        end
        
        --[[local OBoardOption = context:addOption(getText("ContextMenu_ShowBoard"), worldobjects, SC_Board.ShowBoard, player, x, y, z);
        OBoardOption.iconTexture = getTexture("media/ui/icons/SC_Board_ContextMenu.png");
        if SC_isAdmin() or debug then
            local OBoardOptionAdmin = context:addOption(getText("ContextMenu_RemoveOBoard"), worldobjects, SC_Board.RemoveDialog, player, x, y, z);
            OBoardOptionAdmin.iconTexture = getTexture("media/ui/BugIcon.png");
        end]]--
    else

        print("[SC_Board] Not a board, checking create permission: isAdmin=" .. tostring(SC_isAdmin()) .. " IsCreatePossible=" .. tostring(SC_Board.Permissions:IsCreatePossible()))
        if SC_isAdmin() or SC_Board.Permissions:IsCreatePossible() then
            local BoardContextMenu = context:addOption(getText("ContextMenu_CreateOBoard"), worldobjects, SC_Board.AddBoard, player, x, y, z);
            BoardContextMenu.iconTexture = getTexture("media/ui/icons/SC_Board_ContextMenu.png");
            print("[SC_Board] Added Create Board option")
        else
            print("[SC_Board] No permission to create board")
        end
        --[[if SC_isAdmin() or debug then
            local OBoardOptionAdmin = context:addOption(getText("ContextMenu_CreateOBoard"), worldobjects, SC_Board.AddBoard, player, x, y, z);
            OBoardOptionAdmin.iconTexture = getTexture("media/ui/BugIcon.png");
        end]]--
    end
end
Events.OnFillWorldObjectContextMenu.Add(SC_Board.OnFillWorldObjectContextMenu);

