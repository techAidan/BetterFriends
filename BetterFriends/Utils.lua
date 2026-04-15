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

-- Role icons as inline |T..|t markup using Blizzard's classic LFG role
-- texture sheet. This texture ships with every WoW build so the icons
-- render reliably regardless of Retail/Classic/patch. Coordinates are
-- picked from the 64x64 sprite sheet to give:
--   TANK    -> shield
--   HEALER  -> plus/cross
--   DAMAGER -> crossed swords (dagger-equivalent)
local ROLE_ICON_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local ROLE_ICON_COORDS = {
    TANK    = { 0,  19, 22, 41 },
    HEALER  = { 20, 39,  1, 20 },
    DAMAGER = { 20, 39, 22, 41 },
}
function ns.Utils.GetRoleIcon(role)
    local c = ROLE_ICON_COORDS[role]
    if not c then return "" end
    return string.format(
        "|T%s:16:16:0:0:64:64:%d:%d:%d:%d|t",
        ROLE_ICON_TEXTURE, c[1], c[2], c[3], c[4]
    )
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
