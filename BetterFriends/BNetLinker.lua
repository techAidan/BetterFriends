local addonName, ns = ...

ns.BNetLinker = {}
ns.BNetLinker.bnetSnapshot = {}
ns.BNetLinker.pendingInvites = {}

-- Enumerate every online WoW game account on the BNet friend list,
-- calling callback(info, ga) for each. Handles the three API shapes
-- documented in FriendsViewer.lua: info.gameAccountInfo (modern),
-- C_BattleNet.GetFriendNumGameAccounts/GetFriendGameAccountInfo (multi),
-- and info.gameAccounts (legacy/test).
local function isWoWGameAccount(ga)
    return ga and (
        ga.clientProgram == nil
        or ga.clientProgram == "WoW"
        or (BNET_CLIENT_WOW and ga.clientProgram == BNET_CLIENT_WOW)
    )
end

-- Check both possible online-status locations. Modern client puts the live
-- status under info.gameAccountInfo.isOnline; the top-level info.isOnline
-- field may not be populated.
local function isAccountOnline(info)
    if not info then return false end
    if info.isOnline then return true end
    if info.gameAccountInfo then
        if info.gameAccountInfo.isOnline then return true end
        if info.gameAccountInfo.clientProgram and info.gameAccountInfo.clientProgram ~= "" then
            return true
        end
    end
    return false
end
ns.BNetLinker._isAccountOnline = isAccountOnline  -- exported for FriendsViewer

function ns.BNetLinker:ForEachWoWGameAccount(callback)
    if not BNGetNumFriends then return end
    local numTotal = BNGetNumFriends()

    for i = 1, numTotal do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and isAccountOnline(info) then
            local seen = false

            if info.gameAccountInfo and isWoWGameAccount(info.gameAccountInfo)
                and info.gameAccountInfo.characterName
                and info.gameAccountInfo.characterName ~= "" then
                callback(info, info.gameAccountInfo)
                seen = true
            end

            if C_BattleNet.GetFriendNumGameAccounts then
                local numGA = C_BattleNet.GetFriendNumGameAccounts(i) or 0
                for j = 1, numGA do
                    local ga = C_BattleNet.GetFriendGameAccountInfo(i, j)
                    if ga and isWoWGameAccount(ga) and ga.characterName and ga.characterName ~= "" then
                        callback(info, ga)
                        seen = true
                    end
                end
            end

            if not seen and info.gameAccounts then
                for _, ga in ipairs(info.gameAccounts) do
                    if isWoWGameAccount(ga) and ga.characterName and ga.characterName ~= "" then
                        callback(info, ga)
                    end
                end
            end
        end
    end
end

function ns.BNetLinker:SnapshotBNetFriends()
    self.bnetSnapshot = {}
    local numTotal = BNGetNumFriends()
    for i = 1, numTotal do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.bnetAccountID then
            self.bnetSnapshot[info.bnetAccountID] = true
        end
    end
end

function ns.BNetLinker:AddPendingInvite(nameRealm)
    self.pendingInvites[nameRealm] = { timestamp = time() }
end

function ns.BNetLinker:GetPendingInvites()
    return self.pendingInvites
end

function ns.BNetLinker:FindBNetIndexByAccountID(accountID)
    local numTotal = BNGetNumFriends()
    for i = 1, numTotal do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.bnetAccountID == accountID then
            return i
        end
    end
    return nil
end

function ns.BNetLinker:ProcessNewFriends()
    local numTotal = BNGetNumFriends()
    local currentFriends = {}

    -- Build current friends set and collect new ones
    local newFriends = {}
    for i = 1, numTotal do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.bnetAccountID then
            currentFriends[info.bnetAccountID] = true
            if not self.bnetSnapshot[info.bnetAccountID] then
                table.insert(newFriends, info)
            end
        end
    end

    -- Check new friends against pending invites
    for _, info in ipairs(newFriends) do
        local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts(self:FindBNetIndexByAccountID(info.bnetAccountID))
        local friendIndex = self:FindBNetIndexByAccountID(info.bnetAccountID)

        -- Check game accounts for character matches
        if info.gameAccounts then
            for _, gameAccount in ipairs(info.gameAccounts) do
                if gameAccount.characterName and gameAccount.realmName then
                    local nameRealm = ns.Utils.NormalizeNameRealm(gameAccount.characterName, gameAccount.realmName)
                    if self.pendingInvites[nameRealm] then
                        ns.Data:SetBNetLink(nameRealm, info.bnetAccountID, info.battleTag)
                        self.pendingInvites[nameRealm] = nil
                    end
                end
            end
        end
    end

    -- Update snapshot to current state
    self.bnetSnapshot = currentFriends
end

-- Walk the whole BNet friend list and build a nameRealm -> { accountID,
-- battleTag } lookup. Unlike ForEachWoWGameAccount, this includes
-- *offline* accounts too — the goal here is to harvest character/realm
-- info that Blizzard still reports even when the friend isn't logged in,
-- so auto-linking works at /reload time before they come online.
function ns.BNetLinker:BuildCharacterLookup()
    local map = {}
    if not BNGetNumFriends then return map end
    local numTotal = BNGetNumFriends()

    local function ingestGameAccount(info, ga)
        if not (ga and isWoWGameAccount(ga) and ga.characterName and ga.characterName ~= "") then
            return
        end
        local realm = ga.realmName
        if not realm or realm == "" then return end
        local nr = ns.Utils.NormalizeNameRealm(ga.characterName, realm)
        map[nr] = { accountID = info.bnetAccountID, battleTag = info.battleTag }
    end

    for i = 1, numTotal do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.bnetAccountID then
            if info.gameAccountInfo then
                ingestGameAccount(info, info.gameAccountInfo)
            end
            if C_BattleNet.GetFriendNumGameAccounts then
                local numGA = C_BattleNet.GetFriendNumGameAccounts(i) or 0
                for j = 1, numGA do
                    ingestGameAccount(info, C_BattleNet.GetFriendGameAccountInfo(i, j))
                end
            end
            if info.gameAccounts then
                for _, ga in ipairs(info.gameAccounts) do
                    ingestGameAccount(info, ga)
                end
            end
        end
    end
    return map
end

-- Link any tracked friend that has no bnetAccountID but whose
-- nameRealm matches a character on someone's BNet account. Returns the
-- number of new links created. Safe to call repeatedly — already-linked
-- friends are skipped.
function ns.BNetLinker:AutoLinkByScan()
    local map = self:BuildCharacterLookup()
    local linked = 0
    for nr, friend in pairs(ns.Data:GetAllFriends()) do
        if not friend.bnetAccountID then
            local match = map[nr]
            if match and match.accountID then
                ns.Data:SetBNetLink(nr, match.accountID, match.battleTag)
                linked = linked + 1
                if ns.DebugLog then
                    ns.DebugLog:Log("BNetLinker", "Auto-linked "
                        .. nr .. " -> " .. tostring(match.battleTag))
                end
            end
        end
    end
    return linked
end

function ns.BNetLinker:GetLiveStatus(nameRealm)
    local friend = ns.Data:GetFriend(nameRealm)
    if not friend or not friend.bnetAccountID then
        return nil
    end

    local index = self:FindBNetIndexByAccountID(friend.bnetAccountID)
    if not index then return nil end

    local info = C_BattleNet.GetFriendAccountInfo(index)
    if not info then return nil end

    local status = {
        isOnline = isAccountOnline(info),
        currentCharacter = nil,
        currentRealm = nil,
        currentClass = nil,
        zone = nil,
    }

    -- Pick the first WoW character we can find across the three API
    -- shapes, preferring modern fields. Without this, a BNet friend
    -- online on retail-only data (empty `gameAccounts`) reports
    -- currentCharacter = nil and the "(on X)" viewer annotation never
    -- shows.
    local function adopt(ga)
        if not (ga and isWoWGameAccount(ga) and ga.characterName and ga.characterName ~= "") then
            return false
        end
        status.currentCharacter = ga.characterName
        status.currentRealm = ga.realmName
        status.currentClass = ga.className
        status.zone = ga.areaName
        return true
    end

    if info.gameAccountInfo and adopt(info.gameAccountInfo) then
        -- done
    elseif C_BattleNet.GetFriendNumGameAccounts then
        local numGA = C_BattleNet.GetFriendNumGameAccounts(index) or 0
        for j = 1, numGA do
            if adopt(C_BattleNet.GetFriendGameAccountInfo(index, j)) then break end
        end
    end

    if not status.currentCharacter and info.gameAccounts then
        for _, ga in ipairs(info.gameAccounts) do
            if adopt(ga) then break end
        end
    end

    return status
end

-- Register for BNet friend list changes
ns:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED", ns.BNetLinker, function(self, event)
    ns.BNetLinker:ProcessNewFriends()
    ns.BNetLinker:AutoLinkByScan()
end)

-- When a BNet friend's account info changes (logs in/out, switches
-- character, etc.), their gameAccountInfo gets populated and may reveal
-- a character match that was invisible before. Rescan so previously-met
-- characters link up automatically.
ns:RegisterEvent("BN_FRIEND_INFO_CHANGED", ns.BNetLinker, function(self, event)
    ns.BNetLinker:AutoLinkByScan()
end)

-- At login, do one scan once the friend list has had time to populate.
-- We don't know exactly when that is, so run it on PLAYER_LOGIN *and*
-- lean on the two BNet events above to catch late-arriving data.
ns:RegisterEvent("PLAYER_LOGIN", ns.BNetLinker, function(self, event)
    ns.BNetLinker:AutoLinkByScan()
end)

-- Slash command for manual linking
-- Usage:
--   /btf link CharName-Realm BattleTag#1234   (explicit btag)
--   /btf link CharName-Realm                  (auto-find matching online BNet friend)
--   /btf link CharName                        (auto-find by character name only)
ns.SlashHandlers["link"] = function(msg)
    local args = msg:match("^%s*link%s+(.+)$")
    if not args then
        print("|cFF00CCFFBetterFriends:|r Usage: /btf link CharName[-Realm] [BattleTag#1234]")
        return
    end

    -- Parse: either "<nameRealm> <btag>" or just "<nameRealm>"
    local nameRealmArg, btagArg = args:match("^(%S+)%s+(%S+)$")
    if not nameRealmArg then
        nameRealmArg = args:match("^(%S+)$")
    end
    if not nameRealmArg then
        print("|cFF00CCFFBetterFriends:|r Usage: /btf link CharName[-Realm] [BattleTag#1234]")
        return
    end

    -- Allow either "Char-Realm" or just "Char" — fall back to player realm
    local name, realm = nameRealmArg:match("^([^%-]+)%-(.+)$")
    if not name then
        name = nameRealmArg
        realm = nil
    end

    -- Find the tracked friend. Try exact normalized first, then any
    -- friend with a matching character name.
    local friend, normalized
    if realm then
        normalized = ns.Utils.NormalizeNameRealm(name, realm)
        friend = ns.Data:GetFriend(normalized)
    end
    if not friend then
        for nr, f in pairs(ns.Data:GetAllFriends()) do
            if f.characterName and string.lower(f.characterName) == string.lower(name) then
                friend = f
                normalized = nr
                break
            end
        end
    end
    if not friend then
        print("|cFF00CCFFBetterFriends:|r " .. nameRealmArg .. " is not in your friends list.")
        return
    end

    -- Resolve the BattleTag — either from explicit arg or by auto-finding
    -- a matching online BNet character.
    local btag = btagArg
    local foundAccountID = nil
    local numTotal = BNGetNumFriends()

    if btag then
        for i = 1, numTotal do
            local info = C_BattleNet.GetFriendAccountInfo(i)
            if info and info.battleTag == btag then
                foundAccountID = info.bnetAccountID
                break
            end
        end
    else
        -- Auto-find: scan online BNet WoW characters for one with this name
        local matches = {}
        local target = string.lower(friend.characterName or "")
        ns.BNetLinker:ForEachWoWGameAccount(function(info, ga)
            if string.lower(ga.characterName) == target then
                table.insert(matches, { info = info, ga = ga })
            end
        end)
        if #matches == 0 then
            print("|cFF00CCFFBetterFriends:|r No BNet friend found with character '" .. (friend.characterName or "?") .. "'. Try /btf bnetscan to list candidates.")
            return
        elseif #matches > 1 then
            print("|cFF00CCFFBetterFriends:|r Multiple BNet friends have a character named '" .. friend.characterName .. "':")
            for _, m in ipairs(matches) do
                print("  " .. m.info.battleTag .. " - " .. m.ga.characterName .. "-" .. (m.ga.realmName or "?"))
            end
            print("Specify which one: /btf link " .. nameRealmArg .. " <BattleTag#1234>")
            return
        end
        foundAccountID = matches[1].info.bnetAccountID
        btag = matches[1].info.battleTag
    end

    if foundAccountID then
        ns.Data:SetBNetLink(normalized, foundAccountID, btag)
        print("|cFF00CCFFBetterFriends:|r Linked " .. normalized .. " to " .. btag)
    else
        ns.Data:SetBNetLink(normalized, nil, btag)
        print("|cFF00CCFFBetterFriends:|r Linked " .. normalized .. " to " .. btag .. " (BNet account not found in friends list)")
    end
end

-- Diagnostic: dump all online BNet WoW characters and all tracked friends
-- so the user can see why a fuzzy match isn't catching.
ns.SlashHandlers["bnetscan"] = function(msg)
    print("|cFF00CCFFBetterFriends:|r === BNet character scan ===")
    -- Real WoW returns (numTotal, numOnline). Capture both so we can show
    -- the right value and iterate the full list.
    local numTotal, numOnlineFromAPI = BNGetNumFriends()
    print("Total BNet friends: " .. numTotal
        .. "   (API reports " .. tostring(numOnlineFromAPI) .. " online)")

    -- Verify by walking the list ourselves with the more permissive check
    local onlineCount = 0
    for i = 1, numTotal do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if isAccountOnline(info) then
            onlineCount = onlineCount + 1
        end
    end
    print("Online BNet friends (counted): " .. onlineCount)

    local onlineWoW = 0
    ns.BNetLinker:ForEachWoWGameAccount(function(info, ga)
        onlineWoW = onlineWoW + 1
        local realmStr = ga.realmName or "?"
        local key = string.lower(ga.characterName) .. "-" .. string.lower(realmStr)
        print("  |cFFFFD100" .. (info.battleTag or "?") .. "|r  "
            .. ga.characterName .. "-" .. realmStr
            .. "  |cFF888888[key=" .. key .. "]|r")
    end)
    print("Online WoW characters: " .. onlineWoW)

    -- Diagnostic: if anyone is online but no WoW character was enumerated,
    -- dump raw account info so we can see what fields ARE populated.
    if onlineCount > 0 and onlineWoW == 0 then
        print("|cFFFF4444No WoW characters enumerated. Raw account dump (first 5 online):|r")
        local dumped = 0
        for i = 1, numTotal do
            local info = C_BattleNet.GetFriendAccountInfo(i)
            if isAccountOnline(info) and dumped < 5 then
                dumped = dumped + 1
                print("  #" .. i .. " " .. (info.battleTag or "?")
                    .. "  topIsOnline=" .. tostring(info.isOnline)
                    .. "  hasGameAccountInfo=" .. tostring(info.gameAccountInfo ~= nil)
                    .. "  hasGameAccounts=" .. tostring(info.gameAccounts ~= nil))
                if info.gameAccountInfo then
                    local ga = info.gameAccountInfo
                    print("    gameAccountInfo: clientProgram=" .. tostring(ga.clientProgram)
                        .. " isOnline=" .. tostring(ga.isOnline)
                        .. " character=" .. tostring(ga.characterName)
                        .. " realm=" .. tostring(ga.realmName))
                end
                if C_BattleNet.GetFriendNumGameAccounts then
                    print("    numGameAccounts=" .. tostring(C_BattleNet.GetFriendNumGameAccounts(i)))
                end
            end
        end
    end

    print("--- Tracked friends ---")
    for nameRealm, friend in pairs(ns.Data:GetAllFriends()) do
        local linked = friend.bnetTag
            and ("|cFF00FF00linked: " .. friend.bnetTag .. "|r")
            or "|cFFFF4444no link|r"
        print("  " .. (friend.characterName or "?") .. "-" .. (friend.realm or "?")
            .. "  |cFF888888[key=" .. nameRealm .. "]|r  " .. linked)
    end
    print("Tip: if a tracked friend's [key=...] doesn't match an online character's [key=...], use /btf link CharName to auto-link by name.")
end
