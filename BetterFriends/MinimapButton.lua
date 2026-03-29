local addonName, ns = ...

ns.MinimapButton = {}

local RADIUS = 80
local BUTTON_SIZE = 32

function ns.MinimapButton:Create()
    if self.button then return end

    local btn = CreateFrame("Button", "BetterFriendsMinimapButton", Minimap)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Icon texture (use a built-in WoW icon — the friends list icon)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(BUTTON_SIZE - 4, BUTTON_SIZE - 4)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\Achievement_guildperk_everybodysfriend")
    self.icon = icon

    -- Highlight overlay
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Minimap button border (round border that matches other minimap buttons)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(BUTTON_SIZE + 12, BUTTON_SIZE + 12)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Click handler
    btn:SetScript("OnClick", function(frame, mouseButton)
        if mouseButton == "LeftButton" then
            if ns.FriendsViewer then
                ns.FriendsViewer:Toggle()
            end
        end
    end)

    -- Tooltip
    btn:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFF00CCFFBetterFriends|r")
        local totalCount = 0
        if ns.Data and BetterFriendsDB and BetterFriendsDB.friends then
            for _ in pairs(BetterFriendsDB.friends) do
                totalCount = totalCount + 1
            end
        end
        GameTooltip:AddLine("Tracking " .. totalCount .. " friends", 1, 1, 1)
        GameTooltip:AddLine("Left-click to open", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Dragging — repositions button around the minimap edge
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")

    btn:SetScript("OnDragStart", function(frame)
        frame._isDragging = true
        frame:SetScript("OnUpdate", function(self)
            if not self._isDragging then return end
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.atan2(cy - my, cx - mx)
            local x = math.cos(angle) * RADIUS
            local y = math.sin(angle) * RADIUS
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", x, y)
            -- Store angle in degrees
            ns.MinimapButton._dragAngle = math.deg(angle)
        end)
    end)

    btn:SetScript("OnDragStop", function(frame)
        frame._isDragging = false
        frame:SetScript("OnUpdate", nil)
        -- Save the final angle
        if ns.MinimapButton._dragAngle then
            local settings = ns.Data:GetSettings()
            settings.minimapButtonPosition = ns.MinimapButton._dragAngle
        end
    end)

    self.button = btn
    self:UpdatePosition()
end

function ns.MinimapButton:UpdatePosition()
    if not self.button then return end

    local settings = ns.Data:GetSettings()
    local angle = math.rad(settings.minimapButtonPosition or 220)
    local x = math.cos(angle) * RADIUS
    local y = math.sin(angle) * RADIUS

    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function ns.MinimapButton:UpdateVisibility()
    if not self.button then return end

    local settings = ns.Data:GetSettings()
    if settings.minimapButtonShown then
        self.button:Show()
    else
        self.button:Hide()
    end
end

function ns.MinimapButton:GetAngle()
    local settings = ns.Data:GetSettings()
    return settings.minimapButtonPosition
end

function ns.MinimapButton:SetAngle(angle)
    local settings = ns.Data:GetSettings()
    settings.minimapButtonPosition = angle
    self:UpdatePosition()
end

-- Register for PLAYER_LOGIN to create and show the button
ns:RegisterEvent("PLAYER_LOGIN", ns.MinimapButton, function(self)
    self:Create()
    self:UpdateVisibility()
end)
