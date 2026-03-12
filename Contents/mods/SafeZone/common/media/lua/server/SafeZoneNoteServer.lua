if not isServer() then return end

local function onClientCommand(module, command, player, args)
    if module ~= "SafeZoneNote" then return end

    if command == "giveNote" then
        local modData = player:getModData()
        if modData.SafeZone_NoteGivenServer then return end

        local inv = player:getInventory()
        local note = inv:AddItem("Base.SheetPaper2")
        if not note then return end

        note:setName(args.name or "Note")
        note:setCustomName(true)
        note:addPage(1, args.text or "")

        sendAddItemToContainer(inv, note)
        modData.SafeZone_NoteGivenServer = true
    end
end

Events.OnClientCommand.Add(onClientCommand)
