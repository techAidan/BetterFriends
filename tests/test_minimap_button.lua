-- Tests for MinimapButton.lua
package.path = package.path .. ";tests/?.lua"
require("test_runner")
require("wow_api_mock")

-- Ensure Minimap global exists for MinimapButton
_G.Minimap = CreateFrame("Frame", "Minimap")

local function loadAll()
    ResetMocks()
    -- Recreate Minimap after ResetMocks clears globals
    _G.Minimap = CreateFrame("Frame", "Minimap")
    LoadAddonFile("BetterFriends/Utils.lua")
    LoadAddonFile("BetterFriends/DebugLog.lua")
    LoadAddonFile("BetterFriends/Data.lua")
    LoadAddonFile("BetterFriends/Core.lua")
    LoadAddonFile("BetterFriends/PartyScanner.lua")
    LoadAddonFile("BetterFriends/BNetLinker.lua")
    LoadAddonFile("BetterFriends/MythicPlusTracker.lua")
    LoadAddonFile("BetterFriends/FriendRequestPopup.lua")
    LoadAddonFile("BetterFriends/MinimapButton.lua")
    local ns = BetterFriendsNS
    local onEvent = ns.eventFrame:GetScript("OnEvent")
    onEvent(ns.eventFrame, "ADDON_LOADED", "BetterFriends")
    return ns
end

describe("MinimapButton: Create", function()
    it("should create a button frame", function()
        local ns = loadAll()

        ns.MinimapButton:Create()

        expect(ns.MinimapButton.button).toNotBeNil()
        expect(ns.MinimapButton.button._type).toBe("Button")
    end)

    it("should parent the button to Minimap", function()
        local ns = loadAll()

        ns.MinimapButton:Create()

        expect(ns.MinimapButton.button:GetParent()).toBe(_G.Minimap)
    end)
end)

describe("MinimapButton: UpdateVisibility", function()
    it("should show the button when setting is true", function()
        local ns = loadAll()
        ns.MinimapButton:Create()
        local settings = ns.Data:GetSettings()
        settings.minimapButtonShown = true

        ns.MinimapButton:UpdateVisibility()

        expect(ns.MinimapButton.button:IsShown()).toBe(true)
    end)

    it("should hide the button when setting is false", function()
        local ns = loadAll()
        ns.MinimapButton:Create()
        local settings = ns.Data:GetSettings()
        settings.minimapButtonShown = false

        ns.MinimapButton:UpdateVisibility()

        expect(ns.MinimapButton.button:IsShown()).toBe(false)
    end)
end)

describe("MinimapButton: SetAngle / GetAngle", function()
    it("should store angle in settings via SetAngle", function()
        local ns = loadAll()
        ns.MinimapButton:Create()

        ns.MinimapButton:SetAngle(135)

        local settings = ns.Data:GetSettings()
        expect(settings.minimapButtonPosition).toBe(135)
    end)

    it("should retrieve angle from settings via GetAngle", function()
        local ns = loadAll()
        ns.MinimapButton:Create()
        local settings = ns.Data:GetSettings()
        settings.minimapButtonPosition = 45

        local angle = ns.MinimapButton:GetAngle()

        expect(angle).toBe(45)
    end)
end)

describe("MinimapButton: UpdatePosition", function()
    it("should not error when called", function()
        local ns = loadAll()
        ns.MinimapButton:Create()

        -- Should complete without error
        ns.MinimapButton:UpdatePosition()

        expect(ns.MinimapButton.button).toNotBeNil()
    end)
end)

describe("MinimapButton: PLAYER_LOGIN", function()
    it("should trigger creation on PLAYER_LOGIN", function()
        local ns = loadAll()

        -- Fire PLAYER_LOGIN
        local onEvent = ns.eventFrame:GetScript("OnEvent")
        onEvent(ns.eventFrame, "PLAYER_LOGIN")

        expect(ns.MinimapButton.button).toNotBeNil()
        expect(ns.MinimapButton.button._type).toBe("Button")
    end)
end)

exitWithResults()
