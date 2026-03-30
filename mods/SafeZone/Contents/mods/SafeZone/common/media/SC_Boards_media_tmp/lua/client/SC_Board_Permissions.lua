-- By 🆂🅲🆁🅸🅱🅻
-- Discord: scribl

-- Я не против если вы будете исследовать мои модификации. Не копируйте модификацию!
-- I don't mind if you explore my modifications. Do not copy the modification!

local SC_Permissions = {};

function SC_Permissions:Delete(boardID)
    self.storage.count = self.storage.count - 1;
    self.storage.boards[boardID] = nil;
    self:SaveModData();
end

function SC_Permissions:Create(boardID)
    self.storage.count = self.storage.count + 1;
    self.storage.boards[boardID] = true;
    self:SaveModData();
end

function SC_Permissions:IsDeletePossible(boardID)
    if SandboxVars.SCBoard.AllowPlayersToCreateBoards and self.storage.boards[boardID] == true then
        return true;
    end
    return false;
end

function SC_Permissions:IsCreatePossible()
    if not SandboxVars.SCBoard.AllowPlayersToCreateBoards then
        return false;
    end
    if self.storage.count >= SandboxVars.SCBoard.LimitPlayersToCreateBoards then
        return false;
    end
    return true;
end

function SC_Permissions:SaveModData()
    ModData.add(self.moduleName, self.storage);
end

function SC_Permissions:OnInitGlobalModData()
    self.storage = ModData.getOrCreate(self.moduleName);
    if not self.storage.count then
        self.storage = { count = 0, boards = {} };
    end
end

function SC_Permissions:new()
    local o = {};
    o.moduleName = "SC_Board_Permissions";
    setmetatable(o, self)
    self.__index = self
    self.__metatable = 'SC_Board_Perm'
    return o
end

return SC_Permissions;