require "SafeZoneConfig"

SafeZoneNote = {}

SafeZoneNote.onCreatePlayer = function(playerIndex, playerObj)
    local modData = playerObj:getModData()
    if modData.SafeZone_NoteGiven then return end
    modData.SafeZone_NoteGiven = true

    local noteName = getText("IGUI_SafeZone_NoteName")
    local noteText = getText("IGUI_SafeZone_NoteText", tostring(SafeZoneConfig.BASE_X), tostring(SafeZoneConfig.BASE_Y))

    -- Ждём несколько тиков — при первом подключении сеть может быть не готова
    local ticksLeft = 10
    local function waitAndSend()
        ticksLeft = ticksLeft - 1
        if ticksLeft > 0 then return end
        Events.OnTick.Remove(waitAndSend)
        sendClientCommand(playerObj, "SafeZoneNote", "giveNote", {
            name = noteName,
            text = noteText,
        })
    end
    Events.OnTick.Add(waitAndSend)
end

Events.OnCreatePlayer.Add(SafeZoneNote.onCreatePlayer)
