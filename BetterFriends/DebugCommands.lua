local addonName, ns = ...

-- /btf test — simulates an M+ completion with fake party data
ns.SlashHandlers["test"] = function(msg)
    print("|cFF00CCFFBetterFriends:|r Simulating M+ completion...")

    local fakeMembers = {
        {
            name = "Blobheal",
            realm = "Thrall",
            nameRealm = "blobheal-thrall",
            classToken = "PALADIN",
            classDisplayName = "Paladin",
            role = "HEALER",
            unitID = "party1",
        },
        {
            name = "Tankmachine",
            realm = "Stormrage",
            nameRealm = "tankmachine-stormrage",
            classToken = "WARRIOR",
            classDisplayName = "Warrior",
            role = "TANK",
            unitID = "party2",
        },
        {
            name = "Pewpewmage",
            realm = "Illidan",
            nameRealm = "pewpewmage-illidan",
            classToken = "MAGE",
            classDisplayName = "Mage",
            role = "DAMAGER",
            unitID = "party3",
        },
        {
            name = "Sneakyrogue",
            realm = "Thrall",
            nameRealm = "sneakyrogue-thrall",
            classToken = "ROGUE",
            classDisplayName = "Rogue",
            role = "DAMAGER",
            unitID = "party4",
        },
    }

    local completionData = {
        members = fakeMembers,
        dungeonName = "Ara-Kara",
        keyLevel = 15,
        onTime = true,
    }

    ns.lastCompletion = completionData

    if ns.FriendRequestPopup then
        ns.FriendRequestPopup:Show(completionData)
    end
end
