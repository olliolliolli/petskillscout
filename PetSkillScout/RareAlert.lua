-- Rare pet alert pop-up with a 3D portrait (RareScanner style), shown at the
-- bottom of the screen when the radar spots a rare. Not a secure frame, so it
-- can appear in combat; left-click shows the spawn area on the map.
local PSS = PetSkillScout
PSS.RareAlert = {}
local RA = PSS.RareAlert
local frame
local SHOW_SECONDS = 45
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"

local function Solid(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture("Interface\\Buttons\\WHITE8X8")
  t:SetVertexColor(r, g, b, a or 1)
  return t
end

local function Text(parent, size, r, g, b)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetFont(FONT, size, "")
  fs:SetTextColor(r, g, b)
  fs:SetJustifyH("LEFT")
  return fs
end

local function SavePosition(self)
  if not PetSkillScoutDB then return end
  local x, y = self:GetCenter()
  if x and y then PetSkillScoutDB.rareAlertPos = { x = x, y = y } end
end

local function Create()
  if frame then return frame end
  frame = CreateFrame("Button", "PetSkillScoutRareAlert", UIParent)
  frame:SetSize(330, 98)
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local pos = PetSkillScoutDB and PetSkillScoutDB.rareAlertPos
  if pos and pos.x and pos.y then
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
  else
    frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
  end

  local border = Solid(frame, "BACKGROUND", 0.71, 0.57, 0.96, 1)
  border:SetAllPoints(frame)
  local bg = Solid(frame, "BORDER", 0.05, 0.07, 0.09, 0.96)
  bg:SetPoint("TOPLEFT", 2, -2)
  bg:SetPoint("BOTTOMRIGHT", -2, 2)

  -- Portrait box with the creature model.
  local box = CreateFrame("Frame", nil, frame)
  box:SetSize(84, 84)
  box:SetPoint("LEFT", frame, "LEFT", 7, 0)
  local boxBg = Solid(box, "BACKGROUND", 0.10, 0.08, 0.16, 1)
  boxBg:SetAllPoints(box)
  frame.model = CreateFrame("PlayerModel", nil, box)
  frame.model:SetPoint("TOPLEFT", 1, -1)
  frame.model:SetPoint("BOTTOMRIGHT", -1, 1)

  frame.header = Text(frame, 10, 0.71, 0.57, 0.96)
  frame.header:SetPoint("TOPLEFT", box, "TOPRIGHT", 10, -2)
  frame.name = Text(frame, 16, 1, 0.82, 0.25)
  frame.name:SetPoint("TOPLEFT", frame.header, "BOTTOMLEFT", 0, -3)
  frame.name:SetWidth(215)
  frame.info = Text(frame, 11, 0.85, 0.85, 0.85)
  frame.info:SetPoint("TOPLEFT", frame.name, "BOTTOMLEFT", 0, -3)
  frame.info:SetWidth(215)
  frame.status = Text(frame, 11, 0.42, 0.86, 0.48)
  frame.status:SetPoint("TOPLEFT", frame.info, "BOTTOMLEFT", 0, -2)
  frame.hint = Text(frame, 9, 0.55, 0.55, 0.6)
  frame.hint:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 10, 1)
  frame.hint:SetWidth(215)

  local close = CreateFrame("Button", nil, frame)
  close:SetSize(18, 18)
  close:SetPoint("TOPRIGHT", -4, -4)
  local x = Text(close, 13, 0.8, 0.8, 0.8)
  x:SetPoint("CENTER")
  x:SetText("x")
  close:SetScript("OnClick", function() frame:Hide() end)
  -- Arrow to the rare's nearest spawn point.
  local nav = CreateFrame("Button", nil, frame)
  nav:SetSize(18, 18)
  nav:SetPoint("TOPRIGHT", close, "BOTTOMRIGHT", 0, -4)
  local navIcon = nav:CreateTexture(nil, "ARTWORK")
  navIcon:SetTexture("Interface\\Minimap\\MinimapArrow")
  navIcon:SetAllPoints(nav)
  nav:SetScript("OnClick", function()
    if frame.entry and PSS.Nav then PSS.Nav:SetTarget(PSS.Nav:TargetFromBeast(frame.entry.beast)) end
  end)
  frame.nav = nav

  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(self)
    self.dragStop = GetTime and GetTime() or 0
  end)
  frame:SetScript("OnClick", function(self, button)
    if self.dragStop and GetTime and GetTime() - self.dragStop < 0.3 then return end
    if button == "RightButton" then self:Hide(); return end
    if self.entry and PSS.RareMap and self.entry.beast.mapID then PSS.RareMap:Focus(self.entry) end
  end)
  frame:SetScript("OnUpdate", function(self, elapsed)
    self.remaining = (self.remaining or 0) - (elapsed or 0)
    -- Model fallback: a unit model can be blank when the unit left view.
    if self.checkModel then
      self.checkModel = self.checkModel - (elapsed or 0)
      if self.checkModel <= 0 then
        self.checkModel = nil
        local m = self.model
        local ok, file = false, nil
        if type(m.GetModelFileID) == "function" then ok, file = pcall(m.GetModelFileID, m) end
        if ok and (not file or file == 0) then RA:SetModel(self.entry, nil) end
      end
    end
    -- Stay while hovered; otherwise fade out over the last second.
    if self:IsMouseOver() then self.remaining = math.max(self.remaining, 3) end
    if self.remaining <= 1 then self:SetAlpha(math.max(0, self.remaining)) else self:SetAlpha(1) end
    if self.remaining <= 0 then self:Hide() end
  end)
  frame:Hide()
  return frame
end

function RA:SetModel(entry, unit)
  local m = frame.model
  local b = entry.beast
  if m.ClearModel then pcall(m.ClearModel, m) end
  local ok = false
  if unit and UnitExists and UnitExists(unit) and m.SetUnit then ok = pcall(m.SetUnit, m, unit) end
  if not ok and b.displayID and m.SetDisplayInfo then ok = pcall(m.SetDisplayInfo, m, b.displayID) end
  if not ok and b.npcID and m.SetCreature then ok = pcall(m.SetCreature, m, b.npcID) end
  if m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, 0) end
  if m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, 1.15) end
  if m.SetFacing then pcall(m.SetFacing, m, math.rad(-25)) end
  if unit then frame.checkModel = 0.8 end
end

function RA:Show(entry, unit)
  if not entry then return end
  Create()
  local R = PSS.RarePets
  frame.entry = entry
  frame.header:SetText(PSS:L("rareAlertHeader"))
  frame.name:SetText(entry.name)
  local level = entry.minLevel and (entry.maxLevel and entry.maxLevel ~= entry.minLevel and (entry.minLevel .. "-" .. entry.maxLevel) or tostring(entry.minLevel)) or "?"
  frame.info:SetText((entry.family and PSS:NameFamily(entry.family) or "?") .. "  ·  " .. PSS:L("level") .. " " .. level ..
    "  ·  " .. (entry.zone or "?"))
  local status
  if R:IsCollected(entry) then status = "|cff6bdb7a" .. PSS:L("rareTamed") .. "|r"
  elseif R:IsWanted(entry) then status = "|cfff0c25e" .. PSS:L("rareWant") .. "|r" end
  if entry.elite then status = (status and status .. "  " or "") .. "|cffff8040" .. PSS:L("rareElite") .. "|r" end
  if entry.new then status = (status and status .. "  " or "") .. "|cffb592f5" .. PSS:L("rareNew") .. "|r" end
  frame.status:SetText(status or "")
  frame.hint:SetText(PSS:L("rareAlertHint"))
  frame.remaining = SHOW_SECONDS
  frame:SetAlpha(1)
  frame:Show()
  self:SetModel(entry, unit)
end

-- /pss raretest: preview the pop-up with a rare from the catalogue.
function RA:Test()
  local R = PSS.RarePets
  if not R then return end
  if not R.entries or #R.entries == 0 then R:Build() end
  local list = R.entries
  if #list == 0 then return end
  self:Show(list[math.random(1, #list)], nil)
end
