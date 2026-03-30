-- By 🆂🅲🆁🅸🅱🅻
-- Discord: scribl

-- Я не против если вы будете исследовать мои модификации. Не копируйте модификацию!
-- I don't mind if you explore my modifications. Do not copy the modification!

-- TODO Переделать ID на GUID!

local SC_BoardObject = {};

-- [[ GET ]]

function SC_BoardObject:getBoard(boardID)
    return self.boards[boardID];
end

function SC_BoardObject:getBoardByCoord(x,y,z)
    local boardID = self:getID(x,y,z);
    return self.boards[boardID];
end

function SC_BoardObject:getBoards(playerObj)
    if isClient() then
        sendClientCommand(getPlayer(), self.moduleName, "getBoards", {})
        return;
    end
    sendServerCommand(playerObj, self.moduleName, "sendBoards", self.boards)
end

function SC_BoardObject:getBoardAds(boardID, playerObj)
    if isClient() then
        if not self.boards[boardID] then
            -- INFO : BOARD NOT EXISTS
            return;
        end
        sendClientCommand(getPlayer(), self.moduleName, "getBoardAds", { id = boardID })
        return;
    end
    sendServerCommand(playerObj, self.moduleName, "sendBoardAds", self.boardsAds[boardID])
end

-- [[ END GET ]]

--[[ ADD/SET ]]
function SC_BoardObject:addBoard(x,y,z, limitAds, title, marker, styleBoard, isBlocked)
    local boardID = self:getID(x,y,z);
    if isClient() then
        if self.boards[boardID] then
            -- INFO : BOARD EXISTS
            return;
        end
        sendClientCommand(getPlayer(), self.moduleName, "addBoard", { 
            x = x, 
            y = y, 
            z = z,
            limit = limitAds,
            title = title,
            marker = marker,
            styleBoard = styleBoard,
            isBlocked = isBlocked
        });
        return;
    end
    if not limitAds or limitAds <= 0 or limitAds > 100 then
        limitAds = 10;
    end

    self.boards[boardID] = { x = x, y = y, z = z, limit = limitAds, title = title , marker = marker, styleBoard = styleBoard, isBlocked = isBlocked};
    self.boardsAds[boardID] = {};
    self:updateBoard(boardID);
    self:SaveModData();
    self:Logger(string.format("create board at x = %s, y = %s, z = %s",x ,y ,z ));
end


function SC_BoardObject:addAdBoard(boardID, uuid, title, text, isBlocked)
    if not self.boards[boardID] then
        return;
    end
    if isClient() then
        sendClientCommand(getPlayer(), self.moduleName, "addAdBoard", { id = boardID, uuid = uuid, title = title, text = text, isBlocked = isBlocked });
        return;
    end
    self.boardsAds[boardID][uuid] = { uuid = uuid, isBlocked = isBlocked, title = title, text = text }
    self:updateSpecificAd(boardID, uuid)
    self:SaveModData();
    self:Logger(string.format("added an advertisement boardID = %s, title = %s", boardID, title ));
end

--[[ END ADD/SET ]]

-- [[ DELETE ]]

function SC_BoardObject:delAdBoard(boardID, aduuid)
    if not self.boards[boardID] then
        -- INFO : BOARD NOT EXISTS
        return;
    end
    if isClient() then
        sendClientCommand(getPlayer(), self.moduleName, "delAdBoard", { boardID = boardID, uuid = aduuid});
        return;
    end
    self:Logger(string.format("deleted ad boardID = %s, title = %s", boardID, self.boardsAds[boardID][aduuid].title));
    self.boardsAds[boardID][aduuid] = nil;
    self:updateSpecificAd(boardID, aduuid);
    self:SaveModData();
end

function SC_BoardObject:delBoard(x,y,z)
    local boardID = self:getID(x,y,z);
    if isClient() then
        if not self.boards[boardID] then
            -- INFO : BOARD NOT EXISTS
            return;
        end
        sendClientCommand(getPlayer(), self.moduleName, "delBoard", { x = x, y = y, z = z })
        return;
    end

    self.boards[boardID] = nil;
    self.boardsAds[boardID] = nil;
    self:updateBoard(boardID);
    self:SaveModData();
    self:Logger(string.format("deleted boardID = %s", boardID));
end

-- [[ END DELETE ]]

-- [[ FUNCS ]]

function SC_BoardObject:Logger(msg,a)
    --string.format('[%s] %s: [SCRPCore] %s',os.date('%H:%M:%S'),loggerLevel,message)
    writeLog("boards", "[ "..self.player:getUsername().." ] "..msg);
end

function SC_BoardObject:isBoard(x,y,z)
    local boardID = self:getID(x,y,z);
    if self.boards[boardID] then
        return true;
    end
    return false;
end

function SC_BoardObject:getID(x,y,z)
    if x == nil or x <= 0 then x = 0; end
    if y == nil or y <= 0 then y = 0; end
    if z == nil or z <= 0 then z = 0; end
    return x..y..z;
end

function SC_BoardObject:SaveModData()
    ModData.add(self.moduleName.."_Boards", self.boards);
    ModData.add(self.moduleName.."_Ads", self.boardsAds);
end

function SC_BoardObject:updateSpecificAd(boardID, uuid)
    sendServerCommand(self.moduleName, "sendUpdateSpecificAd", { boardID = boardID, uuid = uuid, ad = self.boardsAds[boardID][uuid] });
end

function SC_BoardObject:updateBoard(currentBoard)
    if isServer() then
        sendServerCommand(self.moduleName, "sendUpdateBoard", { boardID = currentBoard, board = self.boards[currentBoard] });
        -- INFO: BOARD NOT EXISTS!
        return;
    end
    
    if currentBoard.board == nil then
        self.boards[currentBoard.boardID] = nil
        self.boardsAds[currentBoard.boardID] = nil;
        if self.boardMarkers[currentBoard.boardID] then
            getIsoMarkers():removeIsoMarker(self.boardMarkers[currentBoard.boardID]:getID());
            self.boardMarkers[currentBoard.boardID] = nil;
        end
        return;
    end
    local boardID = self:getID(currentBoard.board.x, currentBoard.board.y, currentBoard.board.z);
    self.boards[boardID] = currentBoard.board;
    if self.boardMarkers[boardID] then
        getIsoMarkers():removeIsoMarker(self.boardMarkers[boardID]:getID());
    end
    local sq = getSquare(currentBoard.board.x, currentBoard.board.y, currentBoard.board.z);
    self:addMarker(boardID, sq, currentBoard.board.marker)
end

function SC_BoardObject:createMarkers()
    if not isClient() then return; end
    if not SandboxVars.SCBoard.EnableBoards then return; end
    if not SandboxVars.SCBoard.EnableSpawnMarkers then return; end
    for boardID, values in pairs(self.boards) do
        local sq = getSquare(values.x, values.y, values.z);
        self:addMarker(boardID, sq, values.marker);
    end 
end

function SC_BoardObject:addMarker(boardID, sq, marker)
    if not SandboxVars.SCBoard or not SandboxVars.SCBoard.EnableSpawnMarkers then return; end
    if tonumber(marker) == 3 then return; end
    if sq == nil then return; end
    if marker == nil then marker = 1; end
    local spriteName = "media/ui/markers/SC_BoardMaker"..marker..".png"
    local ok, result = pcall(function()
        return getIsoMarkers():addIsoMarker(spriteName, sq, 1, 1, 1, 1.0)
    end)
    if ok and result then
        self.boardMarkers[boardID] = result
    else
        print("[SC_Board] addMarker failed: " .. tostring(result))
    end
end

--[[ END FUNCS ]]

-- [[ HOOKS ]]

function SC_BoardObject:OnInitGlobalModData()
    self.boards = ModData.getOrCreate(self.moduleName.."_Boards")
    self.boardsAds = ModData.getOrCreate(self.moduleName.."_Ads")
end

function SC_BoardObject:OnGameStart()
    if isServer() then return; end
    local delay = 0;
    local curr = 0;
    local function onTick()
        if getPlayer() and delay>=10 then
            Events.OnTick.Remove(onTick);
            self:getBoards();
        end
        delay = delay + 1
    end
    Events.OnTick.Add(onTick);
end

function SC_BoardObject:LoadGridsquare(sq)
    local board = self:getBoardByCoord(sq:getX(),sq:getY(), sq:getZ());
    if not board then return; end
    local boardID = self:getID(sq:getX(), sq:getY(), sq:getZ());
    self:addMarker(boardID, sq, board.marker);
end

function SC_BoardObject:OnServerCommand(module, cmd, args) -- Client
    if module ~= self.moduleName then return; end
    if cmd == "sendBoardAds" then -- args = { }
        SC_Board.LoadingAds(args);
        return;
    end

    if cmd == "sendUpdateSpecificAd" then -- args = { }
        SC_Board.UpdateSpecificAd(args.boardID, args.uuid, args.ad);
        return;
    end

    if cmd == "sendUpdateBoard" then -- args = { boardID , { x, y, z, limit, title, marker } }
        self:updateBoard(args);
        return;
    end
    if cmd == "sendBoards" then -- args = { { x, y, z, limit, title, marker}, ... }
        if args and args ~= {} then
            self.boards = args;
            self:createMarkers();
        end
        return;
    end
end

function SC_BoardObject:isAdmin(playerObj)
    local level = playerObj:getAccessLevel()
    return level == "Admin" or level == "admin"
end

function SC_BoardObject:sanitizeText(text, maxLen)
    if type(text) ~= "string" then return "" end
    if #text > (maxLen or 2000) then
        text = string.sub(text, 1, maxLen or 2000)
    end
    return text
end

function SC_BoardObject:OnClientCommand(module, cmd, playerObj, args) -- Server
    if module ~= self.moduleName then return; end
    self.player = playerObj;

    local isAdm = self:isAdmin(playerObj)

    if cmd == "getBoardAds" then -- args = { id }
        self:getBoardAds(args.id, playerObj);
        return;
    end
    if cmd == "getBoards" then
        self:getBoards(playerObj)
        return;
    end

    -- Write operations require validation
    if cmd == "addBoard" then
        if not isAdm then
            self:Logger("BLOCKED addBoard from non-admin " .. playerObj:getUsername())
            return;
        end
        local title = self:sanitizeText(args.title, 200)
        local limitAds = tonumber(args.limit) or 10
        if limitAds <= 0 or limitAds > 100 then limitAds = 10 end
        self:addBoard(args.x, args.y, args.z, limitAds, title, args.marker, args.styleBoard, args.isBlocked);
        return;
    end
    if cmd == "delBoard" then
        if not isAdm then
            self:Logger("BLOCKED delBoard from non-admin " .. playerObj:getUsername())
            return;
        end
        self:delBoard(args.x, args.y, args.z);
        return;
    end
    if cmd == "addAdBoard" then
        local boardID = args.id
        if not self.boards[boardID] then return end

        -- Enforce server-side ad limit
        local board = self.boards[boardID]
        local adLimit = board.limit or 10
        local adCount = 0
        if self.boardsAds[boardID] then
            for _ in pairs(self.boardsAds[boardID]) do adCount = adCount + 1 end
        end
        if adCount >= adLimit and not isAdm then
            self:Logger("BLOCKED addAdBoard — limit reached for board " .. tostring(boardID))
            return;
        end

        -- Only admins can set isBlocked
        local isBlocked = false
        if isAdm then isBlocked = args.isBlocked end

        local title = self:sanitizeText(args.title, 200)
        local text = self:sanitizeText(args.text, 5000)
        self:addAdBoard(boardID, args.uuid, title, text, isBlocked)
        return;
    end
    if cmd == "delAdBoard" then
        -- Only admins can delete ads (players can't verify ownership server-side)
        if not isAdm then
            self:Logger("BLOCKED delAdBoard from non-admin " .. playerObj:getUsername())
            return;
        end
        self:delAdBoard(args.boardID, args.uuid);
        return;
    end
end

-- [[ END HOOKS ]]

-- [[ NEW ]]

function SC_BoardObject:new()
    local o = {};
    o.moduleName = "SCOBoard";
    o.boards = {};
    o.boardsAds = {};
    o.player = {}
    o.boardMarkers = {}
    -- o.boards[idboard] = { x = x, y = y, z = z, limit = limit };
    -- o.boardsAds[idboard] = { { id = 1, isBlocked = false, title = "Title", text="Advert1" }, ... };
    setmetatable(o, self)
    self.__index = self
    self.__metatable = 'SC_Board'
    return o
end

return SC_BoardObject;
