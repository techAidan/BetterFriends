local addonName, ns = ...

ns.FriendsViewer = {}
ns.FriendsViewer.displayList = {}
ns.FriendsViewer.rows = {}
ns.FriendsViewer.scrollOffset = 0
ns.FriendsViewer.visibleRows = 12

function ns.FriendsViewer:Create()
    if self.frame then return end

    local frame = CreateFrame("Frame", "BetterFriendsViewerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(620, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)

    -- Mouse wheel scrolling
    frame:SetScript("OnMouseWheel", function(_, delta)
        ns.FriendsViewer:Scroll(-delta)
    end)

    -- Dark background with border
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:Hide()

    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("|cFF00CCFFBetterFriends|r")
    self.titleText = title

    -- Close button (Blizzard template)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        ns.FriendsViewer:Hide()
    end)
    self.closeButton = closeBtn

    -- Footer text
    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    footer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
    footer:SetTextColor(0.7, 0.7, 0.7)
    self.footerText = footer

    -- Create visible rows (up to visibleRows)
    self.rows = {}
    for i = 1, self.visibleRows do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(580, 38)
        row:SetPoint("TOP", title, "BOTTOM", 0, -12 - (i - 1) * 40)
        row:EnableMouse(true)
        row:Hide()

        -- Zebra stripe background: every row gets a bg texture, even rows
        -- are tinted slightly so the two alternate. We set the color at
        -- UpdateRows time because the *display* row index depends on scroll.
        local bgTex = row:CreateTexture(nil, "BACKGROUND")
        bgTex:SetAllPoints(row)
        bgTex:SetColorTexture(1, 1, 1, 0)  -- transparent by default

        -- Hover highlight (shown on mouse enter)
        local hoverTex = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        hoverTex:SetAllPoints(row)
        hoverTex:SetColorTexture(0.3, 0.6, 1.0, 0.12)
        hoverTex:Hide()

        -- Section header hairline: a 1px horizontal texture sitting just
        -- under the header label. Hidden for normal rows; shown when the
        -- row is rendering an ONLINE/OFFLINE divider. Looks much more
        -- polished than the old "━━" character fake line.
        local hlineTex = row:CreateTexture(nil, "ARTWORK")
        hlineTex:SetColorTexture(0.35, 0.35, 0.40, 0.7)
        hlineTex:SetHeight(1)
        hlineTex:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 4)
        hlineTex:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 4)
        hlineTex:Hide()

        -- Inline "X" remove button, anchored to the right edge. Hidden
        -- by default; shown in OnEnter, hidden in OnLeave. Clicking it
        -- fires the same confirmation dialog as the context-menu Remove.
        local removeBtn = CreateFrame("Button", nil, row)
        removeBtn:SetSize(18, 18)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        removeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
        removeBtn:Hide()
        local rowIdxForRemove = i
        removeBtn:SetScript("OnClick", function()
            local rd = ns.FriendsViewer.rows[rowIdxForRemove]
            if rd and rd._currentEntry and not rd._currentEntry._isHeader then
                local entry = rd._currentEntry
                local displayName = entry.friend.characterName or entry.nameRealm
                if StaticPopup_Show then
                    StaticPopup_Show("BETTERFRIENDS_REMOVE_FRIEND", displayName, nil, entry.nameRealm)
                end
            end
        end)

        local rowIdxForHover = i
        row:SetScript("OnEnter", function()
            hoverTex:Show()
            local rd = ns.FriendsViewer.rows[rowIdxForHover]
            if rd and rd._currentEntry and not rd._currentEntry._isHeader then
                ns.FriendsViewer:ShowHoverTooltip(rd._currentEntry, row)
                if rd.removeBtn then rd.removeBtn:Show() end
            end
        end)
        row:SetScript("OnLeave", function()
            hoverTex:Hide()
            if GameTooltip and GameTooltip.Hide then
                GameTooltip:Hide()
            end
            local rd = ns.FriendsViewer.rows[rowIdxForHover]
            if rd and rd.removeBtn then rd.removeBtn:Hide() end
        end)

        -- Right-click opens a per-friend context menu (Whisper, Invite,
        -- Copy BattleTag, Remove, Add Note). Captured via OnMouseUp since
        -- plain Frames (not Buttons) don't fire OnClick.
        local rowIndex = i
        row:SetScript("OnMouseUp", function(_, button)
            if button == "RightButton" then
                local rd = ns.FriendsViewer.rows[rowIndex]
                if rd and rd._currentEntry and not rd._currentEntry._isHeader then
                    ns.FriendsViewer:ShowContextMenu(rd._currentEntry, row)
                end
            end
        end)

        local line1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line1:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -2)
        -- Leave room on the right for the remove button
        line1:SetPoint("TOPRIGHT", row, "TOPRIGHT", -32, -2)
        line1:SetJustifyH("LEFT")
        line1:SetWordWrap(false)

        local line2 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line2:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -2)
        line2:SetJustifyH("LEFT")

        local line3 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line3:SetPoint("TOPLEFT", line2, "BOTTOMLEFT", 0, -1)
        line3:SetJustifyH("LEFT")

        self.rows[i] = {
            row = row,
            bgTex = bgTex,
            hoverTex = hoverTex,
            hlineTex = hlineTex,
            removeBtn = removeBtn,
            line1 = line1,
            line2 = line2,
            line3 = line3,
        }
    end

    self.frame = frame
end

function ns.FriendsViewer:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function ns.FriendsViewer:Show()
    self:Create()
    self:RefreshData()
    self.frame:Show()
end

function ns.FriendsViewer:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

-- Strip spaces, hyphens and apostrophes from a realm name so realms with
-- inconsistent spelling ("Area 52" vs "Area52", "Wyrmrest Accord" vs
-- "WyrmrestAccord") can still be matched.
local function strictRealmKey(realm)
    if not realm then return "" end
    return (string.lower(realm):gsub("[%s%-']", ""))
end

-- Determine if a game account record represents a WoW character.
-- clientProgram may be nil in tests; default-allow in that case.
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

-- Enumerate every WoW game account for an online BNet friend, calling
-- `callback(info, ga)` for each. Handles three API shapes:
--   1. Modern: info.gameAccountInfo (single currently-active game account)
--   2. Multi-account API: C_BattleNet.GetFriendNumGameAccounts/GetFriendGameAccountInfo
--   3. Legacy/test mock: info.gameAccounts table
-- Note: the live WoW client does NOT populate info.gameAccounts on the
-- account-level struct, which is why we need (1) and (2).
function ns.FriendsViewer:ForEachWoWGameAccount(callback)
    if not BNGetNumFriends then return end
    local numTotal = BNGetNumFriends()

    for i = 1, numTotal do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if info and isAccountOnline(info) then
            local seen = false

            -- (1) Currently-active game account
            if info.gameAccountInfo and isWoWGameAccount(info.gameAccountInfo) then
                if info.gameAccountInfo.characterName and info.gameAccountInfo.characterName ~= "" then
                    callback(info, info.gameAccountInfo)
                    seen = true
                end
            end

            -- (2) Iterate via num/index API (covers alt characters logged into a
            --     second WoW client, or anything not reflected in gameAccountInfo)
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

            -- (3) Legacy/test fallback
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

-- Build lookups of all online BNet WoW characters.
-- Returns three tables to support progressively-fuzzier matching:
--   exact:  "name-realm" exact normalized
--   strict: "name-realmnospaces" with whitespace/punctuation removed
--   byName: lowercase name -> array of matches (used only when unambiguous)
function ns.FriendsViewer:BuildBNetCharacterLookup()
    local exact, strict, byName = {}, {}, {}

    self:ForEachWoWGameAccount(function(info, ga)
        local match = {
            accountID = info.bnetAccountID,
            btag = info.battleTag,
            characterName = ga.characterName,
            className = ga.className,
            areaName = ga.areaName,
            realmName = ga.realmName,
        }
        local lowerName = string.lower(ga.characterName)
        if ga.realmName and ga.realmName ~= "" then
            exact[lowerName .. "-" .. string.lower(ga.realmName)] = match
            strict[lowerName .. "-" .. strictRealmKey(ga.realmName)] = match
        end
        byName[lowerName] = byName[lowerName] or {}
        table.insert(byName[lowerName], match)
    end)

    return exact, strict, byName
end

-- Try progressively fuzzier matches against a tracked friend record.
local function findBNetMatch(friend, exact, strict, byName)
    local lowerName = friend.characterName and string.lower(friend.characterName) or nil
    local lowerRealm = friend.realm and string.lower(friend.realm) or nil

    -- 1. Exact normalized name-realm
    if lowerName and lowerRealm then
        local key = lowerName .. "-" .. lowerRealm
        if exact[key] then return exact[key], "exact" end
    end

    -- 2. Strict (whitespace/punctuation removed) name-realm
    if lowerName and friend.realm then
        local key = lowerName .. "-" .. strictRealmKey(friend.realm)
        if strict[key] then return strict[key], "strict" end
    end

    -- 3. Name-only, but only if unambiguous (single online char with that name)
    if lowerName and byName[lowerName] and #byName[lowerName] == 1 then
        return byName[lowerName][1], "name-only"
    end

    return nil, nil
end

function ns.FriendsViewer:RefreshData()
    local allFriends = ns.Data:GetAllFriends()
    local entries = {}
    local onlineCount = 0

    -- Build a set of current party members for fallback online detection
    local partyMembers = {}
    if ns.PartyScanner then
        local currentParty = ns.PartyScanner:CaptureCurrentParty()
        for _, member in ipairs(currentParty) do
            partyMembers[member.nameRealm] = member
        end
    end

    -- Build lookups of BNet WoW characters for fuzzy online detection
    -- when no bnetAccountID is stored on the tracked friend record.
    local exactBNet, strictBNet, byNameBNet = self:BuildBNetCharacterLookup()

    for nameRealm, friend in pairs(allFriends) do
        local liveStatus = nil
        local inParty = partyMembers[nameRealm] ~= nil

        -- 1. Try BNet status by stored account ID
        if friend.bnetAccountID and ns.BNetLinker then
            liveStatus = ns.BNetLinker:GetLiveStatus(nameRealm)
        end

        -- 2. Fallback: fuzzy-match against all online BNet friends.
        --    Opportunistically link the friend so future lookups are cheap.
        if (not liveStatus or not liveStatus.isOnline) then
            local match, how = findBNetMatch(friend, exactBNet, strictBNet, byNameBNet)
            if match then
                liveStatus = {
                    isOnline = true,
                    currentCharacter = match.characterName,
                    currentClass = match.className,
                    zone = match.areaName,
                }
                if not friend.bnetAccountID then
                    ns.Data:SetBNetLink(nameRealm, match.accountID, match.btag)
                    if ns.DebugLog then
                        ns.DebugLog:Log("Viewer", "Auto-linked", nameRealm, "to", match.btag, "via", how)
                    end
                end
            end
        end

        -- 3. Fallback: if they're in your party right now, they're online
        if (not liveStatus or not liveStatus.isOnline) and inParty then
            local partyInfo = partyMembers[nameRealm]
            liveStatus = {
                isOnline = true,
                currentCharacter = partyInfo.name,
                currentClass = partyInfo.classDisplayName,
                zone = "In your party",
            }
        end

        local isOnline = liveStatus and liveStatus.isOnline or false
        if isOnline then
            onlineCount = onlineCount + 1
        end

        table.insert(entries, {
            nameRealm = nameRealm,
            friend = friend,
            liveStatus = liveStatus,
            _isOnline = isOnline,
        })
    end

    -- Sort: online first, then alphabetically by characterName
    table.sort(entries, function(a, b)
        if a._isOnline ~= b._isOnline then
            return a._isOnline
        end
        return (a.friend.characterName or ""):lower() < (b.friend.characterName or ""):lower()
    end)

    self.displayList = entries
    self._onlineCount = onlineCount
    self._totalCount = #entries

    -- renderList is what UpdateRows actually iterates over. It is
    -- displayList with section-header pseudo-entries interleaved so the
    -- viewer shows "━━ ONLINE (7) ━━" / "━━ OFFLINE (15) ━━" dividers.
    -- Kept separate from displayList so external tests/API consumers
    -- still see the flat friend list, indexable 1:1 with friend count.
    local offlineCount = #entries - onlineCount
    local renderList = {}
    if onlineCount > 0 then
        table.insert(renderList, {
            _isHeader = true,
            _headerText = "|cFF40FF40ONLINE|r  (" .. onlineCount .. ")",
        })
        for _, e in ipairs(entries) do
            if e._isOnline then table.insert(renderList, e) end
        end
    end
    if offlineCount > 0 then
        table.insert(renderList, {
            _isHeader = true,
            _headerText = "|cFFFF4444OFFLINE|r  (" .. offlineCount .. ")",
        })
        for _, e in ipairs(entries) do
            if not e._isOnline then table.insert(renderList, e) end
        end
    end
    self.renderList = renderList

    -- Reset scroll to top whenever data is refreshed
    self.scrollOffset = 0

    self:UpdateRows()
end

function ns.FriendsViewer:Scroll(delta)
    -- Scroll math is over renderList (which includes header rows) since
    -- headers occupy row slots in the display.
    local total = self.renderList and #self.renderList or 0
    local maxOffset = math.max(0, total - self.visibleRows)
    local newOffset = math.max(0, math.min(maxOffset, (self.scrollOffset or 0) + delta))
    if newOffset ~= self.scrollOffset then
        self.scrollOffset = newOffset
        self:UpdateRows()
    end
end

function ns.FriendsViewer:UpdateRows()
    local offset = self.scrollOffset or 0
    local renderList = self.renderList or {}
    for i = 1, self.visibleRows do
        local rowData = self.rows[i]
        if not rowData then break end

        local entry = renderList[i + offset]
        -- Remember which entry is currently in this row slot so the
        -- right-click handler can look it up without re-deriving it.
        rowData._currentEntry = entry

        -- Zebra stripe: even visible rows get a subtle tint, UNLESS the
        -- row is a section header (which needs a clean backdrop for the
        -- divider look). Keyed on visible row index so the pattern stays
        -- consistent as you scroll.
        if rowData.bgTex then
            if entry and entry._isHeader then
                rowData.bgTex:SetColorTexture(1, 1, 1, 0)
            elseif i % 2 == 0 then
                rowData.bgTex:SetColorTexture(1, 1, 1, 0.04)
            else
                rowData.bgTex:SetColorTexture(1, 1, 1, 0)
            end
        end

        if entry and entry._isHeader then
            -- Render as a divider: compact label on line1, a thin
            -- texture hairline across the row below it, and no mouse
            -- interaction. Much cleaner than the old "━━" character fake.
            rowData.line1:SetText(entry._headerText)
            rowData.line2:SetText("")
            rowData.line3:SetText("")
            if rowData.hoverTex then rowData.hoverTex:Hide() end
            if rowData.removeBtn then rowData.removeBtn:Hide() end
            if rowData.hlineTex then rowData.hlineTex:Show() end
            rowData.row:EnableMouse(false)
            rowData.row:Show()
        elseif entry then
            rowData.row:EnableMouse(true)
            if rowData.hlineTex then rowData.hlineTex:Hide() end
            local friend = entry.friend
            local liveStatus = entry.liveStatus

            -- Line 1: role icon  class-colored name  BattleTag
            -- Class-color already carries the class identity, so no
            -- separate class icon; the role icon (shield / plus /
            -- crossed swords) is the piece of info not conveyed by
            -- the name's color alone.
            local roleIcon = friend.role and ns.Utils.GetRoleIcon(friend.role) or ""
            local coloredName = ns.Utils.GetClassColoredName(friend.characterName, friend.className)
            local leading = (roleIcon ~= "") and (roleIcon .. " ") or ""
            local parts = { leading .. coloredName }
            if friend.bnetTag then
                table.insert(parts, "|cFFAAAAAA" .. friend.bnetTag .. "|r")
            else
                table.insert(parts, "|cFF666666(no BNet link)|r")
            end
            rowData.line1:SetText(table.concat(parts, "  "))

            -- Line 2: online status (green) or offline with relative last-seen
            if entry._isOnline and liveStatus then
                local statusText = "|cFF40FF40Online|r - " .. (liveStatus.currentCharacter or "?")
                if liveStatus.currentClass then
                    statusText = statusText .. " (" .. liveStatus.currentClass .. ")"
                end
                if liveStatus.zone then
                    statusText = statusText .. " - " .. liveStatus.zone
                end
                rowData.line2:SetText(statusText)
            else
                local offlineText = "|cFFFF4444Offline|r"
                if friend.lastSeenTimestamp then
                    offlineText = offlineText .. " - last seen " .. ns.Utils.FormatRelativeTime(friend.lastSeenTimestamp)
                end
                rowData.line2:SetText(offlineText)
            end

            -- Line 3: key stats, with relative "met" time
            local statsText = (friend.keysCompleted or 0) .. " keys together"
            if friend.highestKeyLevel then
                statsText = statsText .. " | Best: +" .. friend.highestKeyLevel .. " " .. (friend.highestKeyDungeon or "")
            end
            if friend.addedKeyLevel and friend.addedDungeon then
                local dateStr = ""
                if friend.addedTimestamp then
                    dateStr = " (" .. ns.Utils.FormatRelativeTime(friend.addedTimestamp) .. ")"
                end
                statsText = statsText .. " | Met: +" .. friend.addedKeyLevel .. " " .. friend.addedDungeon .. dateStr
            end
            rowData.line3:SetText(statsText)

            -- Remove button stays hidden until the user hovers the row;
            -- ensure it's reset here in case this slot previously held a
            -- header (which would have called Hide() already but be safe).
            if rowData.removeBtn then rowData.removeBtn:Hide() end

            rowData.row:Show()
        else
            rowData.row:Hide()
        end
    end

    -- Update footer with online count + scroll indicator
    if self.footerText then
        local total = self._totalCount or 0
        local online = self._onlineCount or 0
        local footerStr = online .. " online / " .. total .. " tracked"
        -- Show scroll hint based on renderList size (which includes
        -- header rows), not friend count, since headers take row slots.
        if #(self.renderList or {}) > self.visibleRows then
            footerStr = footerStr .. "  -  scroll for more"
        end
        self.footerText:SetText(footerStr)
    end
end

function ns.FriendsViewer:GetDisplayList()
    return self.displayList
end

function ns.FriendsViewer:GetFriendCount()
    return self._totalCount or 0
end

function ns.FriendsViewer:GetOnlineCount()
    return self._onlineCount or 0
end

-- ============================================================
-- Hover tooltip: rich per-friend key history
-- ============================================================

-- Build an array of tooltip lines for a given friend entry. Returned as
-- { { left = "...", right = "..." }, ... } so tests can inspect the
-- structure without needing a real GameTooltip. ShowHoverTooltip renders
-- this into Blizzard's GameTooltip.
--
-- The tooltip deliberately does NOT echo information already visible on
-- the row itself (name, class color, role, BNet tag, aggregate key stats).
-- Its sole job is to surface things you can't see at a glance:
--   * realm (the row elides it to save space)
--   * how long they've been in your friends list
--   * freeform note
--   * the full per-run key history (every run, not just best+met)
function ns.FriendsViewer:BuildTooltipLines(entry)
    local friend = entry.friend
    local lines = {}

    -- Realm (often not on the row since cross-realm names get cramped)
    if friend.realm and friend.realm ~= "" then
        table.insert(lines, { left = "|cFFAAAAAARealm:|r " .. friend.realm })
    end

    -- Friendship duration — humanized (e.g. "Friends for 3 days")
    if friend.addedTimestamp then
        table.insert(lines, {
            left = "|cFFAAAAAAFriends for:|r " .. ns.Utils.FormatRelativeTime(friend.addedTimestamp):gsub(" ago$", ""),
        })
    end

    -- Note (if present) — freeform, never shown on the row
    if friend.notes and friend.notes ~= "" then
        table.insert(lines, { left = "|cFFFFDD88Note:|r " .. friend.notes })
    end

    -- Blank separator before the history block
    table.insert(lines, { left = " " })

    -- Per-run key history: this is the main value-add. Lists every run,
    -- not just the best/most-recent like the row does.
    local history = friend.keyHistory
    if history and #history > 0 then
        table.insert(lines, { left = "|cFFFFD100Full History  (" .. #history .. ")|r" })
        for _, run in ipairs(history) do
            local left = "  +" .. (run.level or "?") .. "  " .. (run.dungeon or "?")
            local right
            if run.onTime == true then
                right = "|cFF40FF40Timed|r"
            elseif run.onTime == false then
                right = "|cFFFF4444Depleted|r"
            else
                right = "|cFF888888-|r"
            end
            if run.timestamp then
                right = right .. "  |cFF888888" .. ns.Utils.FormatRelativeTime(run.timestamp) .. "|r"
            end
            table.insert(lines, { left = left, right = right })
        end
    else
        -- Legacy entry with no recorded history — nothing unique to
        -- show, so point the user at where the data will come from.
        table.insert(lines, {
            left = "|cFF888888No recorded runs yet - history will appear after your next key together.|r",
        })
    end

    return lines
end

-- Render the tooltip at the anchor frame using GameTooltip.
function ns.FriendsViewer:ShowHoverTooltip(entry, anchorFrame)
    if not entry or entry._isHeader then return end
    if not GameTooltip then return end

    local lines = self:BuildTooltipLines(entry)

    GameTooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")
    if GameTooltip.ClearLines then GameTooltip:ClearLines() end
    for _, line in ipairs(lines) do
        if line.right then
            if GameTooltip.AddDoubleLine then
                GameTooltip:AddDoubleLine(line.left, line.right, 1, 1, 1, 1, 1, 1)
            else
                GameTooltip:AddLine(line.left .. "  " .. line.right)
            end
        else
            GameTooltip:AddLine(line.left, 1, 1, 1, true)
        end
    end
    GameTooltip:Show()
end

-- ============================================================
-- Right-click context menu
-- ============================================================

-- Build the list of menu entries for a given friend entry. Returned as
-- plain data (an array of { text, func, disabled, notCheckable }) so
-- tests can verify the menu without actually rendering a dropdown.
-- ShowContextMenu feeds this into Blizzard's EasyMenu.
function ns.FriendsViewer:BuildContextMenu(entry)
    local friend = entry.friend
    local nameRealm = entry.nameRealm
    local liveStatus = entry.liveStatus
    local isOnline = entry._isOnline
    local currentCharacter = liveStatus and liveStatus.currentCharacter

    local displayName = friend.characterName or nameRealm
    local menu = {
        { text = displayName, isTitle = true, notCheckable = true },
    }

    -- Whisper — target the current character if we know it (online), or
    -- the stored character otherwise. Disabled if we have nothing to
    -- send to.
    local whisperTarget = currentCharacter or friend.characterName
    table.insert(menu, {
        text = "Whisper",
        notCheckable = true,
        disabled = not whisperTarget,
        func = function()
            if whisperTarget and ChatFrame_SendTell then
                ChatFrame_SendTell(whisperTarget)
            end
        end,
    })

    -- Invite to Party — only makes sense if they're online
    table.insert(menu, {
        text = "Invite to Party",
        notCheckable = true,
        disabled = not (isOnline and whisperTarget),
        func = function()
            if not whisperTarget then return end
            if C_PartyInfo and C_PartyInfo.InviteUnit then
                C_PartyInfo.InviteUnit(whisperTarget)
            elseif InviteUnit then
                InviteUnit(whisperTarget)
            end
        end,
    })

    -- Copy BattleTag — shows a popup with a selectable edit box so the
    -- user can Ctrl+C. Disabled if no link.
    table.insert(menu, {
        text = "Copy BattleTag",
        notCheckable = true,
        disabled = not friend.bnetTag,
        func = function()
            if friend.bnetTag and StaticPopup_Show then
                StaticPopup_Show("BETTERFRIENDS_COPY_BTAG", friend.bnetTag, nil, friend.bnetTag)
            end
        end,
    })

    -- Add/Edit Note — opens a text entry popup.
    local hasNote = friend.notes and friend.notes ~= ""
    table.insert(menu, {
        text = hasNote and "Edit Note" or "Add Note",
        notCheckable = true,
        func = function()
            if StaticPopup_Show then
                StaticPopup_Show("BETTERFRIENDS_EDIT_NOTE", displayName, nil, {
                    nameRealm = nameRealm,
                    existingNote = friend.notes or "",
                })
            end
        end,
    })

    -- Separator before the destructive action
    table.insert(menu, { text = "", disabled = true, notCheckable = true })

    -- Remove from tracking — confirmation popup.
    table.insert(menu, {
        text = "|cFFFF4444Remove from BetterFriends|r",
        notCheckable = true,
        func = function()
            if StaticPopup_Show then
                StaticPopup_Show("BETTERFRIENDS_REMOVE_FRIEND", displayName, nil, nameRealm)
            end
        end,
    })

    table.insert(menu, { text = "Cancel", notCheckable = true, func = function() end })

    return menu
end

-- Render the context menu at the cursor. Uses Blizzard's EasyMenu.
function ns.FriendsViewer:ShowContextMenu(entry, anchorFrame)
    if not entry or entry._isHeader then return end
    local menu = self:BuildContextMenu(entry)

    -- Lazily create a dropdown menu frame — EasyMenu needs one to render
    -- into. Parented to UIParent so it survives the viewer being hidden
    -- (though in practice we only call this while the viewer is shown).
    if not self._menuFrame then
        self._menuFrame = CreateFrame("Frame", "BetterFriendsContextMenu", UIParent, "UIDropDownMenuTemplate")
    end

    if EasyMenu then
        EasyMenu(menu, self._menuFrame, "cursor", 0, 0, "MENU")
    end
end

-- ============================================================
-- StaticPopup dialog registrations (executed at load time in WoW;
-- guarded for tests where StaticPopupDialogs isn't populated by the
-- mock but assignment is harmless).
-- ============================================================
StaticPopupDialogs = StaticPopupDialogs or {}

StaticPopupDialogs["BETTERFRIENDS_REMOVE_FRIEND"] = {
    text = "Remove %s from BetterFriends? This clears all tracked key history for this character.",
    button1 = "Remove",
    button2 = "Cancel",
    OnAccept = function(self, nameRealm)
        if ns.Data:RemoveFriend(nameRealm) then
            if ns.FriendsViewer and ns.FriendsViewer.RefreshData then
                ns.FriendsViewer:RefreshData()
            end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BETTERFRIENDS_COPY_BTAG"] = {
    text = "%s",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 200,
    OnShow = function(self, btag)
        if self.editBox then
            self.editBox:SetText(btag or "")
            self.editBox:HighlightText()
            self.editBox:SetFocus()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BETTERFRIENDS_EDIT_NOTE"] = {
    text = "Note for %s:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 260,
    maxLetters = 200,
    OnShow = function(self, data)
        if self.editBox and data then
            self.editBox:SetText(data.existingNote or "")
            self.editBox:HighlightText()
            self.editBox:SetFocus()
            self._nameRealm = data.nameRealm
        end
    end,
    OnAccept = function(self, data)
        local text = self.editBox and self.editBox:GetText() or ""
        local nameRealm = data and data.nameRealm
        if nameRealm then
            ns.Data:SetNote(nameRealm, text)
            if ns.FriendsViewer and ns.FriendsViewer.RefreshData then
                ns.FriendsViewer:RefreshData()
            end
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        if parent.button1 then parent.button1:Click() end
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
