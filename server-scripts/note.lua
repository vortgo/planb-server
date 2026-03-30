if not isServer() then return end


local function onClientCommand(module, command, player, args)
    if module ~= "SafeZoneNote" then return end

    if command == "giveNote" then
        local modData = player:getModData()
        if modData.SafeZone_NoteGivenServer then return end

        local inv = player:getInventory()

        -- Записка
        local note = inv:AddItem("Base.SheetPaper2")
        if note then
            note:setName(args.name or "Note")
            note:setCustomName(true)
            note:addPage(1, args.text or "")
            sendAddItemToContainer(inv, note)
        end

        -- Рация, настроенная на канал SafeZone
        local radio = inv:AddItem("Base.WalkieTalkie5")
        if radio then
            local deviceData = radio:getDeviceData()
            if deviceData then
                deviceData:setChannel(SafeZoneConfig.RADIO_FREQUENCY)
                deviceData:setIsTurnedOn(true)
            end
            sendAddItemToContainer(inv, radio)
        end

        modData.SafeZone_NoteGivenServer = true
    end
end

Events.OnClientCommand.Add(onClientCommand)
