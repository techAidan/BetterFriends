-- Tests for Data.lua
package.path = package.path .. ";tests/?.lua"
require("test_runner")
require("wow_api_mock")

-- Load dependencies then Data.lua
ResetMocks()
LoadAddonFile("BetterFriends/Utils.lua")
LoadAddonFile("BetterFriends/Data.lua")
local ns = BetterFriendsNS

describe("Data.Init", function()
    it("should create default DB when none exists", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS

        BetterFriendsDB = nil
        ns.Data:Init()

        expect(BetterFriendsDB).toNotBeNil()
        expect(BetterFriendsDB.schemaVersion).toBe(1)
        expect(BetterFriendsDB.friends).toNotBeNil()
        expect(BetterFriendsDB.settings).toNotBeNil()
        expect(BetterFriendsDB.settings.popupEnabled).toBeTruthy()
    end)

    it("should preserve existing data on re-init", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS

        BetterFriendsDB = {
            schemaVersion = 1,
            friends = {
                ["blob-thrall"] = { characterName = "Blob" },
            },
            settings = { popupEnabled = false },
        }
        ns.Data:Init()

        expect(BetterFriendsDB.friends["blob-thrall"].characterName).toBe("Blob")
        expect(BetterFriendsDB.settings.popupEnabled).toBeFalsy()
    end)

    it("should fill in missing settings with defaults", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS

        BetterFriendsDB = {
            schemaVersion = 1,
            friends = {},
            settings = {},
        }
        ns.Data:Init()

        expect(BetterFriendsDB.settings.popupEnabled).toBeTruthy()
        expect(BetterFriendsDB.settings.popupAutoDismissSeconds).toBe(60)
        expect(BetterFriendsDB.settings.minimapButtonShown).toBeTruthy()
    end)
end)

describe("Data.AddFriend", function()
    it("should add a new friend entry", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob",
            realm = "Thrall",
            className = "PALADIN",
            classDisplayName = "Paladin",
            role = "HEALER",
            addedDungeon = "Ara-Kara",
            addedKeyLevel = 12,
        })

        local friend = BetterFriendsDB.friends["blob-thrall"]
        expect(friend).toNotBeNil()
        expect(friend.characterName).toBe("Blob")
        expect(friend.className).toBe("PALADIN")
        expect(friend.role).toBe("HEALER")
        expect(friend.addedDungeon).toBe("Ara-Kara")
        expect(friend.addedKeyLevel).toBe(12)
        expect(friend.keysCompleted).toBe(1)
        expect(friend.highestKeyLevel).toBe(12)
        expect(friend.highestKeyDungeon).toBe("Ara-Kara")
        expect(friend.addedTimestamp).toNotBeNil()
    end)

    it("should not overwrite an existing friend", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob",
            realm = "Thrall",
            className = "PALADIN",
            classDisplayName = "Paladin",
            role = "HEALER",
            addedDungeon = "Ara-Kara",
            addedKeyLevel = 12,
        })

        -- Try to add again with different data
        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob",
            realm = "Thrall",
            className = "WARRIOR",
            classDisplayName = "Warrior",
            role = "TANK",
            addedDungeon = "Stonevault",
            addedKeyLevel = 20,
        })

        -- Should still have original data
        local friend = BetterFriendsDB.friends["blob-thrall"]
        expect(friend.className).toBe("PALADIN")
        expect(friend.role).toBe("HEALER")
    end)
end)

describe("Data.GetFriend", function()
    it("should return friend data if exists", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob",
            realm = "Thrall",
            className = "PALADIN",
            classDisplayName = "Paladin",
            role = "HEALER",
            addedDungeon = "Ara-Kara",
            addedKeyLevel = 12,
        })

        local friend = ns.Data:GetFriend("blob-thrall")
        expect(friend).toNotBeNil()
        expect(friend.characterName).toBe("Blob")
    end)

    it("should return nil if friend does not exist", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        expect(ns.Data:GetFriend("nobody-nowhere")).toBeNil()
    end)
end)

describe("Data.IsFriend", function()
    it("should return true for tracked friends", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob", realm = "Thrall",
            className = "PALADIN", classDisplayName = "Paladin",
            role = "HEALER", addedDungeon = "Ara-Kara", addedKeyLevel = 12,
        })

        expect(ns.Data:IsFriend("blob-thrall")).toBeTruthy()
    end)

    it("should return false for non-tracked names", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        expect(ns.Data:IsFriend("nobody-nowhere")).toBeFalsy()
    end)
end)

describe("Data.UpdateFriendKeyStats", function()
    it("should increment keysCompleted", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob", realm = "Thrall",
            className = "PALADIN", classDisplayName = "Paladin",
            role = "HEALER", addedDungeon = "Ara-Kara", addedKeyLevel = 12,
        })

        ns.Data:UpdateFriendKeyStats("blob-thrall", "Stonevault", 15)

        local friend = ns.Data:GetFriend("blob-thrall")
        expect(friend.keysCompleted).toBe(2)
    end)

    it("should update highest key when new key is higher", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob", realm = "Thrall",
            className = "PALADIN", classDisplayName = "Paladin",
            role = "HEALER", addedDungeon = "Ara-Kara", addedKeyLevel = 12,
        })

        ns.Data:UpdateFriendKeyStats("blob-thrall", "Stonevault", 18)

        local friend = ns.Data:GetFriend("blob-thrall")
        expect(friend.highestKeyLevel).toBe(18)
        expect(friend.highestKeyDungeon).toBe("Stonevault")
    end)

    it("should NOT update highest key when new key is lower", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob", realm = "Thrall",
            className = "PALADIN", classDisplayName = "Paladin",
            role = "HEALER", addedDungeon = "Ara-Kara", addedKeyLevel = 12,
        })

        ns.Data:UpdateFriendKeyStats("blob-thrall", "Stonevault", 8)

        local friend = ns.Data:GetFriend("blob-thrall")
        expect(friend.highestKeyLevel).toBe(12)
        expect(friend.highestKeyDungeon).toBe("Ara-Kara")
    end)

    it("should update lastSeenTimestamp", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob", realm = "Thrall",
            className = "PALADIN", classDisplayName = "Paladin",
            role = "HEALER", addedDungeon = "Ara-Kara", addedKeyLevel = 12,
        })

        local before = ns.Data:GetFriend("blob-thrall").lastSeenTimestamp
        -- Small delay isn't reliable in tests, so just check it's set
        ns.Data:UpdateFriendKeyStats("blob-thrall", "Stonevault", 15)
        local after = ns.Data:GetFriend("blob-thrall").lastSeenTimestamp
        expect(after).toNotBeNil()
    end)

    it("should do nothing for non-tracked friends", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        -- Should not error
        ns.Data:UpdateFriendKeyStats("nobody-nowhere", "Stonevault", 15)
        expect(ns.Data:GetFriend("nobody-nowhere")).toBeNil()
    end)
end)

describe("Data.GetAllFriends", function()
    it("should return all tracked friends", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob", realm = "Thrall",
            className = "PALADIN", classDisplayName = "Paladin",
            role = "HEALER", addedDungeon = "Ara-Kara", addedKeyLevel = 12,
        })
        ns.Data:AddFriend("sword-thrall", {
            characterName = "Sword", realm = "Thrall",
            className = "WARRIOR", classDisplayName = "Warrior",
            role = "TANK", addedDungeon = "Stonevault", addedKeyLevel = 10,
        })

        local friends = ns.Data:GetAllFriends()
        expect(friends["blob-thrall"]).toNotBeNil()
        expect(friends["sword-thrall"]).toNotBeNil()
    end)
end)

describe("Data.GetSettings", function()
    it("should return settings table", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        local settings = ns.Data:GetSettings()
        expect(settings).toNotBeNil()
        expect(settings.popupEnabled).toBeTruthy()
    end)
end)

describe("Data.SetBNetLink", function()
    it("should store bnet account ID and tag", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob", realm = "Thrall",
            className = "PALADIN", classDisplayName = "Paladin",
            role = "HEALER", addedDungeon = "Ara-Kara", addedKeyLevel = 12,
        })

        ns.Data:SetBNetLink("blob-thrall", 12345, "Keith#1234")

        local friend = ns.Data:GetFriend("blob-thrall")
        expect(friend.bnetAccountID).toBe(12345)
        expect(friend.bnetTag).toBe("Keith#1234")
    end)

    it("should do nothing for non-tracked friends", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:SetBNetLink("nobody-nowhere", 99999, "Nobody#0000")
        expect(ns.Data:GetFriend("nobody-nowhere")).toBeNil()
    end)
end)

describe("Data.ClearBNetLink", function()
    it("should clear bnet link but keep friend data", function()
        ResetMocks()
        LoadAddonFile("BetterFriends/Utils.lua")
        LoadAddonFile("BetterFriends/Data.lua")
        ns = BetterFriendsNS
        ns.Data:Init()

        ns.Data:AddFriend("blob-thrall", {
            characterName = "Blob", realm = "Thrall",
            className = "PALADIN", classDisplayName = "Paladin",
            role = "HEALER", addedDungeon = "Ara-Kara", addedKeyLevel = 12,
        })
        ns.Data:SetBNetLink("blob-thrall", 12345, "Keith#1234")
        ns.Data:ClearBNetLink("blob-thrall")

        local friend = ns.Data:GetFriend("blob-thrall")
        expect(friend.characterName).toBe("Blob")
        expect(friend.bnetAccountID).toBeNil()
        expect(friend.bnetTag).toBeNil()
    end)
end)

exitWithResults()
