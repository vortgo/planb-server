require "SZ_Utils"

local SZ_InfiniteGens = {} ---@type IsoGenerator[]

---@param gen IsoGenerator
local function SZ_RegisterInfiniteGen(gen)
    if not gen then return end
    local data = gen:getModData()
    if not data then return end
    data['_isFuelInfinite'] = true
    SZ_InfiniteGens[#SZ_InfiniteGens + 1] = gen
end

---@param gen IsoGenerator
local function SZ_UnregisterInfiniteGen(gen)
    for i = #SZ_InfiniteGens, 1, -1 do
        local gen2 = SZ_InfiniteGens[i]
        if not gen2 or (gen2:getObjectIndex() == -1) or (gen2:getObjectIndex() == gen:getObjectIndex()) then
            table.remove(SZ_InfiniteGens, i)
        end
    end
end

local maintainGenTicks = 0

-- Maintenance is handled server-side in infinite_gen.lua
-- Client only needs the list for context menu and pickup protection


-- Block non-admin from picking up infinite generators
if ISTakeGenerator and ISTakeGenerator.isValid then
    local _oldIsValid = ISTakeGenerator.isValid

    function ISTakeGenerator:isValid()
        if self.generator and self.generator.getModData then
            local data = self.generator:getModData()
            if data and data["_isFuelInfinite"] and not SZ_Utils.IsAdminPlayer() then
                getPlayer():addLineChatElement(
                    getText("IGUI_SZ_InfGen_AdminOnly"),
                    1, 0, 0
                )
                return false
            end
        end
        return _oldIsValid(self)
    end
end


---@param gen IsoGenerator
local function SZ_MakeInfiniteGen(gen)
    if not gen then return end
    local sq = gen:getSquare()
    if not sq then return end
    sendClientCommand(getPlayer(), "SZInfiniteGen", "makeInfinite", {
        x = sq:getX(), y = sq:getY(), z = sq:getZ()
    })
    -- Optimistic local update for responsiveness
    SZ_RegisterInfiniteGen(gen)
    getPlayer():addLineChatElement(getText("IGUI_SZ_InfGen_SetInfinite"), 1, 1, 0)
end

---@param gen IsoGenerator
local function SZ_MakeNormalGen(gen)
    if not gen then return end
    local sq = gen:getSquare()
    if not sq then return end
    sendClientCommand(getPlayer(), "SZInfiniteGen", "makeNormal", {
        x = sq:getX(), y = sq:getY(), z = sq:getZ()
    })
    SZ_UnregisterInfiniteGen(gen)
    getPlayer():addLineChatElement(getText("IGUI_SZ_InfGen_SetNormal"), 1, 1, 0)
end

---@param context ISContextMenu
---@return ISContextMenu?
local function findGeneratorSubmenu(context)
    local generatorOption = nil
    local localizedName = getText("ContextMenu_Generator")
    for k, v in pairs(context:getMenuOptionNames()) do
        local opt = v
        if opt.name == localizedName or opt.iconTexture == "Item_Generator" then
            generatorOption = opt
            break
        end
    end
    if not generatorOption then return nil end
    if not generatorOption.subOption then return nil end
    return context:getSubMenu(generatorOption.subOption)
end

---@param player integer
---@param context ISContextMenu
---@param worldObjects IsoObject[]
---@param _test boolean
local function SZ_GenWorldContextMenu(player, context, worldObjects, _test)
    if not SZ_Utils.IsAdminPlayer() then return end
    local subMenu = findGeneratorSubmenu(context)
    if not subMenu then
        subMenu = context
    end

    for _, obj in ipairs(worldObjects) do
        if obj:getObjectName() == "IsoGenerator" then
            local gen = obj ---@type IsoGenerator
            local data = gen:getModData()
            if data and data['_isFuelInfinite'] then
                -- Already registered, keep in list
                SZ_RegisterInfiniteGen(gen)
                local opt = subMenu:addOption(getText("IGUI_SZ_InfGen_MakeNormal"), gen, SZ_MakeNormalGen, gen)
                opt.iconTexture = getTexture("media/ui/BugIcon.png")
            else
                local opt = subMenu:addOption(getText("IGUI_SZ_InfGen_MakeInfinite"), gen, SZ_MakeInfiniteGen, gen)
                opt.iconTexture = getTexture("media/ui/BugIcon.png")
            end
            return
        end
    end
end

---@param square IsoGridSquare
local function SZ_OnLoadGridsquare(square)
    local objects = square and square:getObjects() or nil
    if not objects then return end
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local data = obj and obj.getModData and obj:getModData() or nil
        if data and data['_isFuelInfinite'] then
            SZ_InfiniteGens[#SZ_InfiniteGens + 1] = obj
        end
    end
end

Events.LoadGridsquare.Add(SZ_OnLoadGridsquare)
Events.OnFillWorldObjectContextMenu.Add(SZ_GenWorldContextMenu)
