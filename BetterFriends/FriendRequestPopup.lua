local addonName, ns = ...

ns.FriendRequestPopup = {}
ns.FriendRequestPopup.sentThisSession = {}

function ns.FriendRequestPopup:Create()
    if self.frame then return end

    local frame = CreateFrame("Frame", "BetterFriendsPopupFrame")
    frame:SetSize(300, 250)
    frame:SetPoint("CENTER")
    frame:Hide()

    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText("BetterFriends")
    self.titleText = title

    -- Dungeon info text
    local dungeonInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonInfo:SetPoint("TOP", title, "BOTTOM", 0, -5)
    self.dungeonInfoText = dungeonInfo

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeBtn:SetText("X")
    closeBtn:SetScript("OnClick", function()
        ns.FriendRequestPopup:Hide()
    end)
    self.closeButton = closeBtn

    -- Member rows
    self.memberRows = {}
    for i = 1, 4 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(280, 24)
        row:SetPoint("TOP", dungeonInfo, "BOTTOM", 0, -5 - (i - 1) * 28)
        row:Hide()

        local roleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        roleText:SetPoint("LEFT", row, "LEFT", 5, 0)

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", roleText, "RIGHT", 5, 0)

        local addButton = CreateFrame("Button", nil, row)
        addButton:SetSize(80, 20)
        addButton:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        addButton:SetText("Add Friend")
        addButton:Hide()

        local statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
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

    -- Add All button
    local addAllBtn = CreateFrame("Button", nil, frame)
    addAllBtn:SetSize(100, 24)
    addAllBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 30)
    addAllBtn:SetText("Add All")
    addAllBtn:SetScript("OnClick", function()
        ns.FriendRequestPopup:OnAddAll()
    end)
    self.addAllButton = addAllBtn

    -- Timer text
    local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timerText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
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
