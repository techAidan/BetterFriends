-- Tests for FriendRequestPopup.lua
package.path = package.path .. ";tests/?.lua"
require("test_runner")
require("wow_api_mock")

local function loadAll()
    ResetMocks()
    LoadAddonFile("BetterFriends/Utils.lua")
    LoadAddonFile("BetterFriends/Data.lua")
    LoadAddonFile("BetterFriends/Core.lua")
    LoadAddonFile("BetterFriends/PartyScanner.lua")
    LoadAddonFile("BetterFriends/BNetLinker.lua")
    LoadAddonFile("BetterFriends/MythicPlusTracker.lua")
    LoadAddonFile("BetterFriends/FriendRequestPopup.lua")
    local ns = BetterFriendsNS
    local onEvent = ns.eventFrame:GetScript("OnEvent")
    onEvent(ns.eventFrame, "ADDON_LOADED", "BetterFriends")
    return ns
end

local function makeMember(name, realm, classToken, classDisplayName, role)
    return {
        name = name,
        realm = realm,
        nameRealm = string.lower(name) .. "-" .. string.lower(realm),
        classToken = classToken,
        classDisplayName = classDisplayName,
        role = role,
    }
end

local function makeCompletionData(members, dungeonName, keyLevel, onTime)
    return {
        members = members or {},
        dungeonName = dungeonName or "Ara-Kara",
        keyLevel = keyLevel or 12,
        onTime = onTime == nil and true or onTime,
    }
end

describe("FriendRequestPopup: Create", function()
    it("should create a frame", function()
        local ns = loadAll()

        ns.FriendRequestPopup:Create()

        expect(ns.FriendRequestPopup.frame).toNotBeNil()
        expect(ns.FriendRequestPopup.frame._type).toBe("Frame")
    end)
end)

describe("FriendRequestPopup: Show", function()
    it("should create frame and show it with valid data", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members, "Ara-Kara", 12, true)

        ns.FriendRequestPopup:Show(data)

        expect(ns.FriendRequestPopup.frame).toNotBeNil()
        expect(ns.FriendRequestPopup.frame:IsShown()).toBe(true)
    end)

    it("should set dungeon info text with key level and dungeon name", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members, "Ara-Kara", 12, true)

        ns.FriendRequestPopup:Show(data)

        local infoText = ns.FriendRequestPopup.dungeonInfoText:GetText()
        expect(infoText).toContain("+12")
        expect(infoText).toContain("Ara-Kara")
    end)

    it("should differentiate timed vs depleted", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }

        -- Timed
        local timedData = makeCompletionData(members, "Ara-Kara", 12, true)
        ns.FriendRequestPopup:Show(timedData)
        local timedText = ns.FriendRequestPopup.dungeonInfoText:GetText()
        expect(timedText).toContain("Timed")

        -- Depleted
        local depletedData = makeCompletionData(members, "Ara-Kara", 12, false)
        ns.FriendRequestPopup:Show(depletedData)
        local depletedText = ns.FriendRequestPopup.dungeonInfoText:GetText()
        expect(depletedText).toContain("Depleted")
    end)

    it("should show add button for non-friended members", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members)

        ns.FriendRequestPopup:Show(data)

        local row = ns.FriendRequestPopup.memberRows[1]
        expect(row).toNotBeNil()
        expect(row.addButton:IsShown()).toBe(true)
        expect(row.addButton:GetText()).toBe("Add Friend")
    end)

    it("should hide add button for already-tracked friends", function()
        local ns = loadAll()

        -- Pre-add this friend
        ns.Data:AddFriend("sword-thrall", {
            characterName = "Sword",
            realm = "Thrall",
            className = "WARRIOR",
            classDisplayName = "Warrior",
            role = "TANK",
            addedDungeon = "The Stonevault",
            addedKeyLevel = 10,
        })

        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members)

        ns.FriendRequestPopup:Show(data)

        local row = ns.FriendRequestPopup.memberRows[1]
        expect(row).toNotBeNil()
        expect(row.addButton:IsShown()).toBe(false)
        expect(row.statusText:IsShown()).toBe(true)
    end)

    it("should hide unused rows", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
            makeMember("Arrow", "Thrall", "HUNTER", "Hunter", "DAMAGER"),
        }
        local data = makeCompletionData(members)

        ns.FriendRequestPopup:Show(data)

        -- Rows 1 and 2 should be shown, rows 3 and 4 hidden
        expect(ns.FriendRequestPopup.memberRows[1].row:IsShown()).toBe(true)
        expect(ns.FriendRequestPopup.memberRows[2].row:IsShown()).toBe(true)
        expect(ns.FriendRequestPopup.memberRows[3].row:IsShown()).toBe(false)
        expect(ns.FriendRequestPopup.memberRows[4].row:IsShown()).toBe(false)
    end)

    it("should reuse existing frame when called again", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members)

        ns.FriendRequestPopup:Show(data)
        local firstFrame = ns.FriendRequestPopup.frame

        ns.FriendRequestPopup:Show(data)
        local secondFrame = ns.FriendRequestPopup.frame

        expect(firstFrame).toBe(secondFrame)
    end)

    it("should set role text on member rows", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members)

        ns.FriendRequestPopup:Show(data)

        local roleText = ns.FriendRequestPopup.memberRows[1].roleText:GetText()
        expect(roleText).toContain("Tank")
    end)

    it("should set class-colored name text on member rows", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members)

        ns.FriendRequestPopup:Show(data)

        local nameText = ns.FriendRequestPopup.memberRows[1].nameText:GetText()
        expect(nameText).toContain("Sword")
    end)
end)

describe("FriendRequestPopup: OnAddFriend", function()
    it("should send BNSendFriendInvite with correct name-realm format", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members, "Ara-Kara", 12, true)

        ns.FriendRequestPopup:Show(data)
        _G._mockBNetInvitesSent = {}

        ns.FriendRequestPopup:OnAddFriend(members[1])

        expect(#_G._mockBNetInvitesSent).toBe(1)
        expect(_G._mockBNetInvitesSent[1].text).toBe("Sword-Thrall")
    end)

    it("should store friend in Data with correct dungeon context", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members, "Ara-Kara", 12, true)

        ns.FriendRequestPopup:Show(data)
        ns.FriendRequestPopup:OnAddFriend(members[1])

        local friend = ns.Data:GetFriend("sword-thrall")
        expect(friend).toNotBeNil()
        expect(friend.characterName).toBe("Sword")
        expect(friend.realm).toBe("Thrall")
        expect(friend.className).toBe("WARRIOR")
        expect(friend.addedDungeon).toBe("Ara-Kara")
        expect(friend.addedKeyLevel).toBe(12)
    end)

    it("should prevent duplicate sends via sentThisSession", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members, "Ara-Kara", 12, true)

        ns.FriendRequestPopup:Show(data)
        _G._mockBNetInvitesSent = {}

        ns.FriendRequestPopup:OnAddFriend(members[1])
        ns.FriendRequestPopup:OnAddFriend(members[1])

        expect(#_G._mockBNetInvitesSent).toBe(1)
    end)

    it("should call BNetLinker snapshot and pending invite", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members, "Ara-Kara", 12, true)

        -- Set up some existing BNet friends so we can verify snapshot was taken
        _G._mockBNetFriends = {
            { bnetAccountID = 100, battleTag = "Alice#1234", isOnline = true, gameAccounts = {} },
        }

        ns.FriendRequestPopup:Show(data)
        ns.FriendRequestPopup:OnAddFriend(members[1])

        -- Verify snapshot was taken
        expect(ns.BNetLinker.bnetSnapshot[100]).toBe(true)

        -- Verify pending invite was added
        local invites = ns.BNetLinker:GetPendingInvites()
        expect(invites["sword-thrall"]).toNotBeNil()
        expect(invites["sword-thrall"].timestamp).toNotBeNil()
    end)
end)

describe("FriendRequestPopup: OnAddAll", function()
    it("should send for all non-friended members", function()
        local ns = loadAll()

        -- Pre-add one friend so it gets skipped
        ns.Data:AddFriend("healer-thrall", {
            characterName = "Healer",
            realm = "Thrall",
            className = "PRIEST",
            classDisplayName = "Priest",
            role = "HEALER",
            addedDungeon = "The Stonevault",
            addedKeyLevel = 10,
        })

        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
            makeMember("Arrow", "Thrall", "HUNTER", "Hunter", "DAMAGER"),
            makeMember("Healer", "Thrall", "PRIEST", "Priest", "HEALER"),
        }
        local data = makeCompletionData(members, "Ara-Kara", 12, true)

        ns.FriendRequestPopup:Show(data)
        _G._mockBNetInvitesSent = {}

        ns.FriendRequestPopup:OnAddAll()

        -- Should send for Sword and Arrow, skip Healer (already tracked)
        expect(#_G._mockBNetInvitesSent).toBe(2)
    end)

    it("should not double-send for already sent members", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
            makeMember("Arrow", "Thrall", "HUNTER", "Hunter", "DAMAGER"),
        }
        local data = makeCompletionData(members, "Ara-Kara", 12, true)

        ns.FriendRequestPopup:Show(data)
        _G._mockBNetInvitesSent = {}

        -- Send one manually first
        ns.FriendRequestPopup:OnAddFriend(members[1])
        expect(#_G._mockBNetInvitesSent).toBe(1)

        -- Now add all - should only send Arrow
        ns.FriendRequestPopup:OnAddAll()
        expect(#_G._mockBNetInvitesSent).toBe(2)
    end)
end)

describe("FriendRequestPopup: Hide", function()
    it("should hide the frame", function()
        local ns = loadAll()
        local members = {
            makeMember("Sword", "Thrall", "WARRIOR", "Warrior", "TANK"),
        }
        local data = makeCompletionData(members)

        ns.FriendRequestPopup:Show(data)
        expect(ns.FriendRequestPopup.frame:IsShown()).toBe(true)

        ns.FriendRequestPopup:Hide()
        expect(ns.FriendRequestPopup.frame:IsShown()).toBe(false)
    end)
end)

exitWithResults()
