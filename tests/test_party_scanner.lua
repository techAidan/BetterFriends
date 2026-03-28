-- Tests for PartyScanner.lua
package.path = package.path .. ";tests/?.lua"
require("test_runner")
require("wow_api_mock")

local function loadAll()
    ResetMocks()
    LoadAddonFile("BetterFriends/Utils.lua")
    LoadAddonFile("BetterFriends/Data.lua")
    LoadAddonFile("BetterFriends/Core.lua")
    LoadAddonFile("BetterFriends/PartyScanner.lua")
    return BetterFriendsNS
end

describe("PartyScanner: CaptureCurrentParty", function()
    it("should capture a full 4-member party", function()
        local ns = loadAll()

        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        _G._mockUnits["party2"] = { name = "Bob", realm = "Thrall", classDisplayName = "Priest", className = "PRIEST", role = "HEALER" }
        _G._mockUnits["party3"] = { name = "Carol", realm = "Thrall", classDisplayName = "Mage", className = "MAGE", role = "DAMAGER" }
        _G._mockUnits["party4"] = { name = "Dave", realm = "Thrall", classDisplayName = "Rogue", className = "ROGUE", role = "DAMAGER" }

        local party = ns.PartyScanner:CaptureCurrentParty()
        expect(#party).toBe(4)

        expect(party[1].name).toBe("Alice")
        expect(party[1].realm).toBe("Thrall")
        expect(party[1].nameRealm).toBe("alice-thrall")
        expect(party[1].classToken).toBe("WARRIOR")
        expect(party[1].classDisplayName).toBe("Warrior")
        expect(party[1].role).toBe("TANK")

        expect(party[2].name).toBe("Bob")
        expect(party[2].classToken).toBe("PRIEST")
        expect(party[2].role).toBe("HEALER")

        expect(party[3].name).toBe("Carol")
        expect(party[4].name).toBe("Dave")
    end)

    it("should handle nil realm (same-server) using GetNormalizedRealmName fallback", function()
        local ns = loadAll()
        _G._mockPlayerRealm = "Sargeras"

        _G._mockUnits["party1"] = { name = "SameServer", realm = nil, classDisplayName = "Druid", className = "DRUID", role = "HEALER" }

        local party = ns.PartyScanner:CaptureCurrentParty()
        expect(#party).toBe(1)
        expect(party[1].realm).toBe("Sargeras")
        expect(party[1].nameRealm).toBe("sameserver-sargeras")
    end)

    it("should handle empty realm string using GetNormalizedRealmName fallback", function()
        local ns = loadAll()
        _G._mockPlayerRealm = "Sargeras"

        _G._mockUnits["party1"] = { name = "EmptyRealm", realm = "", classDisplayName = "Paladin", className = "PALADIN", role = "TANK" }

        local party = ns.PartyScanner:CaptureCurrentParty()
        expect(#party).toBe(1)
        expect(party[1].realm).toBe("Sargeras")
        expect(party[1].nameRealm).toBe("emptyrealm-sargeras")
    end)

    it("should return empty table when not in a group", function()
        local ns = loadAll()
        -- No mock units set up
        local party = ns.PartyScanner:CaptureCurrentParty()
        expect(#party).toBe(0)
    end)

    it("should skip units where UnitName returns nil", function()
        local ns = loadAll()
        -- Only party1 and party3 have data, party2 and party4 are empty
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        _G._mockUnits["party3"] = { name = "Carol", realm = "Thrall", classDisplayName = "Mage", className = "MAGE", role = "DAMAGER" }

        local party = ns.PartyScanner:CaptureCurrentParty()
        expect(#party).toBe(2)
        expect(party[1].name).toBe("Alice")
        expect(party[2].name).toBe("Carol")
    end)
end)

describe("PartyScanner: CachePartySnapshot", function()
    it("should cache the current party snapshot", function()
        local ns = loadAll()
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }

        ns.PartyScanner:CachePartySnapshot()

        local cached = ns.PartyScanner:GetCachedSnapshot()
        expect(cached).toNotBeNil()
        expect(#cached).toBe(1)
        expect(cached[1].name).toBe("Alice")
    end)

    it("should return nil when no snapshot has been cached", function()
        local ns = loadAll()
        local cached = ns.PartyScanner:GetCachedSnapshot()
        expect(cached).toBeNil()
    end)
end)

describe("PartyScanner: GetMergedParty", function()
    it("should return live data when available and no cache", function()
        local ns = loadAll()
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        _G._mockUnits["party2"] = { name = "Bob", realm = "Thrall", classDisplayName = "Priest", className = "PRIEST", role = "HEALER" }

        local merged = ns.PartyScanner:GetMergedParty()
        expect(#merged).toBe(2)
    end)

    it("should merge cached members into live data when live has gaps", function()
        local ns = loadAll()

        -- Cache a full party
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        _G._mockUnits["party2"] = { name = "Bob", realm = "Thrall", classDisplayName = "Priest", className = "PRIEST", role = "HEALER" }
        _G._mockUnits["party3"] = { name = "Carol", realm = "Thrall", classDisplayName = "Mage", className = "MAGE", role = "DAMAGER" }
        ns.PartyScanner:CachePartySnapshot()

        -- Now only Alice is in live data (Bob and Carol left)
        _G._mockUnits = {}
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }

        local merged = ns.PartyScanner:GetMergedParty()
        expect(#merged).toBe(3)
    end)

    it("should return cached snapshot when no live data is available", function()
        local ns = loadAll()

        -- Cache a party
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        ns.PartyScanner:CachePartySnapshot()

        -- Clear live data
        _G._mockUnits = {}

        local merged = ns.PartyScanner:GetMergedParty()
        expect(#merged).toBe(1)
        expect(merged[1].name).toBe("Alice")
    end)

    it("should return empty table when no live data and no cache", function()
        local ns = loadAll()
        local merged = ns.PartyScanner:GetMergedParty()
        expect(#merged).toBe(0)
    end)

    it("should not duplicate members present in both live and cache", function()
        local ns = loadAll()

        -- Cache a party
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        _G._mockUnits["party2"] = { name = "Bob", realm = "Thrall", classDisplayName = "Priest", className = "PRIEST", role = "HEALER" }
        ns.PartyScanner:CachePartySnapshot()

        -- Live data has same members
        local merged = ns.PartyScanner:GetMergedParty()
        expect(#merged).toBe(2)
    end)
end)

exitWithResults()
