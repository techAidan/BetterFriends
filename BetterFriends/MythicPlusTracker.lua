local addonName, ns = ...

ns.MythicPlusTracker = {}

local function DebugPrint(...)
    if ns.DebugLog then
        ns.DebugLog:Log("M+", ...)
    else
        print("|cFF00CCFFBetterFriends [M+]:|r", ...)
    end
end

-- Cache party snapshot when M+ starts
ns:RegisterEvent("CHALLENGE_MODE_START", ns.MythicPlusTracker, function(self, event)
    DebugPrint("CHALLENGE_MODE_START fired — caching party")
    ns.PartyScanner:CachePartySnapshot()
end)

-- Also cache on GROUP_ROSTER_UPDATE while in M+ (safety net)
ns:RegisterEvent("GROUP_ROSTER_UPDATE", ns.MythicPlusTracker, function(self, event)
    if C_ChallengeMode.IsChallengeModeActive() then
        ns.PartyScanner:CachePartySnapshot()
    end
end)

-- Process M+ completion
ns:RegisterEvent("CHALLENGE_MODE_COMPLETED", ns.MythicPlusTracker, function(self, event)
    DebugPrint("CHALLENGE_MODE_COMPLETED fired!")

    local ok, err = pcall(function()
        -- WoW 12.0 (Midnight) renamed GetCompletionInfo -> GetChallengeCompletionInfo
        -- and changed it to return a single struct instead of multiple values
        local completionInfo
        if C_ChallengeMode.GetChallengeCompletionInfo then
            completionInfo = C_ChallengeMode.GetChallengeCompletionInfo()
        elseif C_ChallengeMode.GetCompletionInfo then
            -- Fallback for older clients (11.x and below)
            local mapID, lvl, tm, ot = C_ChallengeMode.GetCompletionInfo()
            if mapID then
                completionInfo = {
                    mapChallengeModeID = mapID,
                    level = lvl,
                    time = tm,
                    onTime = ot,
                }
            end
        end

        local mapChallengeModeID = completionInfo and completionInfo.mapChallengeModeID
        local level = completionInfo and completionInfo.level
        local onTime = completionInfo and completionInfo.onTime
        DebugPrint("CompletionInfo:", tostring(mapChallengeModeID), "level:", tostring(level), "onTime:", tostring(onTime))

        if not mapChallengeModeID then
            DebugPrint("GetChallengeCompletionInfo returned nil — aborting")
            return
        end

        local dungeonName = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
        DebugPrint("Dungeon:", tostring(dungeonName))

        local members = ns.PartyScanner:GetMergedParty()
        DebugPrint("Party members found:", #members)

        -- Update stats for tracked friends
        for _, member in ipairs(members) do
            DebugPrint("  Member:", member.name, "-", member.nameRealm)
            if ns.Data:IsFriend(member.nameRealm) then
                ns.Data:UpdateFriendKeyStats(member.nameRealm, dungeonName, level)
                DebugPrint("    Updated stats for tracked friend")
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
            DebugPrint("Showing popup")
            ns.FriendRequestPopup:Show(ns.lastCompletion)
        else
            DebugPrint("FriendRequestPopup not available!")
        end
    end)

    if not ok then
        print("|cFFFF0000BetterFriends ERROR:|r " .. tostring(err))
    end
end)

-- On login, cache party if already in M+ (handles /reload mid-dungeon)
ns:RegisterEvent("PLAYER_LOGIN", ns.MythicPlusTracker, function(self, event)
    if C_ChallengeMode.IsChallengeModeActive() then
        DebugPrint("PLAYER_LOGIN: Already in M+, caching party")
        ns.PartyScanner:CachePartySnapshot()
    end
end)
