-- PetSkillScout launcher: draggable icon, default bottom-right.
local ADDON, PSS = ...
local launcher
local ICON = "Interface\\AddOns\\PetSkillScout\\Textures\\PetSkillScoutLogo"

local function SavePosition(self)
    if not PetSkillScoutDB then return end
    local x, y = self:GetCenter()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if x and y and w > 0 and h > 0 then
        PetSkillScoutDB.launcherPosition = {x = x - w/2, y = y - h/2}
    end
end

local function RestorePosition(self)
    self:ClearAllPoints()
    local pos = PetSkillScoutDB and PetSkillScoutDB.launcherPosition
    if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
        local maxX = math.max(0, UIParent:GetWidth()/2 - 22)
        local maxY = math.max(0, UIParent:GetHeight()/2 - 22)
        local x = math.max(-maxX, math.min(maxX, pos.x))
        local y = math.max(-maxY, math.min(maxY, pos.y))
        self:SetPoint("CENTER", UIParent, "CENTER", x, y)
    else
        self:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -24, 26)
    end
end

function PSS:CreateLauncher()
    if launcher then return launcher end
    launcher = CreateFrame("Button", "PetSkillScoutLauncher", UIParent, "SecureActionButtonTemplate")
    launcher:SetSize(46, 46)
    launcher:SetFrameStrata("HIGH")
    launcher:SetClampedToScreen(true)
    launcher:EnableMouse(true)
    launcher:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    launcher:RegisterForDrag("LeftButton")
    launcher:SetMovable(true)

    local icon = launcher:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(launcher)
    icon:SetTexture(ICON)
    launcher.icon = icon

    local highlight = launcher:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(launcher)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.35)

    launcher:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self.dragging = true
        self:StartMoving()
    end)
    launcher:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
        -- Some clients deliver a click right after the drop. Ignore clicks that
        -- arrive within a short window instead of swallowing the next real click.
        self.dragStopTime = GetTime and GetTime() or 0
    end)
    launcher:SetScript("PostClick", function(self, button, down)
        if not PSS:ClickRan(down) then return end
        if PSS.Net and PSS.Net.AfterJoinClick then PSS.Net:AfterJoinClick() end
        local now = GetTime and GetTime() or 0
        if self.dragStopTime and now - self.dragStopTime < 0.3 then return end
        if button == "LeftButton" and PSS.Open then PSS:Open() end
    end)
    if PSS.Net and PSS.Net.AddJoinButton then PSS.Net:AddJoinButton(launcher) end
    launcher:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(PSS:Safe("PetSkillScout"))
            GameTooltip:AddLine(PSS:Safe(PSS:L("launcherHint")), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end
    end)
    launcher:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    RestorePosition(launcher)
    PSS:CreateMinimapButton()
    PSS:UpdateLaunchers()
    return launcher
end

-- Round button on the minimap edge (left click: open, right click: settings,
-- drag: move around the minimap). The floating launcher above is optional.
local mmButton
local function PlaceMinimapButton()
    if not (mmButton and Minimap) then return end
    -- Secure button (it can join the network): never moved in combat.
    if InCombatLockdown and InCombatLockdown() then return end
    -- With the theme's square minimap the button lives in the addon button
    -- bar: let the theme place it, never back on the round ring.
    local LY = PSS.Layout
    if LY and LY.applied and LY.applied.minimap and (PetSkillScoutDB or {}).skinMinimapBar ~= false then
        if LY.ArrangeButtonBar then pcall(LY.ArrangeButtonBar, LY) end
        return
    end
    local angle = math.rad(tonumber(PetSkillScoutDB and PetSkillScoutDB.minimapAngle) or 215)
    local radius = (Minimap:GetWidth() or 140) / 2 + 10
    local x, y = math.cos(angle), math.sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
      -- Square minimap: walk the edge of the square, not a circle.
      local m = math.max(math.abs(x), math.abs(y))
      x, y = x / m, y / m
      radius = (Minimap:GetWidth() or 140) / 2
    end
    mmButton:ClearAllPoints()
    mmButton:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

PSS.PlaceMinimapButton = function() PlaceMinimapButton() end

function PSS:CreateMinimapButton()
    if mmButton or not Minimap then return mmButton end
    mmButton = CreateFrame("Button", "PetSkillScoutMinimapButton", Minimap, "SecureActionButtonTemplate")
    mmButton:SetSize(31, 31)
    mmButton:SetFrameStrata("MEDIUM")
    mmButton:SetFrameLevel(8)
    mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp", "LeftButtonDown", "RightButtonDown")
    mmButton:RegisterForDrag("LeftButton")
    mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = mmButton:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", mmButton, "TOPLEFT", 7, -5)
    local icon = mmButton:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ICON)
    icon:SetSize(21, 21)
    icon:SetPoint("TOPLEFT", mmButton, "TOPLEFT", 6, -5)
    mmButton.icon = icon
    local border = mmButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", mmButton, "TOPLEFT", 0, 0)
    mmButton:SetScript("OnDragStart", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            if not (mx and px and scale and scale > 0) then return end
            local angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            if PetSkillScoutDB then PetSkillScoutDB.minimapAngle = math.floor(angle * 10 + 0.5) / 10 end
            PlaceMinimapButton()
        end)
    end)
    mmButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    mmButton:SetScript("PostClick", function(_, button, down)
        if not PSS:ClickRan(down) then return end
        if PSS.Net and PSS.Net.AfterJoinClick then PSS.Net:AfterJoinClick() end
        if button == "RightButton" then
            if PSS.UI and PSS.UI.Open then PSS.UI:Open("settings") end
        elseif PSS.Open then
            PSS:Open()
        end
    end)
    if PSS.Net and PSS.Net.AddJoinButton then PSS.Net:AddJoinButton(mmButton) end
    mmButton:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(PSS:Safe("PetSkillScout"))
        GameTooltip:AddLine(PSS:Safe(PSS:L("minimapBtnHint")), 0.8, 0.8, 0.8, true)
        local ammo = PSS.Ammo and PSS.Ammo:StatusText()
        if ammo then GameTooltip:AddLine(PSS:Safe(ammo), 1, 1, 1) end
        if PSS.Net and PSS.Net:ChannelID() then
            GameTooltip:AddLine(PSS:Safe(string.format(PSS:L("rankOnline"), PSS.Net:OnlineCount())), 0.56, 0.78, 1)
        end
        GameTooltip:Show()
    end)
    mmButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    PlaceMinimapButton()
    return mmButton
end

-- Visibility from Settings: minimap button (default on), floating icon (default off).
function PSS:UpdateLaunchers()
    if InCombatLockdown and InCombatLockdown() then return end
    local db = PetSkillScoutDB or {}
    if mmButton then
        if db.minimapButton ~= false then mmButton:Show(); PlaceMinimapButton() else mmButton:Hide() end
    end
    if launcher then
        if db.floatingLauncher == true then launcher:Show() else launcher:Hide() end
    end
end
