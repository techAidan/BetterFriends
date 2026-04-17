local addonName, ns = ...

ns.DebugLog = {}

local MAX_LOG_ENTRIES = 500
local ENABLED = true

-- Initialize the log SavedVariable (called from Core.lua ADDON_LOADED)
function ns.DebugLog:Init()
    if not BetterFriendsDebugLog then
        BetterFriendsDebugLog = {}
    end

    -- Trim old entries if over cap
    while #BetterFriendsDebugLog > MAX_LOG_ENTRIES do
        table.remove(BetterFriendsDebugLog, 1)
    end
end

-- Log a message with timestamp
function ns.DebugLog:Log(category, ...)
    if not ENABLED then return end

    local parts = {}
    local args = {...}
    for i = 1, select("#", ...) do
        parts[i] = tostring(args[i])
    end
    local message = table.concat(parts, " ")

    local entry = {
        t = time(),
        cat = category or "General",
        msg = message,
    }

    -- Store in SavedVariable (persists on logout/reload)
    if BetterFriendsDebugLog then
        table.insert(BetterFriendsDebugLog, entry)

        -- Trim if over cap
        while #BetterFriendsDebugLog > MAX_LOG_ENTRIES do
            table.remove(BetterFriendsDebugLog, 1)
        end
    end

    -- Also print to chat for immediate visibility
    print("|cFF00CCFFBetterFriends [" .. entry.cat .. "]:|r " .. message)
end

-- Get all log entries
function ns.DebugLog:GetEntries()
    return BetterFriendsDebugLog or {}
end

-- Get entry count
function ns.DebugLog:GetCount()
    if BetterFriendsDebugLog then
        return #BetterFriendsDebugLog
    end
    return 0
end

-- Clear the log
function ns.DebugLog:Clear()
    BetterFriendsDebugLog = {}
end

-- Print last N entries to chat
function ns.DebugLog:PrintRecent(count)
    local entries = self:GetEntries()
    local total = #entries
    count = count or 20

    if total == 0 then
        print("|cFF00CCFFBetterFriends:|r Debug log is empty.")
        return
    end

    local startIdx = math.max(1, total - count + 1)
    print("|cFF00CCFFBetterFriends:|r Showing last " .. (total - startIdx + 1) .. " of " .. total .. " log entries:")
    print("----")
    for i = startIdx, total do
        local entry = entries[i]
        local timeStr = date("%Y-%m-%d %H:%M:%S", entry.t)
        print("|cFF888888" .. timeStr .. "|r [" .. entry.cat .. "] " .. entry.msg)
    end
    print("----")
    print("|cFF00CCFFBetterFriends:|r Log file location after /reload or logout:")
    print("  WTF\\Account\\<name>\\SavedVariables\\BetterFriends.lua")
end
