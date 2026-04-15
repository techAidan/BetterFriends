-- Tests for /btf test debug command
package.path = package.path .. ";tests/?.lua"
require("test_runner")
require("wow_api_mock")

local function loadAll()
    ResetMocks()
    LoadAddonFile("BetterFriends/Utils.lua")
    LoadAddonFile("BetterFriends/DebugLog.lua")
    LoadAddonFile("BetterFriends/Data.lua")
    LoadAddonFile("BetterFriends/Core.lua")
    LoadAddonFile("BetterFriends/PartyScanner.lua")
    LoadAddonFile("BetterFriends/BNetLinker.lua")
    LoadAddonFile("BetterFriends/MythicPlusTracker.lua")
    LoadAddonFile("BetterFriends/FriendRequestPopup.lua")
    LoadAddonFile("BetterFriends/FriendsViewer.lua")
    LoadAddonFile("BetterFriends/MinimapButton.lua")
    LoadAddonFile("BetterFriends/DebugCommands.lua")
    local ns = BetterFriendsNS
    -- Fire ADDON_LOADED to init
    ns.eventFrame:GetScript("OnEvent")(ns.eventFrame, "ADDON_LOADED", "BetterFriends")
    return ns
end

describe("/btf test command", function()
    it("should register the test slash handler", function()
        local ns = loadAll()
        expect(ns.SlashHandlers["test"]).toNotBeNil()
    end)

    it("should create fake completion data with 4 party members", function()
        local ns = loadAll()
        ns.SlashHandlers["test"]("test")

        expect(ns.lastCompletion).toNotBeNil()
        expect(ns.lastCompletion.dungeonName).toNotBeNil()
        expect(ns.lastCompletion.keyLevel).toNotBeNil()
        expect(ns.lastCompletion.onTime).toNotBeNil()
        expect(#ns.lastCompletion.members).toBe(4)
    end)

    it("should create members with valid class tokens", function()
        local ns = loadAll()
        ns.SlashHandlers["test"]("test")

        for _, member in ipairs(ns.lastCompletion.members) do
            expect(member.name).toNotBeNil()
            expect(member.realm).toNotBeNil()
            expect(member.nameRealm).toNotBeNil()
            expect(member.classToken).toNotBeNil()
            expect(RAID_CLASS_COLORS[member.classToken]).toNotBeNil()
            expect(member.role).toNotBeNil()
        end
    end)

    it("should trigger the popup", function()
        local ns = loadAll()
        ns.SlashHandlers["test"]("test")

        expect(ns.FriendRequestPopup.frame).toNotBeNil()
        expect(ns.FriendRequestPopup.frame:IsShown()).toBeTruthy()
    end)

    it("should print a message confirming simulation", function()
        local ns = loadAll()
        _G._capturedPrints = {}
        ns.SlashHandlers["test"]("test")

        local allOutput = table.concat(_G._capturedPrints, " ")
        expect(allOutput).toContain("Simulating")
    end)
end)

exitWithResults()
