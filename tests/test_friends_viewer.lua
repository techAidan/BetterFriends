-- Tests for FriendsViewer.lua
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

    it("should set frame size to fit at least 12 rows", function()
        local ns = loadAll()

        ns.FriendsViewer:Create()

        expect(ns.FriendsViewer.frame:GetWidth()).toBe(620)
        expect(ns.FriendsViewer.frame:GetHeight()).toBe(560)
    end)

    it("should enable mouse wheel for scrolling", function()
        local ns = loadAll()

        ns.FriendsViewer:Create()

        expect(ns.FriendsViewer.frame._mouseWheelEnabled).toBe(true)
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

describe("FriendsViewer: BNet character-match online detection", function()
    it("should detect online status by character name when no bnetAccountID stored", function()
        local ns = loadAll()

        -- Add friend WITHOUT bnetAccountID
        addFriend(ns, "Urazall", "Thrall", "HUNTER", "Hunter", "DAMAGER")

        -- BNet friend list contains Urazall as an online character
        _G._mockBNetFriends = {
            {
                bnetAccountID = 555,
                battleTag = "Ura#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Urazall", realmName = "Thrall", className = "HUNTER", areaName = "Dornogal" },
                },
            },
        }

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(#list).toBe(1)
        expect(list[1]._isOnline).toBe(true)
        expect(list[1].liveStatus.zone).toBe("Dornogal")
    end)

    it("should opportunistically link BNet account when character match found", function()
        local ns = loadAll()

        local nameRealm = addFriend(ns, "Urazall", "Thrall", "HUNTER", "Hunter", "DAMAGER")

        _G._mockBNetFriends = {
            {
                bnetAccountID = 555,
                battleTag = "Ura#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Urazall", realmName = "Thrall", className = "HUNTER", areaName = "Dornogal" },
                },
            },
        }

        ns.FriendsViewer:Show()

        local friend = ns.Data:GetFriend(nameRealm)
        expect(friend.bnetAccountID).toBe(555)
        expect(friend.bnetTag).toBe("Ura#1234")
    end)

    it("should match when realm has spaces stripped (Area 52 vs Area52)", function()
        local ns = loadAll()

        -- Tracked friend stored with realm "Area52" (no space)
        addFriend(ns, "Urazall", "Area52", "HUNTER", "Hunter", "DAMAGER")

        -- BNet game account reports realm as "Area 52" (with space)
        _G._mockBNetFriends = {
            {
                bnetAccountID = 555,
                battleTag = "Ura#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Urazall", realmName = "Area 52", className = "HUNTER", areaName = "Dornogal" },
                },
            },
        }

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(#list).toBe(1)
        expect(list[1]._isOnline).toBe(true)
    end)

    it("should match by character name only when unambiguous", function()
        local ns = loadAll()

        -- Tracked friend stored with a realm that doesn't match the BNet realm at all
        addFriend(ns, "Urazall", "OldRealmName", "HUNTER", "Hunter", "DAMAGER")

        _G._mockBNetFriends = {
            {
                bnetAccountID = 555,
                battleTag = "Ura#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Urazall", realmName = "TotallyDifferent", className = "HUNTER", areaName = "Dornogal" },
                },
            },
        }

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(list[1]._isOnline).toBe(true)
    end)

    it("should NOT match by character name when ambiguous", function()
        local ns = loadAll()

        addFriend(ns, "Urazall", "OldRealmName", "HUNTER", "Hunter", "DAMAGER")

        -- Two BNet friends both have a character named Urazall on different realms
        _G._mockBNetFriends = {
            {
                bnetAccountID = 555,
                battleTag = "Ura#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Urazall", realmName = "RealmA", className = "HUNTER", areaName = "Dornogal" },
                },
            },
            {
                bnetAccountID = 666,
                battleTag = "Other#5678",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Urazall", realmName = "RealmB", className = "HUNTER", areaName = "Stormwind" },
                },
            },
        }

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        -- Ambiguous → no fallback match → should still appear offline
        expect(list[1]._isOnline).toBe(false)
    end)

    it("should detect online when only gameAccountInfo.isOnline is set (top-level isOnline nil)", function()
        local ns = loadAll()

        addFriend(ns, "Urazall", "Thrall", "HUNTER", "Hunter", "DAMAGER")

        -- Modern API quirk: top-level isOnline is nil, online status lives
        -- only on the inner gameAccountInfo struct.
        _G._mockBNetFriends = {
            {
                bnetAccountID = 555,
                battleTag = "Ura#1234",
                isOnline = nil,
                gameAccountInfo = {
                    clientProgram = "WoW",
                    isOnline = true,
                    characterName = "Urazall",
                    realmName = "Thrall",
                    className = "HUNTER",
                    areaName = "Dornogal",
                },
            },
        }

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(list[1]._isOnline).toBe(true)
    end)

    it("should detect online via modern info.gameAccountInfo (no gameAccounts field)", function()
        local ns = loadAll()

        addFriend(ns, "Urazall", "Thrall", "HUNTER", "Hunter", "DAMAGER")

        -- Modern API: only gameAccountInfo is set, gameAccounts is absent
        _G._mockBNetFriends = {
            {
                bnetAccountID = 555,
                battleTag = "Ura#1234",
                isOnline = true,
                gameAccountInfo = {
                    clientProgram = "WoW",
                    characterName = "Urazall",
                    realmName = "Thrall",
                    className = "HUNTER",
                    areaName = "Dornogal",
                },
            },
        }

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(list[1]._isOnline).toBe(true)
        expect(list[1].liveStatus.zone).toBe("Dornogal")
    end)

    it("should not match offline BNet friends", function()
        local ns = loadAll()

        addFriend(ns, "Urazall", "Thrall", "HUNTER", "Hunter", "DAMAGER")

        _G._mockBNetFriends = {
            {
                bnetAccountID = 555,
                battleTag = "Ura#1234",
                isOnline = false,
                gameAccounts = {
                    { characterName = "Urazall", realmName = "Thrall", className = "HUNTER", areaName = "Dornogal" },
                },
            },
        }

        ns.FriendsViewer:Show()

        local list = ns.FriendsViewer:GetDisplayList()
        expect(list[1]._isOnline).toBe(false)
    end)
end)

describe("FriendsViewer: Display formatting", function()
    it("should include role icon in line1 text", function()
        local ns = loadAll()

        addFriend(ns, "Blobheal", "Thrall", "PALADIN", "Paladin", "HEALER")

        ns.FriendsViewer:Show()

        -- rows[1] is now the section header; first friend row is rows[2].
        local text = ns.FriendsViewer.rows[2].line1:GetText()
        expect(text).toContain("roleicon-healer")
    end)

    it("should include class icon in line1 text", function()
        local ns = loadAll()

        addFriend(ns, "Blobheal", "Thrall", "PALADIN", "Paladin", "HEALER")

        ns.FriendsViewer:Show()

        local text = ns.FriendsViewer.rows[2].line1:GetText()
        expect(text).toContain("classicon-paladin")
    end)

    it("should include BNet tag in line1 when linked", function()
        local ns = loadAll()

        addFriend(ns, "Blobheal", "Thrall", "PALADIN", "Paladin", "HEALER", nil, nil, 100, "Keith#1234")

        ns.FriendsViewer:Show()

        local text = ns.FriendsViewer.rows[2].line1:GetText()
        expect(text).toContain("Keith#1234")
    end)

    it("should show '(no BNet link)' when not linked", function()
        local ns = loadAll()

        addFriend(ns, "Blobheal", "Thrall", "PALADIN", "Paladin", "HEALER")

        ns.FriendsViewer:Show()

        local text = ns.FriendsViewer.rows[2].line1:GetText()
        expect(text).toContain("no BNet link")
    end)

    it("should render a section header row above friend rows", function()
        local ns = loadAll()

        addFriend(ns, "A", "Thrall", "WARRIOR", "Warrior", "TANK")
        addFriend(ns, "B", "Thrall", "HUNTER", "Hunter", "DAMAGER")

        ns.FriendsViewer:Show()

        local headerText = ns.FriendsViewer.rows[1].line1:GetText()
        expect(headerText).toContain("OFFLINE")
        expect(headerText).toContain("(2)")
    end)
end)

describe("FriendsViewer: Scrolling", function()
    local function addManyFriends(ns, count)
        for i = 1, count do
            addFriend(ns, "Friend" .. string.format("%02d", i), "Thrall", "WARRIOR", "Warrior", "TANK")
        end
    end

    it("should track scrollOffset starting at 0", function()
        local ns = loadAll()
        addManyFriends(ns, 20)

        ns.FriendsViewer:Show()

        expect(ns.FriendsViewer.scrollOffset).toBe(0)
    end)

    it("should scroll down when Scroll(+1) called", function()
        local ns = loadAll()
        addManyFriends(ns, 20)

        ns.FriendsViewer:Show()
        ns.FriendsViewer:Scroll(1)

        expect(ns.FriendsViewer.scrollOffset).toBe(1)
    end)

    it("should clamp scrollOffset to maxOffset", function()
        local ns = loadAll()
        addManyFriends(ns, 20)
        -- 20 friends + 1 OFFLINE header = 21 renderList entries.
        -- 12 visible -> max offset 9.

        ns.FriendsViewer:Show()
        ns.FriendsViewer:Scroll(100)

        expect(ns.FriendsViewer.scrollOffset).toBe(9)
    end)

    it("should not scroll past 0", function()
        local ns = loadAll()
        addManyFriends(ns, 20)

        ns.FriendsViewer:Show()
        ns.FriendsViewer:Scroll(-10)

        expect(ns.FriendsViewer.scrollOffset).toBe(0)
    end)

    it("should not scroll when total <= visibleRows", function()
        local ns = loadAll()
        addManyFriends(ns, 5)

        ns.FriendsViewer:Show()
        ns.FriendsViewer:Scroll(5)

        expect(ns.FriendsViewer.scrollOffset).toBe(0)
    end)

    it("should reset scrollOffset on RefreshData", function()
        local ns = loadAll()
        addManyFriends(ns, 20)

        ns.FriendsViewer:Show()
        ns.FriendsViewer:Scroll(5)
        expect(ns.FriendsViewer.scrollOffset).toBe(5)

        ns.FriendsViewer:RefreshData()
        expect(ns.FriendsViewer.scrollOffset).toBe(0)
    end)

    it("should display row content from scrolled offset", function()
        local ns = loadAll()
        addManyFriends(ns, 20)

        ns.FriendsViewer:Show()
        local row1Before = ns.FriendsViewer.rows[1].line1:GetText()

        ns.FriendsViewer:Scroll(3)
        local row1After = ns.FriendsViewer.rows[1].line1:GetText()

        expect(row1Before == row1After).toBe(false)
    end)

    it("should show scroll hint in footer when scrollable", function()
        local ns = loadAll()
        addManyFriends(ns, 20)

        ns.FriendsViewer:Show()

        local footerText = ns.FriendsViewer.footerText:GetText()
        expect(footerText).toContain("scroll for more")
    end)

    it("should not show scroll hint in footer when all entries fit", function()
        local ns = loadAll()
        addManyFriends(ns, 5)

        ns.FriendsViewer:Show()

        local footerText = ns.FriendsViewer.footerText:GetText()
        expect(footerText:find("scroll for more") == nil).toBe(true)
    end)
end)

-- ============================================================
-- Context menu
-- ============================================================
local function findMenuItem(menu, label)
    for _, item in ipairs(menu) do
        if item.text == label then return item end
    end
    return nil
end

describe("FriendsViewer: Context menu", function()
    it("should build a menu with core actions for a friend", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER", "Ara-Kara", 12, 100, "Keith#1234")
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local menu = ns.FriendsViewer:BuildContextMenu(entry)

        expect(findMenuItem(menu, "Whisper")).toNotBeNil()
        expect(findMenuItem(menu, "Invite to Party")).toNotBeNil()
        expect(findMenuItem(menu, "Copy BattleTag")).toNotBeNil()
        -- Remove item is color-coded, so we check by presence of any
        -- entry whose text contains "Remove"
        local hasRemove = false
        for _, item in ipairs(menu) do
            if item.text and item.text:find("Remove") then hasRemove = true end
        end
        expect(hasRemove).toBe(true)
    end)

    it("should show the friend's display name as a title", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local menu = ns.FriendsViewer:BuildContextMenu(entry)

        expect(menu[1].text).toBe("Blob")
        expect(menu[1].isTitle).toBe(true)
    end)

    it("should disable Invite to Party when friend is offline", function()
        local ns = loadAll()
        addFriend(ns, "Offline", "Thrall", "WARRIOR", "Warrior", "TANK")
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local menu = ns.FriendsViewer:BuildContextMenu(entry)

        local invite = findMenuItem(menu, "Invite to Party")
        expect(invite.disabled).toBe(true)
    end)

    it("should enable Invite to Party when friend is online", function()
        local ns = loadAll()
        addFriend(ns, "Online", "Thrall", "HUNTER", "Hunter", "DAMAGER", nil, nil, 100, "On#1234")
        _G._mockBNetFriends = {
            {
                bnetAccountID = 100,
                battleTag = "On#1234",
                isOnline = true,
                gameAccounts = {
                    { characterName = "Online", realmName = "Thrall", className = "HUNTER", areaName = "Valdrakken" },
                },
            },
        }
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local menu = ns.FriendsViewer:BuildContextMenu(entry)

        local invite = findMenuItem(menu, "Invite to Party")
        expect(invite.disabled).toBe(false)
    end)

    it("should disable Copy BattleTag when no BNet link is stored", function()
        local ns = loadAll()
        addFriend(ns, "Unlinked", "Thrall", "MAGE", "Mage", "DAMAGER")
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local menu = ns.FriendsViewer:BuildContextMenu(entry)

        local copy = findMenuItem(menu, "Copy BattleTag")
        expect(copy.disabled).toBe(true)
    end)

    it("should enable Copy BattleTag when BNet link is stored", function()
        local ns = loadAll()
        addFriend(ns, "Linked", "Thrall", "MAGE", "Mage", "DAMAGER", nil, nil, 100, "Keith#1234")
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local menu = ns.FriendsViewer:BuildContextMenu(entry)

        local copy = findMenuItem(menu, "Copy BattleTag")
        expect(copy.disabled).toBeFalsy()
    end)

    it("should label the note action 'Add Note' when none exists", function()
        local ns = loadAll()
        addFriend(ns, "New", "Thrall", "PRIEST", "Priest", "HEALER")
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local menu = ns.FriendsViewer:BuildContextMenu(entry)

        expect(findMenuItem(menu, "Add Note")).toNotBeNil()
        expect(findMenuItem(menu, "Edit Note")).toBeNil()
    end)

    it("should label the note action 'Edit Note' when one already exists", function()
        local ns = loadAll()
        local nr = addFriend(ns, "Noted", "Thrall", "PRIEST", "Priest", "HEALER")
        ns.Data:SetNote(nr, "great tank")
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local menu = ns.FriendsViewer:BuildContextMenu(entry)

        expect(findMenuItem(menu, "Edit Note")).toNotBeNil()
        expect(findMenuItem(menu, "Add Note")).toBeNil()
    end)
end)

describe("Data: SetNote", function()
    it("should store a note on a tracked friend", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        local ok = ns.Data:SetNote("blob-thrall", "best healer")
        expect(ok).toBe(true)
        expect(ns.Data:GetFriend("blob-thrall").notes).toBe("best healer")
    end)

    it("should return false for an unknown friend", function()
        local ns = loadAll()
        expect(ns.Data:SetNote("ghost-nowhere", "x")).toBe(false)
    end)
end)

describe("FriendsViewer: Hover tooltip", function()
    local function findLineMatching(lines, substr)
        for _, line in ipairs(lines) do
            local text = line.left or ""
            if line.right then text = text .. " " .. line.right end
            if text:find(substr, 1, true) then return line end
        end
        return nil
    end

    it("should include the character name in a tooltip header line", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local lines = ns.FriendsViewer:BuildTooltipLines(entry)

        expect(findLineMatching(lines, "Blob")).toNotBeNil()
    end)

    it("should list every key run from keyHistory", function()
        local ns = loadAll()
        local nr = addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER", "Ara-Kara", 12)
        -- addFriend seeds +12 Ara-Kara; add two more runs via UpdateFriendKeyStats
        ns.Data:UpdateFriendKeyStats(nr, "Stonevault", 15, true)
        ns.Data:UpdateFriendKeyStats(nr, "Dawnbreaker", 13, false)
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local lines = ns.FriendsViewer:BuildTooltipLines(entry)

        expect(findLineMatching(lines, "+12")).toNotBeNil()
        expect(findLineMatching(lines, "Ara-Kara")).toNotBeNil()
        expect(findLineMatching(lines, "+15")).toNotBeNil()
        expect(findLineMatching(lines, "Stonevault")).toNotBeNil()
        expect(findLineMatching(lines, "+13")).toNotBeNil()
        expect(findLineMatching(lines, "Dawnbreaker")).toNotBeNil()
    end)

    it("should mark timed runs green and depleted runs red", function()
        local ns = loadAll()
        local nr = addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        ns.Data:UpdateFriendKeyStats(nr, "Stonevault", 15, true)
        ns.Data:UpdateFriendKeyStats(nr, "Dawnbreaker", 13, false)
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local lines = ns.FriendsViewer:BuildTooltipLines(entry)

        expect(findLineMatching(lines, "Timed")).toNotBeNil()
        expect(findLineMatching(lines, "Depleted")).toNotBeNil()
    end)

    it("should include the friend's note when one is set", function()
        local ns = loadAll()
        local nr = addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        ns.Data:SetNote(nr, "great healer")
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local lines = ns.FriendsViewer:BuildTooltipLines(entry)

        expect(findLineMatching(lines, "great healer")).toNotBeNil()
    end)

    it("should fall back to aggregate stats for legacy entries with no keyHistory", function()
        local ns = loadAll()
        local nr = addFriend(ns, "Legacy", "Thrall", "WARRIOR", "Warrior", "TANK")
        -- Simulate an old DB entry that predates keyHistory
        local friend = ns.Data:GetFriend(nr)
        friend.keyHistory = nil
        friend.keysCompleted = 7
        friend.highestKeyLevel = 18
        friend.highestKeyDungeon = "Stonevault"
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        local lines = ns.FriendsViewer:BuildTooltipLines(entry)

        expect(findLineMatching(lines, "7")).toNotBeNil()
        expect(findLineMatching(lines, "Stonevault")).toNotBeNil()
    end)

    it("should push lines into GameTooltip via ShowHoverTooltip", function()
        local ns = loadAll()
        local nr = addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER", "Ara-Kara", 12)
        ns.FriendsViewer:Show()

        local entry = ns.FriendsViewer:GetDisplayList()[1]
        GameTooltip._tooltipLines = nil
        ns.FriendsViewer:ShowHoverTooltip(entry, ns.FriendsViewer.rows[1].row)

        expect(GameTooltip._tooltipOwner).toNotBeNil()
        expect(GameTooltip._tooltipLines).toNotBeNil()
        expect(#GameTooltip._tooltipLines > 0).toBe(true)
    end)

    it("should not render a tooltip for header rows", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        ns.FriendsViewer:Show()

        GameTooltip._tooltipLines = nil
        local headerEntry = ns.FriendsViewer.renderList[1]
        expect(headerEntry._isHeader).toBe(true)
        ns.FriendsViewer:ShowHoverTooltip(headerEntry, ns.FriendsViewer.rows[1].row)

        expect(GameTooltip._tooltipLines).toBeNil()
    end)
end)

describe("Data: keyHistory tracking", function()
    it("should seed keyHistory on AddFriend with the first run", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER", "Ara-Kara", 12)
        local friend = ns.Data:GetFriend("blob-thrall")

        expect(friend.keyHistory).toNotBeNil()
        expect(#friend.keyHistory).toBe(1)
        expect(friend.keyHistory[1].dungeon).toBe("Ara-Kara")
        expect(friend.keyHistory[1].level).toBe(12)
    end)

    it("should append to keyHistory on UpdateFriendKeyStats", function()
        local ns = loadAll()
        local nr = addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER", "Ara-Kara", 12)
        ns.Data:UpdateFriendKeyStats(nr, "Stonevault", 15, true)
        ns.Data:UpdateFriendKeyStats(nr, "Dawnbreaker", 13, false)

        local friend = ns.Data:GetFriend(nr)
        expect(#friend.keyHistory).toBe(3)
        expect(friend.keyHistory[2].dungeon).toBe("Stonevault")
        expect(friend.keyHistory[2].level).toBe(15)
        expect(friend.keyHistory[2].onTime).toBe(true)
        expect(friend.keyHistory[3].onTime).toBe(false)
    end)

    it("should lazily create keyHistory on legacy DB entries", function()
        local ns = loadAll()
        local nr = addFriend(ns, "Legacy", "Thrall", "WARRIOR", "Warrior", "TANK")
        local friend = ns.Data:GetFriend(nr)
        friend.keyHistory = nil

        ns.Data:UpdateFriendKeyStats(nr, "Stonevault", 15, true)

        expect(friend.keyHistory).toNotBeNil()
        expect(#friend.keyHistory).toBe(1)
        expect(friend.keyHistory[1].dungeon).toBe("Stonevault")
    end)
end)

describe("FriendsViewer: Relative times", function()
    it("should show a relative 'met' time on line3 instead of an absolute date", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER", "Ara-Kara", 12)

        -- Backdate so the relative formatter produces something
        -- distinguishable from "0s ago"
        local friend = ns.Data:GetFriend("blob-thrall")
        friend.addedTimestamp = time() - (3 * 86400)  -- 3 days ago

        ns.FriendsViewer:Show()

        local line3 = ns.FriendsViewer.rows[2].line3:GetText()
        expect(line3).toContain("Met:")
        expect(line3).toContain("d ago")
        -- The old format was "YYYY-MM-DD"; make sure we're not using it
        expect(line3:find("%d%d%d%d%-%d%d%-%d%d") == nil).toBe(true)
    end)

    it("should show relative 'last seen' on offline friends", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")

        local friend = ns.Data:GetFriend("blob-thrall")
        friend.lastSeenTimestamp = time() - (2 * 3600)  -- 2 hours ago

        ns.FriendsViewer:Show()

        local line2 = ns.FriendsViewer.rows[2].line2:GetText()
        expect(line2).toContain("Offline")
        expect(line2).toContain("last seen")
        expect(line2).toContain("h ago")
    end)
end)

describe("FriendsViewer: Inline remove button", function()
    it("should create a remove button per row", function()
        local ns = loadAll()
        ns.FriendsViewer:Create()

        for i = 1, ns.FriendsViewer.visibleRows do
            expect(ns.FriendsViewer.rows[i].removeBtn).toNotBeNil()
        end
    end)

    it("should start the remove button hidden", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        ns.FriendsViewer:Show()

        expect(ns.FriendsViewer.rows[2].removeBtn:IsShown()).toBe(false)
    end)

    it("should show the remove button when the row is hovered", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        ns.FriendsViewer:Show()

        local row = ns.FriendsViewer.rows[2].row
        local onEnter = row:GetScript("OnEnter")
        onEnter(row)

        expect(ns.FriendsViewer.rows[2].removeBtn:IsShown()).toBe(true)
    end)

    it("should hide the remove button when the row loses hover", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        ns.FriendsViewer:Show()

        local row = ns.FriendsViewer.rows[2].row
        local onEnter = row:GetScript("OnEnter")
        local onLeave = row:GetScript("OnLeave")
        onEnter(row)
        expect(ns.FriendsViewer.rows[2].removeBtn:IsShown()).toBe(true)

        onLeave(row)
        expect(ns.FriendsViewer.rows[2].removeBtn:IsShown()).toBe(false)
    end)

    it("should not show a remove button when hovering a header row", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        ns.FriendsViewer:Show()

        -- row 1 is the OFFLINE header
        local headerRow = ns.FriendsViewer.rows[1].row
        local onEnter = headerRow:GetScript("OnEnter")
        onEnter(headerRow)

        expect(ns.FriendsViewer.rows[1].removeBtn:IsShown()).toBe(false)
    end)

    it("should trigger the remove confirmation popup on click", function()
        local ns = loadAll()
        addFriend(ns, "Blob", "Thrall", "PALADIN", "Paladin", "HEALER")
        ns.FriendsViewer:Show()

        -- Stub StaticPopup_Show so we can see what got called
        local captured = nil
        _G.StaticPopup_Show = function(dialog, text, _, data)
            captured = { dialog = dialog, text = text, data = data }
        end

        -- Stamp _currentEntry by running UpdateRows (already done via Show)
        local btn = ns.FriendsViewer.rows[2].removeBtn
        local onClick = btn:GetScript("OnClick")
        onClick(btn)

        expect(captured).toNotBeNil()
        expect(captured.dialog).toBe("BETTERFRIENDS_REMOVE_FRIEND")
        expect(captured.data).toBe("blob-thrall")
    end)
end)

describe("Utils: GetClassIcon", function()
    it("should return atlas markup for a known class token", function()
        local ns = loadAll()
        local markup = ns.Utils.GetClassIcon("PALADIN")
        expect(markup).toContain("classicon-paladin")
    end)

    it("should return empty string for nil or empty class token", function()
        local ns = loadAll()
        expect(ns.Utils.GetClassIcon(nil)).toBe("")
        expect(ns.Utils.GetClassIcon("")).toBe("")
    end)
end)

exitWithResults()
