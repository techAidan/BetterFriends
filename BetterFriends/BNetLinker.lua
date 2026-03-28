local addonName, ns = ...

ns.BNetLinker = {}
ns.BNetLinker.bnetSnapshot = {}
ns.BNetLinker.pendingInvites = {}

function ns.BNetLinker:SnapshotBNetFriends()
    self.bnetSnapshot = {}
    local _, numTotal = BNGetNumFriends()
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
    local _, numTotal = BNGetNumFriends()
    for i = 1, numTotal do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.bnetAccountID == accountID then
            return i
        end
    end
    return nil
end

function ns.BNetLinker:ProcessNewFriends()
    local _, numTotal = BNGetNumFriends()
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
        isOnline = info.isOnline,
        currentCharacter = nil,
        currentRealm = nil,
        currentClass = nil,
        zone = nil,
    }

    if info.gameAccounts and #info.gameAccounts > 0 then
        local ga = info.gameAccounts[1]
        status.currentCharacter = ga.characterName
        status.currentRealm = ga.realmName
        status.currentClass = ga.className
        status.zone = ga.areaName
    end

    return status
end

-- Register for BNet friend list changes
ns:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED", ns.BNetLinker, function(self, event)
    ns.BNetLinker:ProcessNewFriends()
end)

-- Slash command for manual linking
ns.SlashHandlers["link"] = function(msg)
    -- msg is the full message like "link CharName-Realm Keith#1234"
    -- Strip the "link " prefix to get args
    local args = msg:match("^%s*link%s+(.+)$")
    if not args then
        print("|cFF00CCFFBetterFriends:|r Usage: /bf link CharName-Realm BattleTag#1234")
        return
    end

    -- Parse character name-realm and btag
    local nameRealm, btag = args:match("^(%S+)%s+(%S+)$")
    if not nameRealm or not btag then
        print("|cFF00CCFFBetterFriends:|r Usage: /bf link CharName-Realm BattleTag#1234")
        return
    end

    -- Normalize the nameRealm
    local name, realm = nameRealm:match("^([^%-]+)%-(.+)$")
    if not name or not realm then
        print("|cFF00CCFFBetterFriends:|r Invalid character name format. Use: CharName-Realm")
        return
    end

    local normalized = ns.Utils.NormalizeNameRealm(name, realm)
    local friend = ns.Data:GetFriend(normalized)
    if not friend then
        print("|cFF00CCFFBetterFriends:|r " .. normalized .. " is not in your friends list.")
        return
    end

    -- Find the bnet account ID by btag
    local _, numTotal = BNGetNumFriends()
    local foundAccountID = nil
    for i = 1, numTotal do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and info.battleTag == btag then
            foundAccountID = info.bnetAccountID
            break
        end
    end

    if foundAccountID then
        ns.Data:SetBNetLink(normalized, foundAccountID, btag)
        print("|cFF00CCFFBetterFriends:|r Linked " .. normalized .. " to " .. btag)
    else
        -- Link with just the btag, no account ID
        ns.Data:SetBNetLink(normalized, nil, btag)
        print("|cFF00CCFFBetterFriends:|r Linked " .. normalized .. " to " .. btag .. " (BNet account not found in friends list)")
    end
end
