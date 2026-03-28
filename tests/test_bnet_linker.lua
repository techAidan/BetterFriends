-- Tests for BNetLinker.lua
package.path = package.path .. ";tests/?.lua"
require("test_runner")
require("wow_api_mock")

local function loadAll()
    ResetMocks()
    LoadAddonFile("BetterFriends/Utils.lua")
    LoadAddonFile("BetterFriends/Data.lua")
    LoadAddonFile("BetterFriends/Core.lua")
    LoadAddonFile("BetterFriends/PartyScanner.lua")
    LoadAddonFile("BetterFriends/MythicPlusTracker.lua")
    LoadAddonFile("BetterFriends/BNetLinker.lua")
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

describe("BNetLinker: SnapshotBNetFriends", function()
    it("should capture all BNet friend account IDs", function()
        local ns = loadAll()

        _G._mockBNetFriends = {
            { bnetAccountID = 100, battleTag = "Alice#1234", isOnline = true, gameAccounts = {} },
            { bnetAccountID = 200, battleTag = "Bob#5678", isOnline = false, gameAccounts = {} },
            { bnetAccountID = 300, battleTag = "Carol#9012", isOnline = true, gameAccounts = {} },
        }

        ns.BNetLinker:SnapshotBNetFriends()

        expect(ns.BNetLinker.bnetSnapshot[100]).toBe(true)
        expect(ns.BNetLinker.bnetSnapshot[200]).toBe(true)
        expect(ns.BNetLinker.bnetSnapshot[300]).toBe(true)
    end)

    it("should handle empty BNet friends list", function()
        local ns = loadAll()

        _G._mockBNetFriends = {}

        ns.BNetLinker:SnapshotBNetFriends()

        -- Snapshot should be empty
        local count = 0
        for _ in pairs(ns.BNetLinker.bnetSnapshot) do count = count + 1 end
        expect(count).toBe(0)
    end)
end)

describe("BNetLinker: AddPendingInvite", function()
    it("should add a pending invite with timestamp", function()
        local ns = loadAll()

        ns.BNetLinker:AddPendingInvite("alice-thrall")

        local invites = ns.BNetLinker:GetPendingInvites()
        expect(invites["alice-thrall"]).toNotBeNil()
        expect(invites["alice-thrall"].timestamp).toNotBeNil()
    end)

    it("should track multiple pending invites", function()
        local ns = loadAll()

        ns.BNetLinker:AddPendingInvite("alice-thrall")
        ns.BNetLinker:AddPendingInvite("bob-thrall")

        local invites = ns.BNetLinker:GetPendingInvites()
        expect(invites["alice-thrall"]).toNotBeNil()
        expect(invites["bob-thrall"]).toNotBeNil()
    end)
end)

describe("BNetLinker: ProcessNewFriends", function()
    it("should detect new BNet friends via diff", function()
        local ns = loadAll()

        -- Start with one existing friend
        _G._mockBNetFriends = {
            { bnetAccountID = 100, battleTag = "OldFriend#1111", isOnline = true, gameAccounts = {} },
        }
        ns.BNetLinker:SnapshotBNetFriends()

        -- Add a new friend to the mock
        _G._mockBNetFriends = {
            { bnetAccountID = 100, battleTag = "OldFriend#1111", isOnline = true, gameAccounts = {} },
            {
                bnetAccountID = 200,
                battleTag = "NewFriend#2222",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Sword", realmName = "Thrall", className = "Warrior", areaName = "Dornogal" },
                },
            },
        }

        -- Add a pending invite for the new friend's character
        ns.BNetLinker:AddPendingInvite("sword-thrall")

        -- Add sword-thrall as a tracked friend first
        ns.Data:AddFriend("sword-thrall", {
            characterName = "Sword",
            realm = "Thrall",
            className = "WARRIOR",
            classDisplayName = "Warrior",
            role = "TANK",
            addedDungeon = "The Stonevault",
            addedKeyLevel = 10,
        })

        ns.BNetLinker:ProcessNewFriends()

        -- Should have linked the friend
        local friend = ns.Data:GetFriend("sword-thrall")
        expect(friend.bnetAccountID).toBe(200)
        expect(friend.bnetTag).toBe("NewFriend#2222")
    end)

    it("should remove matched invite from pending", function()
        local ns = loadAll()

        _G._mockBNetFriends = {}
        ns.BNetLinker:SnapshotBNetFriends()

        _G._mockBNetFriends = {
            {
                bnetAccountID = 200,
                battleTag = "NewFriend#2222",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Sword", realmName = "Thrall", className = "Warrior", areaName = "Dornogal" },
                },
            },
        }

        ns.BNetLinker:AddPendingInvite("sword-thrall")
        ns.Data:AddFriend("sword-thrall", {
            characterName = "Sword",
            realm = "Thrall",
            className = "WARRIOR",
            classDisplayName = "Warrior",
            role = "TANK",
            addedDungeon = "The Stonevault",
            addedKeyLevel = 10,
        })

        ns.BNetLinker:ProcessNewFriends()

        local invites = ns.BNetLinker:GetPendingInvites()
        expect(invites["sword-thrall"]).toBeNil()
    end)

    it("should not match when no pending invites exist", function()
        local ns = loadAll()

        _G._mockBNetFriends = {}
        ns.BNetLinker:SnapshotBNetFriends()

        _G._mockBNetFriends = {
            {
                bnetAccountID = 200,
                battleTag = "NewFriend#2222",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Sword", realmName = "Thrall", className = "Warrior", areaName = "Dornogal" },
                },
            },
        }

        -- No pending invites, no crash
        ns.BNetLinker:ProcessNewFriends()

        -- Snapshot should be updated
        expect(ns.BNetLinker.bnetSnapshot[200]).toBe(true)
    end)

    it("should update snapshot after processing", function()
        local ns = loadAll()

        _G._mockBNetFriends = {}
        ns.BNetLinker:SnapshotBNetFriends()

        _G._mockBNetFriends = {
            { bnetAccountID = 500, battleTag = "New#5555", isOnline = true, gameAccounts = {} },
        }

        ns.BNetLinker:ProcessNewFriends()

        expect(ns.BNetLinker.bnetSnapshot[500]).toBe(true)
    end)

    it("should be triggered by BN_FRIEND_LIST_SIZE_CHANGED event", function()
        local ns = loadAll()

        _G._mockBNetFriends = {}
        ns.BNetLinker:SnapshotBNetFriends()

        _G._mockBNetFriends = {
            {
                bnetAccountID = 200,
                battleTag = "NewFriend#2222",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Sword", realmName = "Thrall", className = "Warrior", areaName = "Dornogal" },
                },
            },
        }

        ns.BNetLinker:AddPendingInvite("sword-thrall")
        ns.Data:AddFriend("sword-thrall", {
            characterName = "Sword",
            realm = "Thrall",
            className = "WARRIOR",
            classDisplayName = "Warrior",
            role = "TANK",
            addedDungeon = "The Stonevault",
            addedKeyLevel = 10,
        })

        fireEvent(ns, "BN_FRIEND_LIST_SIZE_CHANGED")

        local friend = ns.Data:GetFriend("sword-thrall")
        expect(friend.bnetAccountID).toBe(200)
    end)
end)

describe("BNetLinker: GetLiveStatus", function()
    it("should return online info for linked friend", function()
        local ns = loadAll()

        -- Add and link a friend
        ns.Data:AddFriend("sword-thrall", {
            characterName = "Sword",
            realm = "Thrall",
            className = "WARRIOR",
            classDisplayName = "Warrior",
            role = "TANK",
            addedDungeon = "The Stonevault",
            addedKeyLevel = 10,
        })
        ns.Data:SetBNetLink("sword-thrall", 200, "Keith#1234")

        _G._mockBNetFriends = {
            {
                bnetAccountID = 200,
                battleTag = "Keith#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Sword", realmName = "Thrall", className = "Warrior", areaName = "Dornogal" },
                },
            },
        }

        local status = ns.BNetLinker:GetLiveStatus("sword-thrall")
        expect(status).toNotBeNil()
        expect(status.isOnline).toBe(true)
        expect(status.currentCharacter).toBe("Sword")
        expect(status.currentRealm).toBe("Thrall")
        expect(status.currentClass).toBe("Warrior")
        expect(status.zone).toBe("Dornogal")
    end)

    it("should return nil for unlinked friend", function()
        local ns = loadAll()

        ns.Data:AddFriend("sword-thrall", {
            characterName = "Sword",
            realm = "Thrall",
            className = "WARRIOR",
            classDisplayName = "Warrior",
            role = "TANK",
            addedDungeon = "The Stonevault",
            addedKeyLevel = 10,
        })
        -- No BNet link set

        local status = ns.BNetLinker:GetLiveStatus("sword-thrall")
        expect(status).toBeNil()
    end)

    it("should return nil for unknown friend", function()
        local ns = loadAll()

        local status = ns.BNetLinker:GetLiveStatus("nobody-nowhere")
        expect(status).toBeNil()
    end)
end)

describe("BNetLinker: FindBNetIndexByAccountID", function()
    it("should find the correct index for an account ID", function()
        local ns = loadAll()

        _G._mockBNetFriends = {
            { bnetAccountID = 100, battleTag = "Alice#1111", isOnline = true, gameAccounts = {} },
            { bnetAccountID = 200, battleTag = "Bob#2222", isOnline = false, gameAccounts = {} },
            { bnetAccountID = 300, battleTag = "Carol#3333", isOnline = true, gameAccounts = {} },
        }

        expect(ns.BNetLinker:FindBNetIndexByAccountID(100)).toBe(1)
        expect(ns.BNetLinker:FindBNetIndexByAccountID(200)).toBe(2)
        expect(ns.BNetLinker:FindBNetIndexByAccountID(300)).toBe(3)
    end)

    it("should return nil for unknown account ID", function()
        local ns = loadAll()

        _G._mockBNetFriends = {
            { bnetAccountID = 100, battleTag = "Alice#1111", isOnline = true, gameAccounts = {} },
        }

        expect(ns.BNetLinker:FindBNetIndexByAccountID(999)).toBeNil()
    end)

    it("should return nil when BNet friends list is empty", function()
        local ns = loadAll()

        _G._mockBNetFriends = {}

        expect(ns.BNetLinker:FindBNetIndexByAccountID(100)).toBeNil()
    end)
end)

describe("BNetLinker: Slash command /bf link", function()
    it("should manually link a friend to a BattleTag", function()
        local ns = loadAll()

        ns.Data:AddFriend("sword-thrall", {
            characterName = "Sword",
            realm = "Thrall",
            className = "WARRIOR",
            classDisplayName = "Warrior",
            role = "TANK",
            addedDungeon = "The Stonevault",
            addedKeyLevel = 10,
        })

        _G._mockBNetFriends = {
            { bnetAccountID = 200, battleTag = "Keith#1234", isOnline = true, gameAccounts = {} },
        }

        _G._capturedPrints = {}
        ns.SlashHandlers["link"]("link Sword-Thrall Keith#1234")

        local friend = ns.Data:GetFriend("sword-thrall")
        expect(friend.bnetAccountID).toBe(200)
        expect(friend.bnetTag).toBe("Keith#1234")
    end)

    it("should print usage when no args provided", function()
        local ns = loadAll()

        _G._capturedPrints = {}
        ns.SlashHandlers["link"]("link")

        expect(#_G._capturedPrints > 0).toBeTruthy()
        local output = table.concat(_G._capturedPrints, " ")
        expect(output).toContain("Usage")
    end)

    it("should print error for non-existent friend", function()
        local ns = loadAll()

        _G._capturedPrints = {}
        ns.SlashHandlers["link"]("link Nobody-Nowhere Keith#1234")

        expect(#_G._capturedPrints > 0).toBeTruthy()
        local output = table.concat(_G._capturedPrints, " ")
        expect(output).toContain("not in your friends list")
    end)
end)

exitWithResults()
