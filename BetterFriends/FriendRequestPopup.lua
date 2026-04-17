local addonName, ns = ...

ns.FriendRequestPopup = {}
ns.FriendRequestPopup.sentThisSession = {}
ns.FriendRequestPopup.pendingVerifiedInvites = {} -- queue for BATTLETAG_INVITE_SHOW

local function DebugPrint(...)
    if ns.DebugLog then
        ns.DebugLog:Log("Popup", ...)
    else
        print("|cFF00CCFFBetterFriends [Popup]:|r", ...)
    end
end

function ns.FriendRequestPopup:Create()
    if self.frame then return end

    -- Main frame with clean tooltip-style backdrop
    local frame = CreateFrame("Frame", "BetterFriendsPopupFrame", UIParent, "BackdropTemplate")
    frame:SetSize(390, 340)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)

    -- Modern tooltip-style backdrop (thinner border, cleaner look)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
    frame:Hide()

    -- Title text
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("|cFF00CCFFBetterFriends|r")
    self.titleText = title

    -- Separator 1: below title
    local sep1 = frame:CreateTexture(nil, "ARTWORK")
    sep1:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    sep1:SetSize(340, 1)
    sep1:SetPoint("TOP", title, "BOTTOM", 0, -6)

    -- Dungeon info text
    local dungeonInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dungeonInfo:SetPoint("TOP", sep1, "BOTTOM", 0, -10)
    self.dungeonInfoText = dungeonInfo

    -- Separator 2: below dungeon info
    local sep2 = frame:CreateTexture(nil, "ARTWORK")
    sep2:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    sep2:SetSize(340, 1)
    sep2:SetPoint("TOP", dungeonInfo, "BOTTOM", 0, -8)

    -- Close button (uses built-in Blizzard close button template)
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        ns.FriendRequestPopup:Hide()
    end)
    self.closeButton = closeBtn

    -- Member rows
    self.memberRows = {}
    for i = 1, 4 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(360, 34)
        row:EnableMouse(true)
        if i == 1 then
            -- Anchor centered to the separator so the row sits inside the frame
            row:SetPoint("TOP", sep2, "BOTTOM", 0, -6)
        else
            row:SetPoint("TOP", self.memberRows[i - 1].row, "BOTTOM", 0, -1)
        end
        row:Hide()

        -- Alternating row background (even rows get subtle zebra stripe)
        if i % 2 == 0 then
            local bgTex = row:CreateTexture(nil, "BACKGROUND")
            bgTex:SetColorTexture(1, 1, 1, 0.03)
            bgTex:SetAllPoints(row)
        end

        -- Hover highlight (all rows)
        local hoverTex = row:CreateTexture(nil, "BACKGROUND")
        hoverTex:SetColorTexture(1, 1, 1, 0.08)
        hoverTex:SetAllPoints(row)
        hoverTex:Hide()

        row:SetScript("OnEnter", function() hoverTex:Show() end)
        row:SetScript("OnLeave", function() hoverTex:Hide() end)

        -- Role icon + name on the left
        local roleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        roleText:SetPoint("LEFT", row, "LEFT", 8, 0)
        roleText:SetWidth(55)
        roleText:SetJustifyH("LEFT")

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", roleText, "RIGHT", 2, 0)
        -- Width expanded from 170 so the optional alt-cluster annotation
        -- ("alt of Urazall (3 keys)") can render inline after the name
        -- without clipping against the Add Friend button.
        nameText:SetWidth(200)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)

        -- Add Friend button on the right (uses Blizzard button template)
        local addButton = CreateFrame("Button", "BFPopupAddBtn" .. i, row, "UIPanelButtonTemplate")
        addButton:SetSize(85, 22)
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
            hoverTexture = hoverTex,
            memberInfo = nil,
        }
    end

    -- Separator 3: above Add All button
    local sep3 = frame:CreateTexture(nil, "ARTWORK")
    sep3:SetColorTexture(0.3, 0.3, 0.3, 0.6)
    sep3:SetSize(340, 1)
    sep3:SetPoint("BOTTOM", frame, "BOTTOM", 0, 58)

    -- Add All button at the bottom (uses Blizzard button template)
    local addAllBtn = CreateFrame("Button", "BFPopupAddAllBtn", frame, "UIPanelButtonTemplate")
    addAllBtn:SetSize(120, 26)
    addAllBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 30)
    addAllBtn:SetText("Add All")
    addAllBtn:SetScript("OnClick", function()
        ns.FriendRequestPopup:OnAddAll()
    end)
    self.addAllButton = addAllBtn

    -- Timer text
    local timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
    timerText:SetTextColor(0.6, 0.6, 0.6)
    self.timerText = timerText

    self.frame = frame
end

function ns.FriendRequestPopup:Show(completionData)
    if not self.frame then
        self:Create()
    end

    self.completionData = completionData

    -- Set dungeon info with colored key level and timed/depleted status
    local timedColor = completionData.onTime and "|cFF00FF00" or "|cFFFF4444"
    local timedStr = completionData.onTime and "Timed!" or "Depleted"
    local infoStr = "|cFFFFD100+" .. completionData.keyLevel .. "|r  "
        .. completionData.dungeonName .. "  -  "
        .. timedColor .. timedStr .. "|r"
    self.dungeonInfoText:SetText(infoStr)

    -- Build the BNet character lookup once per Show so we can annotate
    -- untracked members whose BNet is already in a cluster with someone
    -- we know. Empty table if BNetLinker isn't loaded (e.g. tests).
    local bnetMap = {}
    if ns.BNetLinker and ns.BNetLinker.BuildCharacterLookup then
        bnetMap = ns.BNetLinker:BuildCharacterLookup()
    end

    -- Populate member rows
    for i = 1, 4 do
        local rowData = self.memberRows[i]
        local member = completionData.members[i]

        if member then
            -- Role text
            local roleIcon = ns.Utils.GetRoleIcon(member.role)
            local roleName = ns.Utils.GetRoleDisplayName(member.role)
            rowData.roleText:SetText(roleIcon .. " " .. roleName)

            -- Class-colored name, plus an optional "alt of <primary>" tag
            -- when this member isn't tracked but their BNet account
            -- already has a tracked character in it. N is the cluster-
            -- wide keysCompleted total so the user knows how familiar
            -- this person is, regardless of which alt we met them on.
            local coloredName = ns.Utils.GetClassColoredName(member.name, member.classToken)
            local isFriend = ns.Data:IsFriend(member.nameRealm)

            local altAnnotation = ""
            if not isFriend then
                local match = bnetMap[member.nameRealm]
                if match and match.accountID then
                    local primaryNR = ns.Data:GetPrimaryByBNetAccountID(match.accountID)
                    if primaryNR then
                        local primary = ns.Data:GetFriend(primaryNR)
                        local total = ns.Data:GetClusterKeyTotal(primaryNR)
                        local keysLabel = (total == 1) and "1 key" or (total .. " keys")
                        altAnnotation = "  |cFFAAAAAAalt of "
                            .. (primary.characterName or "?")
                            .. " (" .. keysLabel .. ")|r"
                    end
                end
            end
            rowData.nameText:SetText(coloredName .. altAnnotation)

            -- Store member info for button click
            rowData.memberInfo = member

            -- Set button for add row click handler
            rowData.addButton:SetScript("OnClick", function()
                ns.FriendRequestPopup:OnAddFriend(member)
            end)

            -- Check if already a friend
            if isFriend then
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
    DebugPrint("OnAddFriend called for:", memberInfo.name, "-", memberInfo.realm)

    -- Prevent duplicate sends
    if self.sentThisSession[nameRealm] then
        DebugPrint("Already sent this session, skipping:", nameRealm)
        return
    end

    -- Use the verified BattleTag invite flow (unit-based)
    -- This is how Blizzard's right-click "Add BattleTag Friend" works
    local unitID = memberInfo.unitID
    if unitID then
        DebugPrint("Using verified invite flow for unit:", unitID)
        local ok, err = pcall(function()
            -- Queue this invite so BATTLETAG_INVITE_SHOW handler knows what to do
            self.pendingVerifiedInvites[nameRealm] = memberInfo
            BNCheckBattleTagInviteToUnit(unitID)
        end)
        if ok then
            DebugPrint("BNCheckBattleTagInviteToUnit sent for:", unitID)
        else
            DebugPrint("BNCheckBattleTagInviteToUnit FAILED:", tostring(err))
            self.pendingVerifiedInvites[nameRealm] = nil
        end
    else
        DebugPrint("No unitID available for:", memberInfo.name, "- cannot send verified invite")
        DebugPrint("Use /btf link <name-realm> <BattleTag#1234> to manually add")
    end

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

    -- Update button to show "Sending..." feedback (will update to "Sent!" on BATTLETAG_INVITE_SHOW)
    for _, rowData in ipairs(self.memberRows) do
        if rowData.memberInfo and rowData.memberInfo.nameRealm == nameRealm then
            rowData.addButton:SetText("|cFFFFFF00Sending...|r")
            rowData.addButton:Disable()
            DebugPrint("Updated button to Sending... for:", nameRealm)
        end
    end
end

-- Handle BATTLETAG_INVITE_SHOW: server confirmed the BattleTag lookup, now send the actual invite
function ns.FriendRequestPopup:OnBattleTagInviteShow()
    DebugPrint("BATTLETAG_INVITE_SHOW fired — sending verified invite")

    local ok, err = pcall(BNSendVerifiedBattleTagInvite)
    if ok then
        DebugPrint("BNSendVerifiedBattleTagInvite succeeded")
    else
        DebugPrint("BNSendVerifiedBattleTagInvite FAILED:", tostring(err))
    end

    -- Update any "Sending..." buttons to "Sent!"
    -- (We don't know exactly which invite this corresponds to, so update all pending)
    for nameRealm, _ in pairs(self.pendingVerifiedInvites) do
        for _, rowData in ipairs(self.memberRows) do
            if rowData.memberInfo and rowData.memberInfo.nameRealm == nameRealm then
                rowData.addButton:SetText("|cFF00FF00Sent!|r")
                DebugPrint("Updated button to Sent! for:", nameRealm)
            end
        end
    end
    -- Clear the first pending invite (FIFO)
    for nameRealm, _ in pairs(self.pendingVerifiedInvites) do
        self.pendingVerifiedInvites[nameRealm] = nil
        break
    end
end

function ns.FriendRequestPopup:OnAddAll()
    if not self.completionData or not self.completionData.members then
        return
    end

    DebugPrint("OnAddAll called")
    local count = 0
    for _, member in ipairs(self.completionData.members) do
        if not ns.Data:IsFriend(member.nameRealm) and not self.sentThisSession[member.nameRealm] then
            self:OnAddFriend(member)
            count = count + 1
        end
    end
    DebugPrint("OnAddAll sent", count, "invites")

    -- Update Add All button
    self.addAllButton:SetText("|cFF00FF00Sent All!|r")
    self.addAllButton:Disable()
end

-- Register for BATTLETAG_INVITE_SHOW event
ns:RegisterEvent("BATTLETAG_INVITE_SHOW", ns.FriendRequestPopup, function(self, event)
    ns.FriendRequestPopup:OnBattleTagInviteShow()
end)
