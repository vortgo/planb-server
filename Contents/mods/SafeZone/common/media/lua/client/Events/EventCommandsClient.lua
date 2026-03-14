local function log(msg)
    print("[EventCmdClient] " .. tostring(msg))
end

local function isAdmin(playerObj)
    local level = playerObj:getAccessLevel()
    return level == "Admin" or level == "admin"
end

-- ---------------------------------------------------------------------------
-- Обработка ответов от сервера
-- ---------------------------------------------------------------------------

local function onServerCommand(module, command, args)
    if module ~= "SafeZoneEvents" then return end

    if command == "result" then
        log(tostring(args.text))
    end
end

Events.OnServerCommand.Add(onServerCommand)

-- ---------------------------------------------------------------------------
-- Парсинг команды /event
-- ---------------------------------------------------------------------------

local function parseEventCommand(text)
    -- /event spawn <type> [x y]
    -- /event list
    -- /event remove <id>
    -- /event removeall
    -- /event types

    local parts = {}
    for token in text:gmatch("%S+") do
        table.insert(parts, token)
    end

    -- parts[1] = "/event"
    if #parts < 2 then return nil end

    local sub = parts[2]:lower()

    if sub == "spawn" then
        if #parts < 3 then
            return nil, "Usage: /event spawn <type> [x y]"
        end
        local cmd = { command = "spawn", type = parts[3] }
        if parts[4] and parts[5] then
            cmd.x = parts[4]
            cmd.y = parts[5]
        end
        return cmd

    elseif sub == "list" then
        return { command = "list" }

    elseif sub == "remove" then
        if #parts < 3 then
            return nil, "Usage: /event remove <id>"
        end
        return { command = "remove", id = parts[3] }

    elseif sub == "removeall" then
        return { command = "removeall" }

    elseif sub == "types" then
        return { command = "types" }
    end

    return nil, "Unknown subcommand: " .. sub
        .. ". Available: spawn, list, remove, removeall, types"
end

-- ---------------------------------------------------------------------------
-- Хук чата: цепочка с существующим хуком
-- ---------------------------------------------------------------------------

local function hookChat()
    local chat = ISChat.instance
    if not chat or not chat.textEntry then return end

    -- Сохраняем предыдущий хук (может быть от StarterKitClient)
    local previousFn = chat.textEntry.onCommandEntered

    local function hookedOnCommandEntered(self)
        local text = chat.textEntry:getText()
        if not text then return previousFn(self) end

        -- Проверяем /event
        if text:match("^/event%s") or text == "/event" then
            local playerObj = getSpecificPlayer(0)

            if not playerObj or not isAdmin(playerObj) then
                log("Admin access required")
                chat.textEntry:setText("")
                chat:unfocus()
                return
            end

            local cmd, err = parseEventCommand(text)
            if cmd then
                sendClientCommand(playerObj, "SafeZoneEvents", cmd.command, cmd)
            else
                log(err or "Usage: /event <spawn|list|remove|removeall|types>")
            end

            chat.textEntry:setText("")
            chat:unfocus()
            return
        end

        -- Передаём в предыдущий хук
        return previousFn(self)
    end

    chat.textEntry.onCommandEntered = hookedOnCommandEntered
    log("Chat hook installed")
end

Events.OnGameStart.Add(hookChat)
log("EventCommandsClient loaded")
