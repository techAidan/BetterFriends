local addonName, ns = ...

ns.FriendRequestPopup = {}
ns.FriendRequestPopup.sentThisSession = {}

function ns.FriendRequestPopup:Create()
    if self.frame then return end

    -- Main frame with backdrop for visibility
    local frame = CreateFrame("Frame", "BetterFriendsPopupFrame", UIParent, "BackdropTemplate")
    frame:SetSize(380, 310)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

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

    -- Dungeon info text
    local dungeonInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonInfo:SetPoint("TOP", title, "BOTTOM", 0, -4)
    self.dungeonInfoText = dungeonInfo

    -- Close button (uses built-in Blizzard close button template)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        ns.FriendRequestPopup:Hide()
    end)
    self.closeButton = closeBtn

    -- Member rows
    self.memberRows = {}
    local rowAnchor = dungeonInfo
    for i = 1, 4 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(356, 28)
        if i == 1 then
            row:SetPoint("TOPLEFT", dungeonInfo, "BOTTOMLEFT", -80, -8)
        else
            row:SetPoint("TOP", self.memberRows[i - 1].row, "BOTTOM", 0, -2)
        end
        row:Hide()

        -- Role icon + name on the left
        local roleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        roleText:SetPoint("LEFT", row, "LEFT", 8, 0)
        roleText:SetWidth(70)
        roleText:SetJustifyH("LEFT")

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", roleText, "RIGHT", 4, 0)
        nameText:SetWidth(110)
        nameText:SetJustifyH("LEFT")

        -- Add Friend button on the right (uses Blizzard button template)
        local addButton = CreateFrame("Button", "BFPopupAddBtn" .. i, row, "UIPanelButtonTemplate")
        addButton:SetSize(90, 22)
        addButton:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        addButton:SetText("Add Friend")
        addButton:Hide()

        -- Status text (shown instead of button for already-tracked friends)
        local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        statusText:SetTextColor(0.5, 1, 0.5)
        statusText:Hide()

        self.memberRows[i] = {
            row = row,
            roleText = roleText,
            nameText = nameText,
            addButton = addButton,
            statusText = statusText,
            memberInfo = nil,
        }
    end

    -- Add All button at the bottom (uses Blizzard button template)
    local addAllBtn = CreateFrame("Button", "BFPopupAddAllBtn", frame, "UIPanelButtonTemplate")
    addAllBtn:SetSize(110, 26)
    addAllBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 32)
    addAllBtn:SetText("Add All")
    addAllBtn:SetScript("OnClick", function()
        ns.FriendRequestPopup:OnAddAll()
    end)
    self.addAllButton = addAllBtn

    -- Timer text
    local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
    timerText:SetTextColor(0.6, 0.6, 0.6)
    self.timerText = timerText

    self.frame = frame
end

function ns.FriendRequestPopup:Show(completionData)
    if not self.frame then
        self:Create()
    end

    self.completionData = completionData

    -- Set dungeon info
    local timedStr = completionData.onTime and "Timed!" or "Depleted"
    local infoStr = "+" .. completionData.keyLevel .. " " .. completionData.dungeonName .. " - " .. timedStr
    self.dungeonInfoText:SetText(infoStr)

    -- Populate member rows
    for i = 1, 4 do
        local rowData = self.memberRows[i]
        local member = completionData.members[i]

        if member then
            -- Role text
            local roleIcon = ns.Utils.GetRoleIcon(member.role)
            local roleName = ns.Utils.GetRoleDisplayName(member.role)
            rowData.roleText:SetText(roleIcon .. " " .. roleName)

            -- Class-colored name
            local coloredName = ns.Utils.GetClassColoredName(member.name, member.classToken)
            rowData.nameText:SetText(coloredName)

            -- Store member info for button click
            rowData.memberInfo = member

            -- Set button for add row click handler
            rowData.addButton:SetScript("OnClick", function()
                ns.FriendRequestPopup:OnAddFriend(member)
            end)

            -- Check if already a friend
            if ns.Data:IsFriend(member.nameRealm) then
                rowData.addButton:Hide()
                local friend = ns.Data:GetFriend(member.nameRealm)
                rowData.statusText:SetText("Friend (+" .. friend.highestKeyLevel .. " " .. friend.highestKeyDungeon .. ")")
                rowData.statusText:Show()
            else
                rowData.addButton:SetText("Add Friend")
                rowData.addButton:Show()
                rowData.statusText:Hide()
            end

            rowData.row:Show()
        else
            rowData.row:Hide()
        end
    end

    self.frame:Show()
end

function ns.FriendRequestPopup:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function ns.FriendRequestPopup:OnAddFriend(memberInfo)
    local nameRealm = memberInfo.nameRealm

    -- Prevent duplicate sends
    if self.sentThisSession[nameRealm] then
        return
    end

    -- Send BNet friend invite
    BNSendFriendInvite(memberInfo.name .. "-" .. memberInfo.realm)

    -- Store in Data
    ns.Data:AddFriend(nameRealm, {
        characterName = memberInfo.name,
        realm = memberInfo.realm,
        className = memberInfo.classToken,
        classDisplayName = memberInfo.classDisplayName,
        role = memberInfo.role,
        addedDungeon = self.completionData.dungeonName,
        addedKeyLevel = self.completionData.keyLevel,
    })

    -- Notify BNetLinker
    if ns.BNetLinker then
        ns.BNetLinker:SnapshotBNetFriends()
        ns.BNetLinker:AddPendingInvite(nameRealm)
    end

    -- Mark as sent
    self.sentThisSession[nameRealm] = true
end

function ns.FriendRequestPopup:OnAddAll()
    if not self.completionData or not self.completionData.members then
        return
    end

    for _, member in ipairs(self.completionData.members) do
        if not ns.Data:IsFriend(member.nameRealm) and not self.sentThisSession[member.nameRealm] then
            self:OnAddFriend(member)
        end
    end
end
