local addonName, ns = ...

ns.Utils = {}

function ns.Utils.GetClassColor(classToken)
    local color = RAID_CLASS_COLORS[classToken]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

function ns.Utils.GetClassColoredName(name, classToken)
    local color = RAID_CLASS_COLORS[classToken]
    if color then
        return color:WrapTextInColorCode(name)
    end
    return name
end

function ns.Utils.GetRoleIcon(role)
    local atlasMap = {
        TANK = "roleicon-tank",
        HEALER = "roleicon-healer",
        DAMAGER = "roleicon-dps",
    }
    local atlas = atlasMap[role]
    if atlas then
        return CreateAtlasMarkup(atlas, 16, 16)
    end
    return ""
end

function ns.Utils.GetRoleDisplayName(role)
    local names = {
        TANK = "Tank",
        HEALER = "Healer",
        DAMAGER = "DPS",
    }
    return names[role] or "Unknown"
end

function ns.Utils.FormatKeyLevel(level, dungeon)
    return "+" .. level .. " " .. dungeon
end

function ns.Utils.FormatTimestamp(timestamp)
    return date("%Y-%m-%d", timestamp)
end

function ns.Utils.FormatRelativeTime(timestamp)
    local diff = time() - timestamp
    if diff < 60 then
        return diff .. "s ago"
    elseif diff < 3600 then
        return math.floor(diff / 60) .. "m ago"
    elseif diff < 86400 then
        return math.floor(diff / 3600) .. "h ago"
    else
        return math.floor(diff / 86400) .. "d ago"
    end
end

function ns.Utils.NormalizeNameRealm(name, realm)
    if not realm or realm == "" then
        realm = GetNormalizedRealmName()
    end
    return string.lower(name) .. "-" .. string.lower(realm)
end
