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
    -- Seed keyHistory with the first run so the hover tooltip has
    -- something to show immediately. Subsequent runs are appended by
    -- UpdateFriendKeyStats.
    local initialHistory = {}
    if info.addedDungeon and info.addedKeyLevel then
        table.insert(initialHistory, {
            dungeon = info.addedDungeon,
            level = info.addedKeyLevel,
            onTime = info.addedOnTime,  -- may be nil on older mocks
            timestamp = now,
        })
    end

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
        keyHistory = initialHistory,
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

function ns.Data:UpdateFriendKeyStats(nameRealm, dungeonName, keyLevel, onTime)
    local friend = BetterFriendsDB.friends[nameRealm]
    if not friend then return end

    local now = time()
    friend.keysCompleted = friend.keysCompleted + 1
    friend.lastSeenTimestamp = now

    if keyLevel > friend.highestKeyLevel then
        friend.highestKeyLevel = keyLevel
        friend.highestKeyDungeon = dungeonName
    end

    -- Append to keyHistory for the hover tooltip. Older DB entries may not
    -- have this field yet (schema upgrade), so initialize it lazily.
    if not friend.keyHistory then
        friend.keyHistory = {}
    end
    table.insert(friend.keyHistory, {
        dungeon = dungeonName,
        level = keyLevel,
        onTime = onTime,
        timestamp = now,
    })
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

function ns.Data:SetNote(nameRealm, note)
    local friend = BetterFriendsDB.friends[nameRealm]
    if not friend then return false end
    friend.notes = note or ""
    return true
end

-- Return the set of tracked nameRealms that share the same bnetAccountID
-- as `nameRealm`, including nameRealm itself. If the friend has no BNet
-- link, returns just { nameRealm }. The result is a plain array so
-- callers can ipairs over it; order is stable and primary-first (the
-- earliest `addedTimestamp` in the cluster).
function ns.Data:GetAltCluster(nameRealm)
    local friend = BetterFriendsDB and BetterFriendsDB.friends and BetterFriendsDB.friends[nameRealm]
    if not friend then return {} end

    if not friend.bnetAccountID then
        return { nameRealm }
    end

    local members = {}
    for nr, f in pairs(BetterFriendsDB.friends) do
        if f.bnetAccountID == friend.bnetAccountID then
            table.insert(members, nr)
        end
    end

    -- Sort by earliest addedTimestamp first (stable primary = first-met).
    table.sort(members, function(a, b)
        local fa = BetterFriendsDB.friends[a]
        local fb = BetterFriendsDB.friends[b]
        return (fa.addedTimestamp or 0) < (fb.addedTimestamp or 0)
    end)
    return members
end

-- The "primary" is the character you met first in the cluster — the one
-- you recognize them by. Returns the input nameRealm if unlinked.
function ns.Data:GetClusterPrimary(nameRealm)
    local cluster = self:GetAltCluster(nameRealm)
    return cluster[1] or nameRealm
end

-- Sum of keysCompleted across every tracked character in the cluster.
function ns.Data:GetClusterKeyTotal(nameRealm)
    local cluster = self:GetAltCluster(nameRealm)
    local total = 0
    for _, nr in ipairs(cluster) do
        local f = BetterFriendsDB.friends[nr]
        if f and f.keysCompleted then
            total = total + f.keysCompleted
        end
    end
    return total
end

-- Given a bnetAccountID (e.g. from a BNet friend list entry), return the
-- tracked nameRealm of the earliest-met character on that account, or nil
-- if none of this BNet's characters are tracked yet. Used by the popup
-- to label a newly-met alt as "alt of <primary>".
function ns.Data:GetPrimaryByBNetAccountID(bnetAccountID)
    if not bnetAccountID then return nil end
    if not (BetterFriendsDB and BetterFriendsDB.friends) then return nil end

    local bestNameRealm, bestTs = nil, nil
    for nr, f in pairs(BetterFriendsDB.friends) do
        if f.bnetAccountID == bnetAccountID then
            local ts = f.addedTimestamp or 0
            if not bestTs or ts < bestTs then
                bestTs = ts
                bestNameRealm = nr
            end
        end
    end
    return bestNameRealm
end
