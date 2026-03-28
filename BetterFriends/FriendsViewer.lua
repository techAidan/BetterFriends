local addonName, ns = ...

ns.FriendsViewer = {}
ns.FriendsViewer.displayList = {}
ns.FriendsViewer.rows = {}

function ns.FriendsViewer:Create()
    if self.frame then return end

    local frame = CreateFrame("Frame", "BetterFriendsViewerFrame")
    frame:SetSize(600, 450)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
    frame:Hide()

    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("BetterFriends")
    self.titleText = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetText("X")
    closeBtn:SetScript("OnClick", function()
        ns.FriendsViewer:Hide()
    end)
    self.closeButton = closeBtn

    -- Footer text
    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    footer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    self.footerText = footer

    -- Create visible rows (up to 12)
    self.rows = {}
    for i = 1, 12 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(580, 32)
        row:SetPoint("TOP", title, "BOTTOM", 0, -10 - (i - 1) * 34)
        row:Hide()

        local line1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line1:SetPoint("TOPLEFT", row, "TOPLEFT", 5, 0)
        line1:SetJustifyH("LEFT")

        local line2 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line2:SetPoint("TOPLEFT", line1, "BOTTOMLEFT", 0, -2)
        line2:SetJustifyH("LEFT")

        local line3 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line3:SetPoint("TOPLEFT", line2, "BOTTOMLEFT", 0, -1)
        line3:SetJustifyH("LEFT")

        self.rows[i] = {
            row = row,
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

function ns.FriendsViewer:RefreshData()
    local allFriends = ns.Data:GetAllFriends()
    local entries = {}
    local onlineCount = 0

    for nameRealm, friend in pairs(allFriends) do
        local liveStatus = nil
        if friend.bnetAccountID and ns.BNetLinker then
            liveStatus = ns.BNetLinker:GetLiveStatus(nameRealm)
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

    -- Update footer
    if self.footerText then
        self.footerText:SetText(onlineCount .. " online / " .. #entries .. " tracked")
    end

    self:UpdateRows()
end

function ns.FriendsViewer:UpdateRows()
    for i = 1, 12 do
        local rowData = self.rows[i]
        if not rowData then break end

        local entry = self.displayList[i]
        if entry then
            local friend = entry.friend
            local liveStatus = entry.liveStatus

            -- Line 1: class-colored name + BattleTag
            local coloredName = ns.Utils.GetClassColoredName(friend.characterName, friend.className)
            local line1Text = coloredName
            if friend.bnetTag then
                line1Text = line1Text .. " (" .. friend.bnetTag .. ")"
            end
            rowData.line1:SetText(line1Text)

            -- Line 2: online status or offline
            if entry._isOnline and liveStatus then
                local statusText = "Currently on: " .. (liveStatus.currentCharacter or "?")
                if liveStatus.currentClass then
                    statusText = statusText .. " (" .. liveStatus.currentClass .. ")"
                end
                if liveStatus.zone then
                    statusText = statusText .. " - " .. liveStatus.zone
                end
                rowData.line2:SetText(statusText)
            else
                rowData.line2:SetText("Offline")
            end

            -- Line 3: key stats
            local statsText = (friend.keysCompleted or 0) .. " keys together"
            if friend.highestKeyLevel then
                statsText = statsText .. " | Best: +" .. friend.highestKeyLevel .. " " .. (friend.highestKeyDungeon or "")
            end
            if friend.addedKeyLevel and friend.addedDungeon then
                local dateStr = ""
                if friend.addedTimestamp then
                    dateStr = " (" .. ns.Utils.FormatTimestamp(friend.addedTimestamp) .. ")"
                end
                statsText = statsText .. " | Met: +" .. friend.addedKeyLevel .. " " .. friend.addedDungeon .. dateStr
            end
            rowData.line3:SetText(statsText)

            rowData.row:Show()
        else
            rowData.row:Hide()
        end
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
