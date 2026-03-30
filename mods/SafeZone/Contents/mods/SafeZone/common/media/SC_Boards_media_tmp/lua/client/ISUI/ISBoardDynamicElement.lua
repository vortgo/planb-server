-- By 🆂🅲🆁🅸🅱🅻
-- Discord: scribl

-- Я не против если вы будете исследовать мои модификации. Не копируйте модификацию!
-- I don't mind if you explore my modifications. Do not copy the modification!

require "ISUI/ISPanel";

ISBoardDynamicElement = ISPanel:derive("ISBoardDynamicElement");

function ISBoardDynamicElement:prerender()
    ISPanel.prerender(self);
    if self.image == nil then
        return;
    end
    self:drawTextureScaledAspect(self.image, 0, 0, self.width, self.height, 1, self.textureColor.r, self.textureColor.g, self.textureColor.b);
end

function ISBoardDynamicElement:render()
    ISPanel.render(self);
end

function ISBoardDynamicElement:createChildren()

end

function ISBoardDynamicElement:destroy()
    self:setVisible(false);
    self:removeFromUIManager();
end

function ISBoardDynamicElement:new(x, y, width, height, image)
    local o = {};
    o = ISPanel:new(x, y, width, height);
    o.textureColor = {r=1.0, g=1.0, b=1.0, a=1.0};
    o.backgroundColor = {r=0, g=1, b=0, a=0};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0};
    o.width = width;
    o.height = height;
    o.image = image;
    o.moveWithMouse = false;
    setmetatable(o, self);
    self.__index = self;
    return o;
end