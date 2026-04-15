local addonName, ns = ...

ns.Data = {}

local DEFAULTS = {
    schemaVersion = 1,
    friends = {},
    settings = {
        popupEnabled = true,
        popupAutoDismissSeconds = 60,
        minimapButtonShown = true,
        minimapButtonPosition = 220,
        soundOnPopup = true,
    },
}

function ns.Data:Init()
    if not BetterFriendsDB then
        BetterFriendsDB = {}
    end

    local db = BetterFriendsDB
    db.schemaVersion = db.schemaVersion or DEFAULTS.schemaVersion
    db.friends = db.friends or {}

    -- Merge default settings without overwriting existing values
    if not db.settings then
        db.settings = {}
    end
    for k, v in pairs(DEFAULTS.settings) do
        if db.settings[k] == nil then
            db.settings[k] = v
        end
    end
end

function ns.Data:AddFriend(nameRealm, info)
    if BetterFriendsDB.friends[nameRealm] then
        return -- Don't overwrite existing friends
    end

    local now = time()
    BetterFriendsDB.friends[nameRealm] = {
        characterName = info.characterName,
        realm = info.realm,
        className = info.className,
        classDisplayName = info.classDisplayName,
        role = info.role,
        addedTimestamp = now,
        addedDungeon = info.addedDungeon,
        addedKeyLevel = info.addedKeyLevel,
        keysCompleted = 1,
        highestKeyLevel = info.addedKeyLevel,
        highestKeyDungeon = info.addedDungeon,
        lastSeenTimestamp = now,
        bnetAccountID = nil,
        bnetTag = nil,
        notes = "",
    }
end

function ns.Data:GetFriend(nameRealm)
    return BetterFriendsDB.friends[nameRealm]
end

function ns.Data:IsFriend(nameRealm)
    return BetterFriendsDB.friends[nameRealm] ~= nil
end

function ns.Data:UpdateFriendKeyStats(nameRealm, dungeonName, keyLevel)
    local friend = BetterFriendsDB.friends[nameRealm]
    if not friend then return end

    friend.keysCompleted = friend.keysCompleted + 1
    friend.lastSeenTimestamp = time()

    if keyLevel > friend.highestKeyLevel then
        friend.highestKeyLevel = keyLevel
        friend.highestKeyDungeon = dungeonName
    end
end

function ns.Data:GetAllFriends()
    return BetterFriendsDB.friends
end

function ns.Data:GetSettings()
    return BetterFriendsDB.settings
end

function ns.Data:SetBNetLink(nameRealm, accountID, battleTag)
    local friend = BetterFriendsDB.friends[nameRealm]
    if not friend then return end

    friend.bnetAccountID = accountID
    friend.bnetTag = battleTag
end

function ns.Data:ClearBNetLink(nameRealm)
    local friend = BetterFriendsDB.friends[nameRealm]
    if not friend then return end

    friend.bnetAccountID = nil
    friend.bnetTag = nil
end

function ns.Data:RemoveFriend(nameRealm)
    if not BetterFriendsDB.friends[nameRealm] then
        return false
    end
    BetterFriendsDB.friends[nameRealm] = nil
    return true
end
