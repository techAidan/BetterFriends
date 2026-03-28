-- Tests for FriendsViewer.lua
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
    LoadAddonFile("BetterFriends/FriendsViewer.lua")
    local ns = BetterFriendsNS
    local onEvent = ns.eventFrame:GetScript("OnEvent")
    onEvent(ns.eventFrame, "ADDON_LOADED", "BetterFriends")
    return ns
end

local function addFriend(ns, name, realm, classToken, classDisplayName, role, dungeon, keyLevel, bnetAccountID, bnetTag)
    local nameRealm = string.lower(name) .. "-" .. string.lower(realm)
    ns.Data:AddFriend(nameRealm, {
        characterName = name,
        realm = realm,
        className = classToken,
        classDisplayName = classDisplayName,
        role = role,
        addedDungeon = dungeon or "Ara-Kara",
        addedKeyLevel = keyLevel or 10,
    })
    if bnetAccountID then
        ns.Data:SetBNetLink(nameRealm, bnetAccountID, bnetTag)
    end
    return nameRealm
end

-- ============================================================
-- Tests
-- ============================================================

describe("FriendsViewer: Create", function()
    it("should create a frame", function()
        local ns = loadAll()

        ns.FriendsViewer:Create()

        expect(ns.FriendsViewer.frame).toNotBeNil()
        expect(ns.FriendsViewer.frame._type).toBe("Frame")
    end)

    it("should create rows table", function()
        local ns = loadAll()

        ns.FriendsViewer:Create()

        expect(ns.FriendsViewer.rows).toNotBeNil()
        expect(type(ns.FriendsViewer.rows)).toBe("table")
    end)

    it("should set frame size roughly 600x450", function()
        local ns = loadAll()

        ns.FriendsViewer:Create()

        expect(ns.FriendsViewer.frame:GetWidth()).toBe(600)
        expect(ns.FriendsViewer.frame:GetHeight()).toBe(450)
    end)
end)

describe("FriendsViewer: Show", function()
    it("should create frame and show it", function()
        local ns = loadAll()

        ns.FriendsViewer:Show()

        expect(ns.FriendsViewer.frame).toNotBeNil()
        expect(ns.FriendsViewer.frame:IsShown()).toBe(true)
    end)

    it("should reuse existing frame when called again", function()
        local ns = loadAll()

        ns.FriendsViewer:Show()
        local firstFrame = ns.FriendsViewer.frame

        ns.FriendsViewer:Show()
        expect(ns.FriendsViewer.frame).toBe(firstFrame)
    end)
end)

describe("FriendsViewer: Toggle", function()
    it("should show when hidden", function()
        local ns = loadAll()

        ns.FriendsViewer:Toggle()

        expect(ns.FriendsViewer.frame:IsShown()).toBe(true)
    end)

    it("should hide when shown", function()
        local ns = loadAll()

        ns.FriendsViewer:Show()
        expect(ns.FriendsViewer.frame:IsShown()).toBe(true)

        ns.FriendsViewer:Toggle()
        expect(ns.FriendsViewer.frame:IsShown()).toBe(false)
    end)
end)

describe("FriendsViewer: Hide", function()
    it("should hide the frame", function()
        local ns = loadAll()

        ns.FriendsViewer:Show()
        expect(ns.FriendsViewer.frame:IsShown()).toBe(true)

        ns.FriendsViewer:Hide()
        expect(ns.FriendsViewer.frame:IsShown()).toBe(false)
    end)
end)

describe("FriendsViewer: RefreshData", function()
    it("should build display list from Data", function()
        local ns = loadAll()

        addFriend(ns, "Sword", "Thrall", "WARRIOR", "Warrior", "TANK")
        addFriend(ns, "Arrow", "Thrall", "HUNTER", "Hunter", "DAMAGER")

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(list).toNotBeNil()
        expect(#list).toBe(2)
    end)

    it("should sort online friends first", function()
        local ns = loadAll()

        -- Add two friends, one with BNet (will be online), one without (offline)
        addFriend(ns, "Offline", "Thrall", "WARRIOR", "Warrior", "TANK")
        addFriend(ns, "Online", "Thrall", "HUNTER", "Hunter", "DAMAGER", nil, nil, 200, "Online#1234")

        -- Set up BNet mock so Online friend appears online
        _G._mockBNetFriends = {
            {
                bnetAccountID = 200,
                battleTag = "Online#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Online", realmName = "Thrall", className = "HUNTER", areaName = "Valdrakken" },
                },
            },
        }

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(#list).toBe(2)
        -- Online friend should be first
        expect(list[1].nameRealm).toBe("online-thrall")
        expect(list[2].nameRealm).toBe("offline-thrall")
    end)

    it("should sort alphabetically within online and offline groups", function()
        local ns = loadAll()

        -- Three offline friends in non-alphabetical order
        addFriend(ns, "Zephyr", "Thrall", "MAGE", "Mage", "DAMAGER")
        addFriend(ns, "Alpha", "Thrall", "WARRIOR", "Warrior", "TANK")
        addFriend(ns, "Middle", "Thrall", "PRIEST", "Priest", "HEALER")

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(#list).toBe(3)
        expect(list[1].friend.characterName).toBe("Alpha")
        expect(list[2].friend.characterName).toBe("Middle")
        expect(list[3].friend.characterName).toBe("Zephyr")
    end)

    it("should handle empty friends list", function()
        local ns = loadAll()

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(list).toNotBeNil()
        expect(#list).toBe(0)
    end)

    it("should handle friends with no BNet link as offline", function()
        local ns = loadAll()

        addFriend(ns, "NoBnet", "Thrall", "ROGUE", "Rogue", "DAMAGER")

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(#list).toBe(1)
        expect(list[1].liveStatus).toBeNil()
    end)
end)

describe("FriendsViewer: GetFriendCount", function()
    it("should return correct count", function()
        local ns = loadAll()

        addFriend(ns, "Sword", "Thrall", "WARRIOR", "Warrior", "TANK")
        addFriend(ns, "Arrow", "Thrall", "HUNTER", "Hunter", "DAMAGER")
        addFriend(ns, "Heal", "Thrall", "PRIEST", "Priest", "HEALER")

        ns.FriendsViewer:Show()

        expect(ns.FriendsViewer:GetFriendCount()).toBe(3)
    end)

    it("should return 0 for empty list", function()
        local ns = loadAll()

        ns.FriendsViewer:Show()

        expect(ns.FriendsViewer:GetFriendCount()).toBe(0)
    end)
end)

describe("FriendsViewer: GetOnlineCount", function()
    it("should return correct online count with mock BNet data", function()
        local ns = loadAll()

        addFriend(ns, "OnlineOne", "Thrall", "WARRIOR", "Warrior", "TANK", nil, nil, 100, "One#1234")
        addFriend(ns, "OnlineTwo", "Thrall", "HUNTER", "Hunter", "DAMAGER", nil, nil, 200, "Two#1234")
        addFriend(ns, "OfflineBnet", "Thrall", "MAGE", "Mage", "DAMAGER", nil, nil, 300, "Three#1234")
        addFriend(ns, "NoBnet", "Thrall", "PRIEST", "Priest", "HEALER")

        _G._mockBNetFriends = {
            {
                bnetAccountID = 100,
                battleTag = "One#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "OnlineOne", realmName = "Thrall", className = "WARRIOR", areaName = "Valdrakken" },
                },
            },
            {
                bnetAccountID = 200,
                battleTag = "Two#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "OnlineTwo", realmName = "Thrall", className = "HUNTER", areaName = "Valdrakken" },
                },
            },
            {
                bnetAccountID = 300,
                battleTag = "Three#1234",
                isOnline = false,
                gameAccounts = {},
            },
        }

        ns.FriendsViewer:Show()

        expect(ns.FriendsViewer:GetOnlineCount()).toBe(2)
    end)

    it("should return 0 when no friends are online", function()
        local ns = loadAll()

        addFriend(ns, "NoBnet", "Thrall", "WARRIOR", "Warrior", "TANK")

        ns.FriendsViewer:Show()

        expect(ns.FriendsViewer:GetOnlineCount()).toBe(0)
    end)
end)

describe("FriendsViewer: Footer text", function()
    it("should show correct counts in footer", function()
        local ns = loadAll()

        addFriend(ns, "OnlinePal", "Thrall", "WARRIOR", "Warrior", "TANK", nil, nil, 100, "Pal#1234")
        addFriend(ns, "OfflinePal", "Thrall", "HUNTER", "Hunter", "DAMAGER")

        _G._mockBNetFriends = {
            {
                bnetAccountID = 100,
                battleTag = "Pal#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "OnlinePal", realmName = "Thrall", className = "WARRIOR", areaName = "Valdrakken" },
                },
            },
        }

        ns.FriendsViewer:Show()

        local footerText = ns.FriendsViewer.footerText:GetText()
        expect(footerText).toContain("1 online")
        expect(footerText).toContain("2 tracked")
    end)
end)

describe("FriendsViewer: Display entry structure", function()
    it("should have correct fields in display entries", function()
        local ns = loadAll()

        addFriend(ns, "Sword", "Thrall", "WARRIOR", "Warrior", "TANK", "Ara-Kara", 12, 100, "Sword#1234")

        _G._mockBNetFriends = {
            {
                bnetAccountID = 100,
                battleTag = "Sword#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Sword", realmName = "Thrall", className = "WARRIOR", areaName = "Valdrakken" },
                },
            },
        }

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(#list).toBe(1)

        local entry = list[1]
        expect(entry.nameRealm).toBe("sword-thrall")
        expect(entry.friend).toNotBeNil()
        expect(entry.friend.characterName).toBe("Sword")
        expect(entry.liveStatus).toNotBeNil()
        expect(entry.liveStatus.isOnline).toBe(true)
        expect(entry.liveStatus.zone).toBe("Valdrakken")
    end)

    it("should have nil liveStatus for friends without BNet", function()
        local ns = loadAll()

        addFriend(ns, "NoBnet", "Thrall", "ROGUE", "Rogue", "DAMAGER")

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(#list).toBe(1)
        expect(list[1].nameRealm).toBe("nobnet-thrall")
        expect(list[1].liveStatus).toBeNil()
    end)
end)

exitWithResults()
