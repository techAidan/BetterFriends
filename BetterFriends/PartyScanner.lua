local addonName, ns = ...

ns.PartyScanner = {}

function ns.PartyScanner:CaptureCurrentParty()
    local party = {}
    for i = 1, 4 do
        local unit = "party" .. i
        local name, realm = UnitName(unit)
        if name then
            if not realm or realm == "" then
                realm = GetNormalizedRealmName()
            end
            local classDisplayName, classToken = UnitClass(unit)
            local role = UnitGroupRolesAssigned(unit)
            local nameRealm = ns.Utils.NormalizeNameRealm(name, realm)
            table.insert(party, {
                name = name,
                realm = realm,
                nameRealm = nameRealm,
                classToken = classToken,
                classDisplayName = classDisplayName,
                role = role,
            })
        end
    end
    return party
end

function ns.PartyScanner:CachePartySnapshot()
    self.cachedSnapshot = self:CaptureCurrentParty()
end

function ns.PartyScanner:GetCachedSnapshot()
    return self.cachedSnapshot
end

function ns.PartyScanner:GetMergedParty()
    local live = self:CaptureCurrentParty()
    if #live > 0 then
        -- Build a set of nameRealms from live data
        local liveSet = {}
        for _, member in ipairs(live) do
            liveSet[member.nameRealm] = true
        end
        -- Fill gaps from cache
        if self.cachedSnapshot then
            for _, cached in ipairs(self.cachedSnapshot) do
                if not liveSet[cached.nameRealm] then
                    table.insert(live, cached)
                    liveSet[cached.nameRealm] = true
                end
            end
        end
        return live
    end
    -- No live data, return cache if available
    return self.cachedSnapshot or {}
end
