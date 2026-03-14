local function log(msg)
    print("[EventCmdServer] " .. tostring(msg))
end

-- ---------------------------------------------------------------------------
-- Обработка OnClientCommand (module="SafeZoneEvents")
-- ---------------------------------------------------------------------------

local function onClientCommand(module, command, player, args)
    if module ~= "SafeZoneEvents" then return end

    local level = player:getAccessLevel()
    if level ~= "Admin" and level ~= "admin" then
        log("WARN: non-admin " .. player:getUsername() .. " attempted event command: " .. command)
        return
    end

    local username = player:getUsername()

    if command == "spawn" then
        local typeName = args.type
        if not typeName then
            sendServerCommand(player, "SafeZoneEvents", "result", {
                text = "Usage: /event spawn <type> [x y]"
            })
            return
        end

        local x = tonumber(args.x) or math.floor(player:getX())
        local y = tonumber(args.y) or math.floor(player:getY())
        local z = tonumber(args.z) or 0

        log(username .. " spawning event '" .. typeName .. "' at " .. x .. "," .. y .. "," .. z)
        local event, err = EventManager.spawn(typeName, x, y, z, "manual")

        if event then
            local msg = "Event #" .. event.id .. " (" .. event.type .. ") spawned at "
                .. event.x .. ", " .. event.y .. ", " .. event.z
            sendServerCommand(player, "SafeZoneEvents", "result", { text = msg })
        else
            sendServerCommand(player, "SafeZoneEvents", "result", {
                text = "Spawn failed: " .. tostring(err)
            })
        end

    elseif command == "list" then
        local events = EventManager.list()
        if #events == 0 then
            sendServerCommand(player, "SafeZoneEvents", "result", {
                text = "No active events"
            })
            return
        end

        local lines = { "Active events (" .. #events .. "):" }
        for _, ev in ipairs(events) do
            local status = ev.state or "unknown"
            local age = math.floor((os.time() - ev.spawnTime) / 60)
            table.insert(lines,
                "  #" .. ev.id .. " " .. ev.type
                .. " at " .. ev.x .. "," .. ev.y .. "," .. ev.z
                .. " [" .. status .. ", " .. age .. "m, " .. ev.source .. "]"
            )
        end

        sendServerCommand(player, "SafeZoneEvents", "result", {
            text = table.concat(lines, " | ")
        })

    elseif command == "remove" then
        local id = tonumber(args.id)
        if not id then
            sendServerCommand(player, "SafeZoneEvents", "result", {
                text = "Usage: /event remove <id>"
            })
            return
        end

        local ok, err = EventManager.remove(id, true)
        local msg
        if ok then
            msg = "Event #" .. id .. " removed"
        elseif err then
            msg = "Event #" .. id .. ": " .. err
        else
            msg = "Event #" .. id .. " not found"
        end
        sendServerCommand(player, "SafeZoneEvents", "result", { text = msg })

    elseif command == "removeall" then
        local removed, deferred = EventManager.removeAll(true)
        local msg = "Removed " .. removed .. " events"
        if deferred > 0 then
            msg = msg .. ", " .. deferred .. " deferred (chunks not loaded)"
        end
        sendServerCommand(player, "SafeZoneEvents", "result", { text = msg })

    elseif command == "types" then
        local types = EventRegistry.list()
        sendServerCommand(player, "SafeZoneEvents", "result", {
            text = "Available types: " .. table.concat(types, ", ")
        })

    else
        sendServerCommand(player, "SafeZoneEvents", "result", {
            text = "Unknown command: " .. command
        })
    end
end

Events.OnClientCommand.Add(onClientCommand)

-- ---------------------------------------------------------------------------
-- Файловые команды через SafeZoneCommands
-- ---------------------------------------------------------------------------

local function registerFileCommands()
    if not SafeZoneCommands or not SafeZoneCommands.register then
        log("SafeZoneCommands not available, skipping file command registration")
        return
    end

    -- event spawn <type> [x y [z]]
    SafeZoneCommands.register("event", function(args)
        if #args < 1 then
            log("Usage: event <spawn|list|remove|removeall> [args...]")
            return
        end

        local sub = args[1]:lower()

        if sub == "spawn" then
            if #args < 2 then
                log("Usage: event spawn <type> [x y [z]]")
                return
            end
            local typeName = args[2]
            local x = tonumber(args[3])
            local y = tonumber(args[4])
            local z = tonumber(args[5]) or 0

            if not x or not y then
                log("event spawn: coordinates required in file mode")
                return
            end

            local event, err = EventManager.spawn(typeName, x, y, z, "file")
            if event then
                log("Spawned event #" .. event.id .. " (" .. event.type .. ") at "
                    .. event.x .. "," .. event.y .. "," .. event.z)
            else
                log("Spawn failed: " .. tostring(err))
            end

        elseif sub == "list" then
            local events = EventManager.list()
            log("Active events: " .. #events)
            for _, ev in ipairs(events) do
                log("  #" .. ev.id .. " " .. ev.type .. " at " .. ev.x .. "," .. ev.y)
            end

        elseif sub == "remove" then
            local id = tonumber(args[2])
            if not id then
                log("Usage: event remove <id>")
                return
            end
            EventManager.remove(id)

        elseif sub == "removeall" then
            EventManager.removeAll()

        else
            log("Unknown subcommand: " .. sub)
        end
    end)

    log("File commands registered")
end

-- Откладываем регистрацию файловых команд до полной загрузки всех скриптов
Events.OnServerStarted.Add(registerFileCommands)
log("EventCommandsServer loaded")
