-- Tests for Core.lua
package.path = package.path .. ";tests/?.lua"
require("test_runner")
require("wow_api_mock")

local function loadAll()
    ResetMocks()
    LoadAddonFile("BetterFriends/Utils.lua")
    LoadAddonFile("BetterFriends/Data.lua")
    LoadAddonFile("BetterFriends/Core.lua")
    return BetterFriendsNS
end

describe("Core: Event System", function()
    it("should create an event frame", function()
        local ns = loadAll()
        expect(ns.eventFrame).toNotBeNil()
    end)

    it("should register events via ns:RegisterEvent", function()
        local ns = loadAll()
        local handlerCalled = false
        local testModule = {}
        function testModule:OnTestEvent()
            handlerCalled = true
        end

        ns:RegisterEvent("TEST_EVENT", testModule, testModule.OnTestEvent)
        expect(ns.eventFrame._registeredEvents["TEST_EVENT"]).toBeTruthy()
    end)

    it("should dispatch events to registered handlers", function()
        local ns = loadAll()
        local receivedArg = nil
        local testModule = {}
        function testModule:OnTestEvent(event, arg1)
            receivedArg = arg1
        end

        ns:RegisterEvent("TEST_EVENT", testModule, testModule.OnTestEvent)

        -- Simulate WoW firing the event
        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "TEST_EVENT", "hello")
        expect(receivedArg).toBe("hello")
    end)

    it("should support multiple handlers for the same event", function()
        local ns = loadAll()
        local count = 0
        local mod1 = {}
        function mod1:Handler() count = count + 1 end
        local mod2 = {}
        function mod2:Handler() count = count + 1 end

        ns:RegisterEvent("TEST_EVENT", mod1, mod1.Handler)
        ns:RegisterEvent("TEST_EVENT", mod2, mod2.Handler)

        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "TEST_EVENT")
        expect(count).toBe(2)
    end)

    it("should unregister events", function()
        local ns = loadAll()
        local called = false
        local testModule = {}
        function testModule:Handler() called = true end

        ns:RegisterEvent("TEST_EVENT", testModule, testModule.Handler)
        ns:UnregisterEvent("TEST_EVENT", testModule)

        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "TEST_EVENT")
        expect(called).toBeFalsy()
    end)
end)

describe("Core: ADDON_LOADED", function()
    it("should initialize Data on ADDON_LOADED for BetterFriends", function()
        local ns = loadAll()
        BetterFriendsDB = nil

        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "ADDON_LOADED", "BetterFriends")

        expect(BetterFriendsDB).toNotBeNil()
        expect(BetterFriendsDB.schemaVersion).toBe(1)
    end)

    it("should ignore ADDON_LOADED for other addons", function()
        local ns = loadAll()
        BetterFriendsDB = nil

        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "ADDON_LOADED", "SomeOtherAddon")

        expect(BetterFriendsDB).toBeNil()
    end)
end)

describe("Core: Slash Commands", function()
    it("should register /btf and /betterfriends slash commands", function()
        local ns = loadAll()
        -- Trigger ADDON_LOADED to set up slash commands
        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "ADDON_LOADED", "BetterFriends")

        expect(SlashCmdList["BETTERFRIENDS"]).toNotBeNil()
        expect(_G["SLASH_BETTERFRIENDS1"]).toBe("/btf")
        expect(_G["SLASH_BETTERFRIENDS2"]).toBe("/betterfriends")
    end)

    it("should print help text for /btf help", function()
        local ns = loadAll()
        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "ADDON_LOADED", "BetterFriends")

        _G._capturedPrints = {}
        SlashCmdList["BETTERFRIENDS"]("help")

        expect(#_G._capturedPrints > 0).toBeTruthy()
        -- Check that help output mentions key commands
        local allOutput = table.concat(_G._capturedPrints, " ")
        expect(allOutput).toContain("/btf")
    end)

    it("should print help for empty input", function()
        local ns = loadAll()
        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "ADDON_LOADED", "BetterFriends")

        _G._capturedPrints = {}
        SlashCmdList["BETTERFRIENDS"]("")

        expect(#_G._capturedPrints > 0).toBeTruthy()
    end)
end)

exitWithResults()
