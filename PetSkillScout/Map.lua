-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
local PSS = PetSkillScout
PSS.Map = {}

local function NormalizeCoord(v)
  if type(v) ~= "number" then return nil end
  if math.abs(v) > 1 then return v / 100 end
  return v
end

local function HasCoords(beast)
  return beast and beast.verifiedCoords and type(beast.x) == "number" and type(beast.y) == "number"
end

function PSS.Map:CanSetWaypoint(beast)
  -- Forever's client may expose these globals but reject calls; do not treat presence as support.
  return HasCoords(beast) and beast.mapID and C_Map and type(C_Map.SetUserWaypoint) == "function"
     and UiMapPoint and type(UiMapPoint.CreateFromCoordinates) == "function"
end

function PSS.Map:SetWaypoint(beast)
  if not self:CanSetWaypoint(beast) then return false end
  local nx, ny = NormalizeCoord(beast.x), NormalizeCoord(beast.y)
  if not nx or not ny then return false end
  local okPoint, point = pcall(UiMapPoint.CreateFromCoordinates, beast.mapID, nx, ny)
  if not okPoint or not point then return false end
  local ok = pcall(C_Map.SetUserWaypoint, point)
  if ok and C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
    pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
  end
  return ok
end

-- Opens the world map on the beast's zone. The selected beast's spawn points are
-- drawn while it stays selected; it is NOT added to the persistent "Track" list,
-- so the checkbox in the results only changes when the user ticks it.
function PSS.Map:Show(beast)
  if not beast then return end
  PSS.selected = beast
  local hasCoords = HasCoords(beast) and beast.mapID

  -- Open the map first: several clients reset the selected map during OnShow.
  if WorldMapFrame then
    if type(ShowUIPanel) == "function" then
      pcall(ShowUIPanel, WorldMapFrame)
    elseif type(WorldMapFrame.Show) == "function" then
      pcall(WorldMapFrame.Show, WorldMapFrame)
    end
    if hasCoords then
      local set = false
      if type(WorldMapFrame.SetMapID) == "function" then
        set = pcall(WorldMapFrame.SetMapID, WorldMapFrame, beast.mapID)
      end
      if not set and type(SetMapByID) == "function" then
        pcall(SetMapByID, beast.mapID)
      end
    end
  elseif type(ToggleWorldMap) == "function" then
    pcall(ToggleWorldMap)
  end
  self:RefreshTrackedPins()
end

-- Shared world-map canvas helpers (also used by RareMap.lua).
-- Returns canvas, mapID, width, height, scale, or nil when the map is closed.
function PSS.Map:GetCanvasInfo()
  if not (WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()) then return nil end
  local canvas
  if WorldMapFrame.GetCanvas then
    local ok, value = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
    if ok then canvas = value end
  end
  -- Older clients use WorldMapButton/DetailFrame instead of the map canvas API.
  if not canvas then canvas = _G.WorldMapButton or _G.WorldMapDetailFrame end
  if not canvas or not canvas.GetWidth then return nil end
  local mapID
  if type(WorldMapFrame.GetMapID) == "function" then
    local ok, value = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
    if ok then mapID = value end
  end
  local width, height = canvas:GetWidth(), canvas:GetHeight()
  if not width or width <= 0 or not height or height <= 0 then return nil end
  -- The zoomable map scales its canvas; pins counter-scale to keep a fixed size.
  local scale = 1
  if type(WorldMapFrame.GetCanvasScale) == "function" then
    local ok, value = pcall(WorldMapFrame.GetCanvasScale, WorldMapFrame)
    if ok and type(value) == "number" and value > 0 then scale = value end
  end
  return canvas, mapID, width, height, scale
end

-- Pins are drawn one frame strata above the world map with a very high frame
-- level, so map overlays and other addons' pins (HandyNotes, Questie, Leatrix
-- Maps...) can never cover them. Tooltips and menus still stay on top.
local STRATA = {"BACKGROUND","LOW","MEDIUM","HIGH","DIALOG","FULLSCREEN","FULLSCREEN_DIALOG","TOOLTIP"}
function PSS.Map:RaisePin(frame, level)
  local mapStrata = WorldMapFrame and WorldMapFrame.GetFrameStrata and WorldMapFrame:GetFrameStrata() or "HIGH"
  local target = "DIALOG"
  for i, name in ipairs(STRATA) do
    if name == mapStrata then target = STRATA[math.min(i + 1, #STRATA - 1)] break end
  end
  frame:SetFrameStrata(target)
  frame:SetFrameLevel(level or 9000)
  if frame.Raise then frame:Raise() end
end

-- Places a pin at zone percentages x, y. Anchor offsets are measured in the
-- pin's own (counter-scaled) units, so they are divided by the pin scale.
function PSS.Map:Place(pin, canvas, x, y, width, height, scale)
  local k = 1 / math.max(0.2, math.min(5, scale or 1))
  pin:SetScale(k)
  pin:ClearAllPoints()
  pin:SetPoint("CENTER", canvas, "TOPLEFT", (x / 100) * width / k, -(y / 100) * height / k)
end

-- Persistent RareScanner-like pins drawn directly on the world-map canvas.
-- Pins use source spawn points and are shown only on the matching mapID.
local trackedPins, mapRefreshElapsed = {}, 0
local pinsShown = 0
local last = { mapID = false, width = 0, height = 0, scale = 0 }

local function HideTrackedPins()
  if pinsShown == 0 then return end
  for _, pin in ipairs(trackedPins) do pin:Hide() end
  pinsShown = 0
end

local function EnsureTrackedPin(index, canvas)
  local pin = trackedPins[index]
  if not pin then
    pin = CreateFrame("Button", nil, canvas)
    pin:SetSize(20, 20)
    pin.dot = pin:CreateTexture(nil, "ARTWORK")
    pin.dot:SetAllPoints(pin)
    pin.dot:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTaming")
    if pin.dot.SetTexCoord then pin.dot:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    pin.label = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pin.label:SetPoint("LEFT", pin, "RIGHT", 4, 0)
    pin.label:SetTextColor(1, 0.9, 0.25, 1)
    if pin.label.SetFont then
      local font, size = GameFontNormalSmall:GetFont()
      pin.label:SetFont(font, size or 10, "OUTLINE")
    end
    pin.label:Hide()
    pin:SetScript("OnEnter", function(self)
      if self.label then self.label:Show() end
      if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(PSS:Safe(self.beastName or "PetSkillScout"))
        if self.zone then GameTooltip:AddLine(PSS:Safe(self.zone), 0.7, 0.85, 1) end
        if self.ability then
          GameTooltip:AddLine(PSS:Safe(self.ability .. " " .. PSS:L("rank") .. " " .. tostring(self.rank or "?")), 0.4, 1, 0.5)
        end
        if self.px and self.py then GameTooltip:AddLine(PSS:Safe(string.format("%.1f, %.1f", self.px, self.py)), 1, 1, 1) end
        GameTooltip:Show()
      end
    end)
    pin:SetScript("OnLeave", function(self)
      if self.label then self.label:Hide() end
      if GameTooltip then GameTooltip:Hide() end
    end)
    trackedPins[index] = pin
  end
  if pin:GetParent() ~= canvas then pin:SetParent(canvas) end
  PSS.Map:RaisePin(pin, 9000)
  return pin
end

function PSS.Map:RefreshTrackedPins()
  self._trackedPinDirty = true
end

-- Beasts to draw: every tracked one plus the currently selected one.
local function PinSources(mapID)
  local list, seen = {}, {}
  local tracked = PetSkillScoutDB and PetSkillScoutDB.tracked or {}
  local selected = PSS.selected
  local function consider(beast, isSelected)
    if not beast or seen[beast.id] or not HasCoords(beast) then return end
    local legacyMatch = not mapID and isSelected
    if beast.mapID == mapID or legacyMatch then
      seen[beast.id] = true
      table.insert(list, beast)
    end
  end
  for _, beast in ipairs(PSS.Beasts or {}) do
    if tracked[beast.id] then consider(beast, selected and selected.id == beast.id) end
  end
  -- Beasts tracked from the Beasts tab are Atlas records ("atlas-<npc>").
  if PSS.Atlas and next(tracked) then
    PSS.Atlas:Build()
    for _, rec in ipairs(PSS.Atlas.list) do
      if tracked[rec.id] then consider(rec, selected and selected.id == rec.id) end
    end
  end
  -- The selected beast may be a rare-catalogue record that is not in PSS.Beasts.
  -- Rare pets have their own area overlay (RareMap.lua).
  if not (selected and selected.rare) then consider(selected, true) end
  return list
end

local function UpdateTrackedPins()
  local canvas, mapID, width, height, scale = PSS.Map:GetCanvasInfo()
  if not canvas then
    HideTrackedPins()
    last.mapID = false
    return
  end

  -- Only re-lay pins when something actually changed.
  if not PSS.Map._trackedPinDirty and last.mapID == mapID
     and last.width == width and last.height == height and last.scale == scale then
    return
  end
  last.mapID, last.width, last.height, last.scale = mapID, width, height, scale

  local used = 0
  for _, beast in ipairs(PinSources(mapID)) do
    local points = beast.spawnPoints or {{beast.x, beast.y}}
    local abilityName = beast.ability and PSS:NameAbility(beast.ability) or nil
    for _, point in ipairs(points) do
      local x, y = tonumber(point[1]), tonumber(point[2])
      if x and y then
        if math.abs(x) <= 1 then x = x * 100 end
        if math.abs(y) <= 1 then y = y * 100 end
        used = used + 1
        local pin = EnsureTrackedPin(used, canvas)
        pin.beastName, pin.zone = beast.name, beast.zone
        pin.label:SetText(beast.name or "Pet")
        pin.ability, pin.rank = abilityName, beast.rank
        pin.px, pin.py = x, y
        PSS.Map:Place(pin, canvas, x, y, width, height, scale)
        pin:Show()
      end
    end
  end
  for i = used + 1, #trackedPins do trackedPins[i]:Hide() end
  pinsShown = used
  PSS.Map._trackedPinDirty = false
end

local pinDriver = CreateFrame("Frame")
PSS:OnlyWithWorldMap(pinDriver)
PSS.Map._driver = pinDriver
pinDriver:SetScript("OnUpdate", function(_, elapsed)
  mapRefreshElapsed = mapRefreshElapsed + (elapsed or 0)
  if mapRefreshElapsed < 0.25 then return end
  mapRefreshElapsed = 0
  local ok, err = pcall(UpdateTrackedPins)
  if not ok and PSS.Map then PSS.Map._lastPinError = tostring(err) end
end)
pinDriver.pssKey = "Map pins"
PSS:Every(pinDriver, 0.25)
