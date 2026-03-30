-- By 🆂🅲🆁🅸🅱🅻
-- Discord: scribl

-- Я не против если вы будете исследовать мои модификации. Не копируйте модификацию!
-- I don't mind if you explore my modifications. Do not copy the modification!

require "Foraging/forageSystem";
require "ISUI/ISPanel";
require "Foraging/ISBaseIcon";

local ISBoardMarkers = ISBaseIcon:derive("ISBoardMarkers");

function ISBoardMarkers:updatePinIconPosition()
	self:updateZoom();
	self:updateAlpha();
	local dx, dy = self:getScreenDelta();
	self:setX(isoToScreenX(self.player, self.xCoord, self.yCoord, self.zCoord) + dx - self.width / 2);
	self:setY(isoToScreenY(self.player, self.xCoord, self.yCoord, self.zCoord) + dy + (self.pinOffset / self.zoom));
	self:setY(self.y - (30 / self.zoom) - (self.height) + (math.sin(self.bounceStep) * self.bounceHeight));
end

function ISBoardMarkers:initialise()
	ISBaseIcon.initialise(self);
	--
	self:findTextureCenter();
	self:findPinOffset();
	--self:initItemCount();
end


function ISBoardMarkers:new(_manager, _icon)
	local o = {};
	o = ISBaseIcon:new(_manager, _icon);
	setmetatable(o, self)
	self.__index = self;
	o.canMoveVertical			= true;
	o.iconClass					= "boardIcon";
	o:initialise();
	return o;
end