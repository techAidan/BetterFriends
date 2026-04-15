-- WoW API Mock for testing BetterFriends addon
-- Simulates the WoW Lua environment so addon code can run outside the game client

-- Addon namespace simulation
-- In WoW, each file gets (addonName, ns) via `local addonName, ns = ...`
-- We simulate this with a global namespace table
BetterFriendsNS = {}

-- Saved variables (persisted globals in WoW)
BetterFriendsDB = nil
BetterFriendsDebugLog = nil

-- ============================================================
-- Frame system mock
-- ============================================================
local FrameMethods = {}
FrameMethods.__index = FrameMethods

function FrameMethods:RegisterEvent(event)
    self._registeredEvents[event] = true
end

function FrameMethods:UnregisterEvent(event)
    self._registeredEvents[event] = nil
end

function FrameMethods:SetScript(scriptType, handler)
    self._scripts[scriptType] = handler
end

function FrameMethods:GetScript(scriptType)
    return self._scripts[scriptType]
end

function FrameMethods:Show() self._visible = true end
function FrameMethods:Hide() self._visible = false end
function FrameMethods:IsShown() return self._visible end
function FrameMethods:SetSize(w, h) self._width = w; self._height = h end
function FrameMethods:SetWidth(w) self._width = w end
function FrameMethods:SetHeight(h) self._height = h end
function FrameMethods:GetWidth() return self._width or 0 end
function FrameMethods:GetHeight() return self._height or 0 end
function FrameMethods:SetPoint(...) self._points = {...} end
function FrameMethods:ClearAllPoints() self._points = {} end
function FrameMethods:SetMovable(v) self._movable = v end
function FrameMethods:EnableMouse(v) self._mouseEnabled = v end
function FrameMethods:EnableMouseWheel(v) self._mouseWheelEnabled = v end
function FrameMethods:SetClampedToScreen(v) self._clamped = v end
function FrameMethods:RegisterForDrag(...) end
function FrameMethods:SetBackdrop(backdrop) self._backdrop = backdrop end
function FrameMethods:SetBackdropColor(...) end
function FrameMethods:SetBackdropBorderColor(...) end
function FrameMethods:SetParent(parent) self._parent = parent end
function FrameMethods:GetParent() return self._parent end
function FrameMethods:SetFrameStrata(strata) self._strata = strata end
function FrameMethods:SetFrameLevel(level) self._frameLevel = level end
function FrameMethods:GetName() return self._name end
function FrameMethods:SetAlpha(a) self._alpha = a end
function FrameMethods:GetAlpha() return self._alpha or 1 end
function FrameMethods:StartMoving() end
function FrameMethods:StopMovingOrSizing() end
function FrameMethods:GetCenter() return 500, 500 end
function FrameMethods:GetEffectiveScale() return 1 end
function FrameMethods:RegisterForClicks(...) end
function FrameMethods:SetOwner(...) end
function FrameMethods:AddLine(...) end

-- FontString mock methods
function FrameMethods:SetText(text) self._text = text end
function FrameMethods:GetText() return self._text or "" end
function FrameMethods:SetTextColor(r, g, b, a) end
function FrameMethods:SetFont(...) end
function FrameMethods:SetJustifyH(j) end
function FrameMethods:SetJustifyV(j) end
function FrameMethods:SetWordWrap(v) end

-- Button mock methods
function FrameMethods:SetEnabled(v) self._enabled = v end
function FrameMethods:IsEnabled() return self._enabled ~= false end
function FrameMethods:Enable() self._enabled = true end
function FrameMethods:Disable() self._enabled = false end
function FrameMethods:SetNormalTexture(t) end
function FrameMethods:SetHighlightTexture(t) end
function FrameMethods:SetPushedTexture(t) end
function FrameMethods:SetDisabledTexture(t) end

-- Texture mock methods
function FrameMethods:SetTexture(t) self._texture = t end
function FrameMethods:SetTexCoord(...) end
function FrameMethods:SetAtlas(atlas) self._atlas = atlas end
function FrameMethods:SetVertexColor(...) end
function FrameMethods:SetColorTexture(r, g, b, a) self._colorTexture = {r, g, b, a} end
function FrameMethods:SetAllPoints(frame) end
function FrameMethods:SetDrawLayer(layer) end

-- Child creation
function FrameMethods:CreateFontString(name, layer, template)
    return CreateFrame("FontString", name, self, template)
end

function FrameMethods:CreateTexture(name, layer, template)
    return CreateFrame("Texture", name, self, template)
end

-- Track all created frames for test inspection
_G._createdFrames = {}

function CreateFrame(frameType, name, parent, template)
    local frame = setmetatable({}, FrameMethods)
    frame._type = frameType
    frame._name = name
    frame._parent = parent
    frame._template = template
    frame._registeredEvents = {}
    frame._scripts = {}
    frame._visible = false
    frame._points = {}
    frame._children = {}
    table.insert(_G._createdFrames, frame)
    if name then
        _G[name] = frame
    end
    return frame
end

-- ============================================================
-- RAID_CLASS_COLORS
-- ============================================================
RAID_CLASS_COLORS = {
    ["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, colorStr = "ffc79c6e" },
    ["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" },
    ["HUNTER"] = { r = 0.67, g = 0.83, b = 0.45, colorStr = "ffabd473" },
    ["ROGUE"] = { r = 1.00, g = 0.96, b = 0.41, colorStr = "fffff569" },
    ["PRIEST"] = { r = 1.00, g = 1.00, b = 1.00, colorStr = "ffffffff" },
    ["DEATHKNIGHT"] = { r = 0.77, g = 0.12, b = 0.23, colorStr = "ffc41f3b" },
    ["SHAMAN"] = { r = 0.00, g = 0.44, b = 0.87, colorStr = "ff0070de" },
    ["MAGE"] = { r = 0.25, g = 0.78, b = 0.92, colorStr = "ff40c7eb" },
    ["WARLOCK"] = { r = 0.53, g = 0.53, b = 0.93, colorStr = "ff8787ed" },
    ["MONK"] = { r = 0.00, g = 1.00, b = 0.60, colorStr = "ff00ff96" },
    ["DRUID"] = { r = 1.00, g = 0.49, b = 0.04, colorStr = "ffff7d0a" },
    ["DEMONHUNTER"] = { r = 0.64, g = 0.19, b = 0.79, colorStr = "ffa330c9" },
    ["EVOKER"] = { r = 0.20, g = 0.58, b = 0.50, colorStr = "ff33937f" },
}

-- Add WrapTextInColorCode method to each color
for class, color in pairs(RAID_CLASS_COLORS) do
    color.WrapTextInColorCode = function(self, text)
        return "|c" .. self.colorStr .. text .. "|r"
    end
end

-- ============================================================
-- Unit functions mock (configurable per test)
-- ============================================================
_G._mockUnits = {}

function UnitName(unit)
    local data = _G._mockUnits[unit]
    if data then return data.name, data.realm end
    return nil, nil
end

function UnitClass(unit)
    local data = _G._mockUnits[unit]
    if data then return data.classDisplayName, data.className end
    return nil, nil
end

function UnitGroupRolesAssigned(unit)
    local data = _G._mockUnits[unit]
    if data then return data.role end
    return "NONE"
end

function UnitIsUnit(unit1, unit2)
    return unit1 == unit2
end

function GetNumGroupMembers()
    local count = 0
    for unit, _ in pairs(_G._mockUnits) do
        if unit:match("^party") or unit == "player" then
            count = count + 1
        end
    end
    return count
end

function GetNormalizedRealmName()
    return _G._mockPlayerRealm or "TestRealm"
end

-- ============================================================
-- Challenge Mode API mock
-- ============================================================
C_ChallengeMode = {}

_G._mockChallengeMode = {
    active = false,
    completionInfo = nil,
    mapInfo = {},
}

function C_ChallengeMode.IsChallengeModeActive()
    return _G._mockChallengeMode.active
end

-- WoW 12.0 (Midnight) API: returns a struct
function C_ChallengeMode.GetChallengeCompletionInfo()
    local info = _G._mockChallengeMode.completionInfo
    if info then
        return {
            mapChallengeModeID = info.mapChallengeModeID,
            level = info.level,
            time = info.time,
            onTime = info.onTime,
            keystoneUpgradeLevels = info.keystoneUpgradeLevels,
            practiceRun = info.practiceRun,
            oldOverallDungeonScore = info.oldOverallDungeonScore,
            newOverallDungeonScore = info.newOverallDungeonScore,
            isMapRecord = info.IsMapRecord,
            isAffixRecord = info.IsAffixRecord,
            isEligibleForScore = info.isEligibleForScore,
            members = info.members,
        }
    end
    return nil
end

-- Legacy fallback (pre-12.0)
function C_ChallengeMode.GetCompletionInfo()
    local info = _G._mockChallengeMode.completionInfo
    if info then
        return info.mapChallengeModeID, info.level, info.time, info.onTime,
               info.keystoneUpgradeLevels, info.practiceRun, info.oldOverallDungeonScore,
               info.newOverallDungeonScore, info.IsMapRecord, info.IsAffixRecord,
               info.PrimaryAffix, info.isEligibleForScore, info.members
    end
    return nil
end

function C_ChallengeMode.GetMapUIInfo(mapID)
    local info = _G._mockChallengeMode.mapInfo[mapID]
    if info then
        return info.name, info.id, info.timeLimit, info.texture, info.backgroundTexture
    end
    return nil
end

-- ============================================================
-- Friend list API mock
-- ============================================================
C_FriendList = {}

_G._mockFriendList = {}

function C_FriendList.AddFriend(name)
    table.insert(_G._mockFriendList, { name = name, type = "character" })
end

function C_FriendList.GetNumFriends()
    return #_G._mockFriendList
end

function C_FriendList.GetFriendInfoByIndex(index)
    return _G._mockFriendList[index]
end

-- ============================================================
-- BattleNet API mock
-- ============================================================
C_BattleNet = {}

_G._mockBNetFriends = {}
_G._mockBNetInvitesSent = {}

function BNGetNumFriends()
    -- Real WoW API: returns (numBNetTotal, numBNetOnline)
    local online = 0
    for _, f in ipairs(_G._mockBNetFriends) do
        if f.isOnline then online = online + 1 end
    end
    return #_G._mockBNetFriends, online
end

function BNSendFriendInvite(text, noteText)
    table.insert(_G._mockBNetInvitesSent, { text = text, note = noteText })
end

-- Verified BattleTag invite flow (unit-based)
_G._mockBNCheckInviteUnit = nil
_G._mockBNVerifiedInviteSent = false

function BNCheckBattleTagInviteToUnit(unitID)
    _G._mockBNCheckInviteUnit = unitID
    table.insert(_G._mockBNetInvitesSent, { type = "check", unit = unitID })
end

function BNSendVerifiedBattleTagInvite()
    _G._mockBNVerifiedInviteSent = true
    table.insert(_G._mockBNetInvitesSent, { type = "verified" })
end

function C_BattleNet.GetFriendAccountInfo(index)
    -- Friends in the mock can declare either:
    --   * gameAccounts (legacy/test-only table)
    --   * gameAccountInfo (modern API: currently-active game account)
    -- Tests may set either (or both) to exercise different code paths.
    return _G._mockBNetFriends[index]
end

function C_BattleNet.GetFriendNumGameAccounts(index)
    local friend = _G._mockBNetFriends[index]
    if friend and friend.gameAccounts then
        return #friend.gameAccounts
    end
    return 0
end

function C_BattleNet.GetFriendGameAccountInfo(friendIndex, gameIndex)
    local friend = _G._mockBNetFriends[friendIndex]
    if friend and friend.gameAccounts then
        return friend.gameAccounts[gameIndex]
    end
    return nil
end

-- ============================================================
-- Misc WoW globals
-- ============================================================
UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap")
GameTooltip = CreateFrame("Frame", "GameTooltip")

function GetCursorPosition()
    return 500, 500
end

function CreateAtlasMarkup(atlas, width, height)
    return "|A:" .. atlas .. ":" .. (width or 0) .. ":" .. (height or 0) .. "|a"
end

function date(format, timestamp)
    return os.date(format, timestamp)
end

time = os.time

-- Slash command infrastructure
SlashCmdList = {}

function print(...)
    -- Capture prints for test assertions
    local args = {...}
    local parts = {}
    for i, v in ipairs(args) do
        parts[i] = tostring(v)
    end
    local msg = table.concat(parts, " ")
    if _G._capturedPrints then
        table.insert(_G._capturedPrints, msg)
    end
end

-- ============================================================
-- Addon loading simulation
-- ============================================================

-- Simulates WoW's `...` (varargs) that each addon file receives
-- Each file should call: local addonName, ns = ...
-- We override loadfile to inject these
function LoadAddonFile(filepath)
    local fn, err = loadfile(filepath)
    if not fn then
        error("Failed to load " .. filepath .. ": " .. tostring(err))
    end
    -- WoW passes (addonName, namespace) to each file
    setfenv(fn, getfenv())
    return fn("BetterFriends", BetterFriendsNS)
end

-- ============================================================
-- Test helper: reset all mocks between tests
-- ============================================================
function ResetMocks()
    BetterFriendsDB = nil
    BetterFriendsDebugLog = nil
    BetterFriendsNS = {}
    _G._mockUnits = {}
    _G._mockPlayerRealm = "TestRealm"
    _G._mockChallengeMode = { active = false, completionInfo = nil, mapInfo = {} }
    _G._mockFriendList = {}
    _G._mockBNetFriends = {}
    _G._mockBNetInvitesSent = {}
    _G._mockBNCheckInviteUnit = nil
    _G._mockBNVerifiedInviteSent = false
    _G._createdFrames = {}
    _G._capturedPrints = {}
    SlashCmdList = {}
    -- Clear any slash command globals
    for k, v in pairs(_G) do
        if type(k) == "string" and k:match("^SLASH_") then
            _G[k] = nil
        end
    end
end
