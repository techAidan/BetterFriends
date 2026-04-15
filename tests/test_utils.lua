-- Tests for Utils.lua
package.path = package.path .. ";tests/?.lua"
require("test_runner")
require("wow_api_mock")

-- Load the addon file
ResetMocks()
LoadAddonFile("BetterFriends/Utils.lua")
local ns = BetterFriendsNS

describe("Utils.GetClassColor", function()
    it("should return RGB values for a valid class", function()
        local r, g, b = ns.Utils.GetClassColor("WARRIOR")
        expect(r).toBe(0.78)
        expect(g).toBe(0.61)
        expect(b).toBe(0.43)
    end)

    it("should return white for an unknown class", function()
        local r, g, b = ns.Utils.GetClassColor("INVALIDCLASS")
        expect(r).toBe(1)
        expect(g).toBe(1)
        expect(b).toBe(1)
    end)
end)

describe("Utils.GetClassColoredName", function()
    it("should wrap name in class color codes", function()
        local result = ns.Utils.GetClassColoredName("Blob", "PALADIN")
        expect(result).toContain("Blob")
        expect(result).toContain("|c")
        expect(result).toContain("|r")
    end)

    it("should handle unknown class gracefully", function()
        local result = ns.Utils.GetClassColoredName("Test", "INVALIDCLASS")
        expect(result).toContain("Test")
    end)
end)

describe("Utils.GetRoleIcon", function()
    -- Role icons use |T..|t markup against the classic LFG role
    -- texture sheet, which ships with every WoW build. The texture
    -- path is the stable identifier we assert against.
    it("should return texture markup for tank", function()
        local result = ns.Utils.GetRoleIcon("TANK")
        expect(result).toContain("UI-LFG-ICON-ROLES")
    end)

    it("should return texture markup for healer", function()
        local result = ns.Utils.GetRoleIcon("HEALER")
        expect(result).toContain("UI-LFG-ICON-ROLES")
    end)

    it("should return texture markup for dps", function()
        local result = ns.Utils.GetRoleIcon("DAMAGER")
        expect(result).toContain("UI-LFG-ICON-ROLES")
    end)

    it("should return empty string for unknown role", function()
        local result = ns.Utils.GetRoleIcon("NONE")
        expect(result).toBe("")
    end)
end)

describe("Utils.GetRoleDisplayName", function()
    it("should return Tank for TANK", function()
        expect(ns.Utils.GetRoleDisplayName("TANK")).toBe("Tank")
    end)

    it("should return Healer for HEALER", function()
        expect(ns.Utils.GetRoleDisplayName("HEALER")).toBe("Healer")
    end)

    it("should return DPS for DAMAGER", function()
        expect(ns.Utils.GetRoleDisplayName("DAMAGER")).toBe("DPS")
    end)

    it("should return Unknown for NONE", function()
        expect(ns.Utils.GetRoleDisplayName("NONE")).toBe("Unknown")
    end)
end)

describe("Utils.FormatKeyLevel", function()
    it("should format key level with dungeon name", function()
        expect(ns.Utils.FormatKeyLevel(15, "Stonevault")).toBe("+15 Stonevault")
    end)

    it("should handle single digit key levels", function()
        expect(ns.Utils.FormatKeyLevel(2, "Ara-Kara")).toBe("+2 Ara-Kara")
    end)
end)

describe("Utils.FormatTimestamp", function()
    it("should format a timestamp as date string", function()
        -- Use a known timestamp: 2025-03-15 (approximately)
        local result = ns.Utils.FormatTimestamp(1710460800)
        expect(result).toNotBeNil()
        expect(type(result)).toBe("string")
    end)
end)

describe("Utils.FormatRelativeTime", function()
    it("should show seconds for very recent times", function()
        local now = os.time()
        local result = ns.Utils.FormatRelativeTime(now - 30)
        expect(result).toContain("s ago")
    end)

    it("should show minutes for recent times", function()
        local now = os.time()
        local result = ns.Utils.FormatRelativeTime(now - 300)
        expect(result).toBe("5m ago")
    end)

    it("should show hours", function()
        local now = os.time()
        local result = ns.Utils.FormatRelativeTime(now - 7200)
        expect(result).toBe("2h ago")
    end)

    it("should show days", function()
        local now = os.time()
        local result = ns.Utils.FormatRelativeTime(now - 172800)
        expect(result).toBe("2d ago")
    end)
end)

describe("Utils.NormalizeNameRealm", function()
    it("should lowercase and combine name-realm", function()
        expect(ns.Utils.NormalizeNameRealm("Blob", "Thrall")).toBe("blob-thrall")
    end)

    it("should use player realm when realm is nil", function()
        _G._mockPlayerRealm = "Stormrage"
        expect(ns.Utils.NormalizeNameRealm("Blob", nil)).toBe("blob-stormrage")
    end)

    it("should handle empty string realm", function()
        _G._mockPlayerRealm = "Stormrage"
        expect(ns.Utils.NormalizeNameRealm("Blob", "")).toBe("blob-stormrage")
    end)
end)

exitWithResults()
