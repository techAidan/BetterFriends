-- Infrastructure smoke test: verifies test runner and WoW API mocks work
package.path = package.path .. ";tests/?.lua"
require("test_runner")
require("wow_api_mock")

describe("Test Runner", function()
    it("should pass basic assertions", function()
        expect(1 + 1).toBe(2)
        expect("hello").toBe("hello")
        expect(true).toBeTruthy()
        expect(false).toBeFalsy()
        expect(nil).toBeNil()
        expect(42).toNotBeNil()
    end)

    it("should support table equality", function()
        expect({1, 2, 3}).toEqual({1, 2, 3})
        expect({a = 1, b = 2}).toEqual({a = 1, b = 2})
    end)

    it("should support string contains", function()
        expect("hello world").toContain("world")
    end)

    it("should support type checking", function()
        expect("hello").toBeType("string")
        expect(42).toBeType("number")
        expect({}).toBeType("table")
    end)
end)

describe("WoW API Mock: Frames", function()
    it("should create frames", function()
        ResetMocks()
        local frame = CreateFrame("Frame", "TestFrame", nil, nil)
        expect(frame).toNotBeNil()
        expect(frame:GetName()).toBe("TestFrame")
    end)

    it("should register and track events", function()
        ResetMocks()
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ADDON_LOADED")
        expect(frame._registeredEvents["ADDON_LOADED"]).toBeTruthy()
        frame:UnregisterEvent("ADDON_LOADED")
        expect(frame._registeredEvents["ADDON_LOADED"]).toBeNil()
    end)

    it("should handle scripts", function()
        ResetMocks()
        local frame = CreateFrame("Frame")
        local called = false
        frame:SetScript("OnEvent", function() called = true end)
        frame:GetScript("OnEvent")()
        expect(called).toBeTruthy()
    end)
end)

describe("WoW API Mock: Class Colors", function()
    it("should have all classes defined", function()
        expect(RAID_CLASS_COLORS["WARRIOR"]).toNotBeNil()
        expect(RAID_CLASS_COLORS["PALADIN"]).toNotBeNil()
        expect(RAID_CLASS_COLORS["EVOKER"]).toNotBeNil()
    end)

    it("should wrap text in color codes", function()
        local colored = RAID_CLASS_COLORS["WARRIOR"]:WrapTextInColorCode("TestName")
        expect(colored).toContain("TestName")
        expect(colored).toContain("|c")
        expect(colored).toContain("|r")
    end)
end)

describe("WoW API Mock: Unit Functions", function()
    it("should return mock unit data", function()
        ResetMocks()
        _G._mockUnits["party1"] = {
            name = "Blob",
            realm = "Thrall",
            className = "PALADIN",
            classDisplayName = "Paladin",
            role = "HEALER",
        }
        local name, realm = UnitName("party1")
        expect(name).toBe("Blob")
        expect(realm).toBe("Thrall")

        local displayName, token = UnitClass("party1")
        expect(displayName).toBe("Paladin")
        expect(token).toBe("PALADIN")

        expect(UnitGroupRolesAssigned("party1")).toBe("HEALER")
    end)

    it("should return nil for unknown units", function()
        ResetMocks()
        local name, realm = UnitName("party3")
        expect(name).toBeNil()
    end)
end)

describe("WoW API Mock: Challenge Mode", function()
    it("should report active state", function()
        ResetMocks()
        expect(C_ChallengeMode.IsChallengeModeActive()).toBeFalsy()
        _G._mockChallengeMode.active = true
        expect(C_ChallengeMode.IsChallengeModeActive()).toBeTruthy()
    end)
end)

describe("WoW API Mock: BNet", function()
    it("should track sent friend invites", function()
        ResetMocks()
        BNSendFriendInvite("Blob-Thrall")
        expect(#_G._mockBNetInvitesSent).toBe(1)
        expect(_G._mockBNetInvitesSent[1].text).toBe("Blob-Thrall")
    end)
end)

describe("WoW API Mock: LoadAddonFile", function()
    it("should be callable", function()
        expect(LoadAddonFile).toNotBeNil()
        expect(type(LoadAddonFile)).toBe("function")
    end)
end)

exitWithResults()
