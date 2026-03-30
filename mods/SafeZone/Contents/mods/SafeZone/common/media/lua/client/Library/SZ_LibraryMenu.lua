require "SZ_Utils"

-- =========================================================================
-- Library — admin marks shelves, books can't be moved to bags/ground/cars
-- =========================================================================

-- ----- Context menu (admin only) -----------------------------------------

local function findContainerObject(worldobjects)
    for _, obj in ipairs(worldobjects) do
        if obj:getContainer() then
            return obj
        end
        local square = obj:getSquare()
        if square then
            for i = 0, square:getObjects():size() - 1 do
                local sqObj = square:getObjects():get(i)
                if sqObj:getContainer() then
                    return sqObj
                end
            end
        end
    end
    return nil
end

local function onMarkShelf(playerNum, obj)
    local playerObj = getSpecificPlayer(playerNum)
    local sq = obj:getSquare()
    sendClientCommand(playerObj, "SafeZoneLibrary", "mark", {
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
    })
    playerObj:addLineChatElement("Shelf marked as Library", 0.2, 1, 0.2)
end

local function onUnmarkShelf(playerNum, obj)
    local playerObj = getSpecificPlayer(playerNum)
    local sq = obj:getSquare()
    sendClientCommand(playerObj, "SafeZoneLibrary", "unmark", {
        x = sq:getX(),
        y = sq:getY(),
        z = sq:getZ(),
    })
    playerObj:addLineChatElement("Shelf unmarked", 1, 1, 0.2)
end

local function onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if test then return end
    if not SZ_Utils.IsAdminPlayer() then return end

    local obj = findContainerObject(worldobjects)
    if not obj then return end

    local data = obj:getModData()
    if data and data.SZLibraryShelf then
        context:addOption("[SZ] Unmark Library Shelf", player, onUnmarkShelf, obj)
    else
        context:addOption("[SZ] Mark as Library Shelf", player, onMarkShelf, obj)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- ----- Transfer restriction ----------------------------------------------

local function isLibraryShelf(container)
    if not container then return false end
    local parent = container:getParent()
    if not parent then return false end
    if not parent.getModData then return false end
    local data = parent:getModData()
    return data and data.SZLibraryShelf == true
end

local function isPlayerMainInventory(container, character)
    return container == character:getInventory()
end

if ISInventoryTransferAction and ISInventoryTransferAction.isValid then
    local _origIsValid = ISInventoryTransferAction.isValid

    function ISInventoryTransferAction:isValid()
        if self.item and self.item.getModData then
            local md = self.item:getModData()
            if md and md.SZLibrary then
                local src = self.srcContainer
                local dst = self.destContainer
                -- Allow: shelf -> player inventory (borrow)
                -- Allow: player inventory -> library shelf (return)
                local srcIsShelf = isLibraryShelf(src)
                local dstIsShelf = isLibraryShelf(dst)
                local dstIsPlayer = isPlayerMainInventory(dst, self.character)
                local srcIsPlayer = isPlayerMainInventory(src, self.character)

                if (srcIsShelf and dstIsPlayer) or (srcIsPlayer and dstIsShelf) then
                    return _origIsValid(self)
                end

                -- Drop to floor — destroy the book, it will respawn on shelf
                if srcIsPlayer then
                    if not self._szLibraryDestroySent then
                        self._szLibraryDestroySent = true
                        sendClientCommand(self.character, "SafeZoneLibrary", "destroyBook", {
                            itemId = self.item:getID(),
                        })
                        self.character:addLineChatElement(
                            "The book returned to the library shelf.",
                            0.6, 0.8, 1
                        )
                    end
                    return false
                end

                -- Block everything else (bag, car, other container)
                self.character:addLineChatElement(
                    "This book belongs to the library.",
                    1, 0.3, 0.3
                )
                return false
            end
        end
        return _origIsValid(self)
    end
end
