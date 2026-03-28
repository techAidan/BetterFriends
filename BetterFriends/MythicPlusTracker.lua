local addonName, ns = ...

ns.MythicPlusTracker = {}

-- Cache party snapshot when M+ starts
ns:RegisterEvent("CHALLENGE_MODE_START", ns.MythicPlusTracker, function(self, event)
    ns.PartyScanner:CachePartySnapshot()
end)

-- Process M+ completion
ns:RegisterEvent("CHALLENGE_MODE_COMPLETED", ns.MythicPlusTracker, function(self, event)
    local mapChallengeModeID, level, time, onTime = C_ChallengeMode.GetCompletionInfo()
    if not mapChallengeModeID then return end

    local dungeonName = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
    local members = ns.PartyScanner:GetMergedParty()

    -- Update stats for tracked friends
    for _, member in ipairs(members) do
        if ns.Data:IsFriend(member.nameRealm) then
            ns.Data:UpdateFriendKeyStats(member.nameRealm, dungeonName, level)
        end
    end

    -- Store last completion for popup
    ns.lastCompletion = {
        members = members,
        dungeonName = dungeonName,
        keyLevel = level,
        onTime = onTime,
    }

    -- Show popup if available
    if ns.FriendRequestPopup and ns.FriendRequestPopup.Show then
        ns.FriendRequestPopup:Show(ns.lastCompletion)
    end
end)

-- On login, cache party if already in M+
ns:RegisterEvent("PLAYER_LOGIN", ns.MythicPlusTracker, function(self, event)
    if C_ChallengeMode.IsChallengeModeActive() then
        ns.PartyScanner:CachePartySnapshot()
    end
end)
