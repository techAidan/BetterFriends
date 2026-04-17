-- Tests for DebugLog module
package.path = package.path .. ";tests/?.lua;BetterFriends/?.lua"
require("test_runner")
require("wow_api_mock")

-- Helper to load addon files fresh
local function loadAddon()
    ResetMocks()
    BetterFriendsDebugLog = nil
    LoadAddonFile("BetterFriends/Utils.lua")
    LoadAddonFile("BetterFriends/DebugLog.lua")
    LoadAddonFile("BetterFriends/Data.lua")
    LoadAddonFile("BetterFriends/Core.lua")
    return BetterFriendsNS
end

describe("DebugLog: Init", function()
    it("should create empty log table when none exists", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = nil
        ns.DebugLog:Init()
        expect(BetterFriendsDebugLog).toNotBeNil()
        expect(#BetterFriendsDebugLog).toBe(0)
    end)

    it("should preserve existing log entries on re-init", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {
            { t = 1000, cat = "Test", msg = "existing entry" },
        }
        ns.DebugLog:Init()
        expect(#BetterFriendsDebugLog).toBe(1)
        expect(BetterFriendsDebugLog[1].msg).toBe("existing entry")
    end)

    it("should trim entries over the cap on init", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {}
        for i = 1, 550 do
            table.insert(BetterFriendsDebugLog, { t = i, cat = "Test", msg = "entry " .. i })
        end
        ns.DebugLog:Init()
        expect(#BetterFriendsDebugLog).toBe(500)
        -- Should keep the newest entries (51-550)
        expect(BetterFriendsDebugLog[1].msg).toBe("entry 51")
        expect(BetterFriendsDebugLog[500].msg).toBe("entry 550")
    end)
end)

describe("DebugLog: Log", function()
    it("should add an entry with timestamp, category, and message", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {}
        ns.DebugLog:Log("M+", "CHALLENGE_MODE_COMPLETED fired!")
        expect(#BetterFriendsDebugLog).toBe(1)
        expect(BetterFriendsDebugLog[1].cat).toBe("M+")
        expect(BetterFriendsDebugLog[1].msg).toBe("CHALLENGE_MODE_COMPLETED fired!")
        expect(BetterFriendsDebugLog[1].t).toNotBeNil()
    end)

    it("should concatenate multiple arguments into one message", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {}
        ns.DebugLog:Log("M+", "level:", 15, "onTime:", true)
        expect(BetterFriendsDebugLog[1].msg).toBe("level: 15 onTime: true")
    end)

    it("should also print to chat", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {}
        _G._capturedPrints = {}
        ns.DebugLog:Log("M+", "test message")
        expect(#_G._capturedPrints).toBeGreaterThan(0)
        expect(_G._capturedPrints[1]).toContain("test message")
    end)

    it("should enforce max entries cap", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {}
        for i = 1, 505 do
            ns.DebugLog:Log("Test", "entry " .. i)
        end
        expect(#BetterFriendsDebugLog).toBe(500)
    end)

    it("should default category to General when nil", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {}
        ns.DebugLog:Log(nil, "no category")
        expect(BetterFriendsDebugLog[1].cat).toBe("General")
    end)
end)

describe("DebugLog: GetEntries", function()
    it("should return the log entries", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {
            { t = 1000, cat = "A", msg = "first" },
            { t = 2000, cat = "B", msg = "second" },
        }
        local entries = ns.DebugLog:GetEntries()
        expect(#entries).toBe(2)
        expect(entries[1].msg).toBe("first")
    end)

    it("should return empty table when log is nil", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = nil
        local entries = ns.DebugLog:GetEntries()
        expect(#entries).toBe(0)
    end)
end)

describe("DebugLog: GetCount", function()
    it("should return the number of entries", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {
            { t = 1, cat = "A", msg = "a" },
            { t = 2, cat = "B", msg = "b" },
            { t = 3, cat = "C", msg = "c" },
        }
        expect(ns.DebugLog:GetCount()).toBe(3)
    end)

    it("should return 0 when log is nil", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = nil
        expect(ns.DebugLog:GetCount()).toBe(0)
    end)
end)

describe("DebugLog: Clear", function()
    it("should empty the log", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {
            { t = 1, cat = "A", msg = "a" },
            { t = 2, cat = "B", msg = "b" },
        }
        ns.DebugLog:Clear()
        expect(#BetterFriendsDebugLog).toBe(0)
    end)
end)

describe("DebugLog: PrintRecent", function()
    it("should print last N entries to chat", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {}
        for i = 1, 30 do
            table.insert(BetterFriendsDebugLog, { t = 1000 + i, cat = "Test", msg = "entry " .. i })
        end
        _G._capturedPrints = {}
        ns.DebugLog:PrintRecent(5)
        -- Should contain the header, 5 entries, footer, and file path
        local found = 0
        for _, p in ipairs(_G._capturedPrints) do
            if p:match("entry %d+") then
                found = found + 1
            end
        end
        expect(found).toBe(5)
    end)

    it("should show empty message when log is empty", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {}
        _G._capturedPrints = {}
        ns.DebugLog:PrintRecent()
        expect(#_G._capturedPrints).toBeGreaterThan(0)
        expect(_G._capturedPrints[1]).toContain("empty")
    end)

    it("should default to 20 entries", function()
        local ns = loadAddon()
        BetterFriendsDebugLog = {}
        for i = 1, 50 do
            table.insert(BetterFriendsDebugLog, { t = 1000 + i, cat = "Test", msg = "entry " .. i })
        end
        _G._capturedPrints = {}
        ns.DebugLog:PrintRecent()
        local found = 0
        for _, p in ipairs(_G._capturedPrints) do
            if p:match("entry %d+") then
                found = found + 1
            end
        end
        expect(found).toBe(20)
    end)
end)

describe("DebugLog: Slash commands", function()
    it("should handle /btf log command", function()
        local ns = loadAddon()
        -- Trigger ADDON_LOADED to set up slash commands
        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "ADDON_LOADED", "BetterFriends")

        BetterFriendsDebugLog = {
            { t = 1000, cat = "M+", msg = "test log entry" },
        }
        _G._capturedPrints = {}
        SlashCmdList["BETTERFRIENDS"]("log")
        local foundEntry = false
        for _, p in ipairs(_G._capturedPrints) do
            if p:match("test log entry") then foundEntry = true end
        end
        expect(foundEntry).toBeTruthy()
    end)

    it("should handle /btf clearlog command", function()
        local ns = loadAddon()
        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "ADDON_LOADED", "BetterFriends")

        BetterFriendsDebugLog = {
            { t = 1000, cat = "M+", msg = "will be cleared" },
        }
        _G._capturedPrints = {}
        SlashCmdList["BETTERFRIENDS"]("clearlog")
        expect(#BetterFriendsDebugLog).toBe(0)
    end)
end)

printResults()
exitWithResults()
