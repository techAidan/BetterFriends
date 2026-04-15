-- Tests for MythicPlusTracker.lua
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
    LoadAddonFile("BetterFriends/MythicPlusTracker.lua")
    -- Initialize data
    local ns = BetterFriendsNS
    local onEvent = ns.eventFrame:GetScript("OnEvent")
    onEvent(ns.eventFrame, "ADDON_LOADED", "BetterFriends")
    return ns
end

local function fireEvent(ns, event, ...)
    local onEvent = ns.eventFrame:GetScript("OnEvent")
    onEvent(ns.eventFrame, event, ...)
end

local function setupMockCompletion(mapID, level, timeTaken, onTime, dungeonName)
    _G._mockChallengeMode.completionInfo = {
        mapChallengeModeID = mapID,
        level = level,
        time = timeTaken,
        onTime = onTime,
    }
    _G._mockChallengeMode.mapInfo[mapID] = {
        name = dungeonName,
        id = mapID,
        timeLimit = 1800000,
    }
end

describe("MythicPlusTracker: CHALLENGE_MODE_START", function()
    it("should cache party snapshot on CHALLENGE_MODE_START", function()
        local ns = loadAll()

        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        _G._mockUnits["party2"] = { name = "Bob", realm = "Thrall", classDisplayName = "Priest", className = "PRIEST", role = "HEALER" }

        fireEvent(ns, "CHALLENGE_MODE_START")

        local cached = ns.PartyScanner:GetCachedSnapshot()
        expect(cached).toNotBeNil()
        expect(#cached).toBe(2)
        expect(cached[1].name).toBe("Alice")
        expect(cached[2].name).toBe("Bob")
    end)
end)

describe("MythicPlusTracker: CHALLENGE_MODE_COMPLETED", function()
    it("should store lastCompletion with correct data", function()
        local ns = loadAll()

        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        _G._mockUnits["party2"] = { name = "Bob", realm = "Thrall", classDisplayName = "Priest", className = "PRIEST", role = "HEALER" }

        setupMockCompletion(375, 15, 1500000, true, "The Stonevault")

        fireEvent(ns, "CHALLENGE_MODE_COMPLETED")

        expect(ns.lastCompletion).toNotBeNil()
        expect(ns.lastCompletion.dungeonName).toBe("The Stonevault")
        expect(ns.lastCompletion.keyLevel).toBe(15)
        expect(ns.lastCompletion.onTime).toBe(true)
        expect(#ns.lastCompletion.members).toBe(2)
    end)

    it("should update friend stats for tracked friends on completion", function()
        local ns = loadAll()

        -- Add Alice as a tracked friend
        ns.Data:AddFriend("alice-thrall", {
            characterName = "Alice",
            realm = "Thrall",
            className = "WARRIOR",
            classDisplayName = "Warrior",
            role = "TANK",
            addedDungeon = "The Stonevault",
            addedKeyLevel = 10,
        })

        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        _G._mockUnits["party2"] = { name = "Bob", realm = "Thrall", classDisplayName = "Priest", className = "PRIEST", role = "HEALER" }

        setupMockCompletion(375, 15, 1500000, true, "The Stonevault")

        fireEvent(ns, "CHALLENGE_MODE_COMPLETED")

        local friend = ns.Data:GetFriend("alice-thrall")
        expect(friend.keysCompleted).toBe(2) -- 1 from AddFriend + 1 from completion
        expect(friend.highestKeyLevel).toBe(15)
        expect(friend.highestKeyDungeon).toBe("The Stonevault")
    end)

    it("should not update stats for non-tracked party members", function()
        local ns = loadAll()

        -- Bob is NOT a tracked friend
        _G._mockUnits["party1"] = { name = "Bob", realm = "Thrall", classDisplayName = "Priest", className = "PRIEST", role = "HEALER" }

        setupMockCompletion(375, 15, 1500000, true, "The Stonevault")

        fireEvent(ns, "CHALLENGE_MODE_COMPLETED")

        local friend = ns.Data:GetFriend("bob-thrall")
        expect(friend).toBeNil()
    end)

    it("should not crash when GetCompletionInfo returns nil", function()
        local ns = loadAll()

        _G._mockChallengeMode.completionInfo = nil

        -- Should not error
        fireEvent(ns, "CHALLENGE_MODE_COMPLETED")

        expect(ns.lastCompletion).toBeNil()
    end)

    it("should call FriendRequestPopup:Show if it exists", function()
        local ns = loadAll()

        local popupData = nil
        ns.FriendRequestPopup = {
            Show = function(self, data)
                popupData = data
            end,
        }

        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        setupMockCompletion(375, 15, 1500000, true, "The Stonevault")

        fireEvent(ns, "CHALLENGE_MODE_COMPLETED")

        expect(popupData).toNotBeNil()
        expect(popupData.dungeonName).toBe("The Stonevault")
    end)

    it("should not crash when FriendRequestPopup does not exist", function()
        local ns = loadAll()

        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        setupMockCompletion(375, 15, 1500000, true, "The Stonevault")

        -- No FriendRequestPopup set up, should not crash
        fireEvent(ns, "CHALLENGE_MODE_COMPLETED")
        expect(ns.lastCompletion).toNotBeNil()
    end)

    it("should use merged party data including cached members", function()
        local ns = loadAll()

        -- Cache a full party at start
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        _G._mockUnits["party2"] = { name = "Bob", realm = "Thrall", classDisplayName = "Priest", className = "PRIEST", role = "HEALER" }
        _G._mockUnits["party3"] = { name = "Carol", realm = "Thrall", classDisplayName = "Mage", className = "MAGE", role = "DAMAGER" }
        fireEvent(ns, "CHALLENGE_MODE_START")

        -- By completion time, Carol has disconnected
        _G._mockUnits = {}
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }
        _G._mockUnits["party2"] = { name = "Bob", realm = "Thrall", classDisplayName = "Priest", className = "PRIEST", role = "HEALER" }

        setupMockCompletion(375, 15, 1500000, true, "The Stonevault")

        fireEvent(ns, "CHALLENGE_MODE_COMPLETED")

        -- Should have all 3 members (2 live + 1 from cache)
        expect(#ns.lastCompletion.members).toBe(3)
    end)
end)

describe("MythicPlusTracker: PLAYER_LOGIN", function()
    it("should cache party when M+ is active on login", function()
        local ns = loadAll()

        _G._mockChallengeMode.active = true
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }

        fireEvent(ns, "PLAYER_LOGIN")

        local cached = ns.PartyScanner:GetCachedSnapshot()
        expect(cached).toNotBeNil()
        expect(#cached).toBe(1)
    end)

    it("should not cache party when M+ is not active on login", function()
        local ns = loadAll()

        _G._mockChallengeMode.active = false
        _G._mockUnits["party1"] = { name = "Alice", realm = "Thrall", classDisplayName = "Warrior", className = "WARRIOR", role = "TANK" }

        fireEvent(ns, "PLAYER_LOGIN")

        local cached = ns.PartyScanner:GetCachedSnapshot()
        expect(cached).toBeNil()
    end)
end)

exitWithResults()
