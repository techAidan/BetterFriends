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

    -- Icon texture
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(BUTTON_SIZE - 4, BUTTON_SIZE - 4)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\BetterFriends\\icon")
    self.icon = icon

    -- Overlay for highlight
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Border
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(BUTTON_SIZE + 2, BUTTON_SIZE + 2)
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

    -- Dragging support
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")

    btn:SetScript("OnDragStart", function(frame)
        frame._isDragging = true
    end)

    btn:SetScript("OnDragStop", function(frame)
        frame._isDragging = false
        -- Calculate angle from cursor position relative to Minimap center
        -- In the real game, GetCursorPosition() would be used here
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
