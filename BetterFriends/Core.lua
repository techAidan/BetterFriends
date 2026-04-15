local addonName, ns = ...

-- Event dispatch system
ns.eventFrame = CreateFrame("Frame")
ns.callbacks = {}

function ns:RegisterEvent(event, module, handler)
    if not ns.callbacks[event] then
        ns.callbacks[event] = {}
        ns.eventFrame:RegisterEvent(event)
    end
    table.insert(ns.callbacks[event], { module = module, handler = handler })
end

function ns:UnregisterEvent(event, module)
    local cbs = ns.callbacks[event]
    if not cbs then return end

    for i = #cbs, 1, -1 do
        if cbs[i].module == module then
            table.remove(cbs, i)
        end
    end

    if #cbs == 0 then
        ns.callbacks[event] = nil
        ns.eventFrame:UnregisterEvent(event)
    end
end

ns.eventFrame:SetScript("OnEvent", function(self, event, ...)
    -- Handle ADDON_LOADED internally first
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            if ns.DebugLog then ns.DebugLog:Init() end
            ns.Data:Init()
            ns:SetupSlashCommands()
        end
    end

    -- Dispatch to registered handlers
    local cbs = ns.callbacks[event]
    if cbs then
        for _, cb in ipairs(cbs) do
            cb.handler(cb.module, event, ...)
        end
    end
end)

ns.eventFrame:RegisterEvent("ADDON_LOADED")

-- Slash commands
function ns:SetupSlashCommands()
    SLASH_BETTERFRIENDS1 = "/bf"
    SLASH_BETTERFRIENDS2 = "/betterfriends"

    SlashCmdList["BETTERFRIENDS"] = function(msg)
        local cmd = string.lower(string.trim and string.trim(msg) or msg:match("^%s*(.-)%s*$"))

        if cmd == "" or cmd == "help" then
            ns:PrintHelp()
        elseif cmd == "show" then
            if ns.FriendsViewer then
                ns.FriendsViewer:Toggle()
            else
                print("|cFF00CCFFBetterFriends:|r Friends viewer not yet loaded.")
            end
        elseif cmd == "minimap" then
            local settings = ns.Data:GetSettings()
            settings.minimapButtonShown = not settings.minimapButtonShown
            if ns.MinimapButton then
                ns.MinimapButton:UpdateVisibility()
            end
            print("|cFF00CCFFBetterFriends:|r Minimap button " ..
                (settings.minimapButtonShown and "shown" or "hidden") .. ".")
        elseif cmd:match("^log") then
            local countStr = cmd:match("^log%s+(%d+)")
            local count = countStr and tonumber(countStr) or 20
            ns.DebugLog:PrintRecent(count)
        elseif cmd == "clearlog" then
            ns.DebugLog:Clear()
            print("|cFF00CCFFBetterFriends:|r Debug log cleared.")
        else
            -- Check for subcommands handled by other modules
            if ns.SlashHandlers and ns.SlashHandlers[cmd] then
                ns.SlashHandlers[cmd](msg)
            else
                print("|cFF00CCFFBetterFriends:|r Unknown command '" .. cmd .. "'. Type /bf help for commands.")
            end
        end
    end
end

function ns:PrintHelp()
    print("|cFF00CCFFBetterFriends|r - Track friends made through M+ keys")
    print("  /bf show - Toggle the friends viewer")
    print("  /bf minimap - Toggle minimap button")
    print("  /bf test - Simulate an M+ completion (debug)")
    print("  /bf link <char> <btag> - Manually link a friend to a BattleTag")
    print("  /bf log [N] - Show last N debug log entries (default 20)")
    print("  /bf clearlog - Clear the debug log")
    print("  /bf help - Show this help message")
end

-- Allow other modules to register slash subcommands
ns.SlashHandlers = {}

-- string.trim polyfill for outside WoW
if not string.trim then
    string.trim = function(s)
        return s:match("^%s*(.-)%s*$")
    end
end
