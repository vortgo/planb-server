-- By 🆂🅲🆁🅸🅱🅻
-- Discord: scribl

-- Я не против если вы будете исследовать мои модификации. Не копируйте модификацию!
-- I don't mind if you explore my modifications. Do not copy the modification!

require "TimedActions/ISBaseTimedAction"

ISReadAdBoard = ISBaseTimedAction:derive("ISReadAdBoard");

function ISReadAdBoard:isValid() 
    return true;
end

function ISReadAdBoard:stop() 
    ISBaseTimedAction.stop(self); 
end


function ISReadAdBoard:update()

end

function ISReadAdBoard:waitToStart()
    --self.character:faceThisObject(self.thumpable)
    --return self.character:shouldBeTurning()
    return false;
end

function ISReadAdBoard:start()
	self:setAnimVariable("ReadType", "newspaper");
	self:setActionAnim(CharacterActionAnims.Read);
    SC_Board.ISBoard:initialise();
    SC_Board.ISBoard:addToUIManager();
    SC_Board.ISBoard:setVisible(true);
end

function ISReadAdBoard:perform()
    ISBaseTimedAction.perform(self);
end

function ISReadAdBoard:new(character)
    local o = {};
    setmetatable(o, self);
    self.__index = self;
    o.character = character;
    o.useProgressBar = false;
    o.stopOnWalk = true;
    o.maxDistance = 5;
    o.delay = 5;
    o.stopOnRun = true;
    o.maxTime = -1;
    return o;
end
