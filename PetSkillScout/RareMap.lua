-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Rare pets on the world map (RareScanner style).
-- * Every rare with known spawns gets one icon on its zone map.
-- * Clicking an icon shows its spawn area: all spawn points plus an outline.
-- * Shift-click sets a map waypoint where the client supports it.
local PSS = PetSkillScout
PSS.RareMap = { focus = nil }
local RM = PSS.RareMap

local iconPins, dotPins, lines = {}, {}, {}
local areaFrame
local elapsedSince, dirty = 0, true
local last = { mapID = false, width = 0, height = 0, scale = 0 }

-- Icon size setting (Settings > Map): small / medium / large.
local ICON_SIZES = { s = 16, m = 20, l = 24 }

local function Enabled()
  return not PetSkillScoutDB or PetSkillScoutDB.rareMapPins ~= false
end

local function Entries()
  local R = PSS.RarePets
  if not R then return {} end
  if PSS.zoneMapsChanged or not R.entries or #R.entries == 0 then
    PSS.zoneMapsChanged = false
    R:Build()
  end
  return R.entries
end

function RM:Refresh() dirty = true end

local function HideAll()
  for _, p in ipairs(iconPins) do p:Hide() end
  for _, p in ipairs(dotPins) do p:Hide() end
  for _, l in ipairs(lines) do l:Hide() end
end

local function Tooltip(pin)
  local e = pin.entry
  if not (e and GameTooltip) then return end
  local R = PSS.RarePets
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  GameTooltip:AddLine(PSS:Safe(e.name), 1, 0.82, 0.25)
  local level = e.minLevel and (e.maxLevel and e.maxLevel ~= e.minLevel and (e.minLevel .. "-" .. e.maxLevel) or tostring(e.minLevel)) or "?"
  GameTooltip:AddLine(PSS:Safe((e.family and PSS:NameFamily(e.family) or "?") .. "  ·  " .. PSS:L("level") .. " " .. level), 0.85, 0.85, 0.85)
  if e.elite then GameTooltip:AddLine(PSS:Safe(PSS:L("rareElite")), 1, 0.5, 0.25) end
  if e.new then GameTooltip:AddLine(PSS:Safe(PSS:L("rareNew")), 0.71, 0.57, 0.96) end
  if R:IsCollected(e) then GameTooltip:AddLine(PSS:Safe(PSS:L("rareTamed")), 0.42, 0.86, 0.48)
  elseif R:IsWanted(e) then GameTooltip:AddLine(PSS:Safe(PSS:L("rareWant")), 0.94, 0.76, 0.37) end
  GameTooltip:AddLine(PSS:Safe(string.format(PSS:L("rareSpawnCount"), #(e.beast.spawnPoints or {}))), 0.7, 0.85, 1)
  local seen = R:SeenText(e)
  if seen then GameTooltip:AddLine(PSS:Safe(seen), 0.8, 0.8, 0.8) end
  local shared = PSS.Sync and PSS.Sync:Text(e)
  if shared then GameTooltip:AddLine(PSS:Safe(shared), 0.56, 0.78, 1) end
  GameTooltip:AddLine(PSS:Safe(PSS:L("rareMapHint")), 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function EnsureIcon(i, canvas)
  local pin = iconPins[i]
  if not pin then
    pin = CreateFrame("Button", nil, canvas)
    pin:SetSize(16, 16)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin.ring = pin:CreateTexture(nil, "BACKGROUND")
    pin.ring:SetPoint("TOPLEFT", -2, 2)
    pin.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    pin.ring:SetTexture("Interface\\Buttons\\WHITE8X8")
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints(pin)
    pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pin.glow = pin:CreateTexture(nil, "HIGHLIGHT")
    pin.glow:SetAllPoints(pin)
    pin.glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    pin.glow:SetBlendMode("ADD")
    pin:SetScript("OnEnter", Tooltip)
    pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    pin:SetScript("OnClick", function(self, button)
      local e = self.entry
      if not e then return end
      if button == "RightButton" then
        if RM.focus == e.beast.npcID then RM.focus = nil end
      elseif IsControlKeyDown and IsControlKeyDown() then
        if PSS.Nav then PSS.Nav:SetTarget(PSS.Nav:TargetFromBeast(e.beast)) end
      elseif IsShiftKeyDown and IsShiftKeyDown() then
        if PSS.Map and PSS.Map.SetWaypoint then PSS.Map:SetWaypoint(e.beast) end
      else
        RM.focus = (RM.focus ~= e.beast.npcID) and e.beast.npcID or nil
      end
      dirty = true
    end)
    iconPins[i] = pin
  end
  if pin:GetParent() ~= canvas then pin:SetParent(canvas) end
  PSS.Map:RaisePin(pin, 9500)
  return pin
end

local function EnsureDot(i, canvas)
  local dot = dotPins[i]
  if not dot then
    dot = CreateFrame("Frame", nil, canvas)
    dot:SetSize(9, 9)
    dot.border = dot:CreateTexture(nil, "BACKGROUND")
    dot.border:SetAllPoints(dot)
    dot.border:SetTexture("Interface\\Buttons\\WHITE8X8")
    dot.border:SetVertexColor(0, 0, 0, 0.85)
    dot.fill = dot:CreateTexture(nil, "ARTWORK")
    dot.fill:SetPoint("TOPLEFT", 1.5, -1.5)
    dot.fill:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
    dot.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    dot.fill:SetVertexColor(0.71, 0.57, 0.96, 1)
    dot:EnableMouse(false)
    dotPins[i] = dot
  end
  if dot:GetParent() ~= canvas then dot:SetParent(canvas) end
  PSS.Map:RaisePin(dot, 9200)
  return dot
end

-- Convex hull (monotone chain) in canvas pixel space.
local function Hull(points)
  if #points < 3 then return points end
  table.sort(points, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
  local function cross(o, a, b) return (a[1]-o[1])*(b[2]-o[2]) - (a[2]-o[2])*(b[1]-o[1]) end
  local lower, upper = {}, {}
  for _, p in ipairs(points) do
    while #lower >= 2 and cross(lower[#lower-1], lower[#lower], p) <= 0 do table.remove(lower) end
    table.insert(lower, p)
  end
  for i = #points, 1, -1 do
    local p = points[i]
    while #upper >= 2 and cross(upper[#upper-1], upper[#upper], p) <= 0 do table.remove(upper) end
    table.insert(upper, p)
  end
  table.remove(lower); table.remove(upper)
  for _, p in ipairs(upper) do table.insert(lower, p) end
  return lower
end

local function DrawOutline(canvas, pts, scale)
  if not areaFrame then
    areaFrame = CreateFrame("Frame", nil, canvas)
    areaFrame:EnableMouse(false)
  end
  if areaFrame:GetParent() ~= canvas then areaFrame:SetParent(canvas) end
  areaFrame:ClearAllPoints()
  areaFrame:SetAllPoints(canvas)
  PSS.Map:RaisePin(areaFrame, 9100)
  areaFrame:Show()
  -- Lines need Frame:CreateLine (modern clients). Without it only dots are shown.
  if type(areaFrame.CreateLine) ~= "function" then return end
  local hull = Hull(pts)
  if #hull < 2 then return end
  local thickness = 2 / math.max(0.2, scale or 1)
  for i = 1, #hull do
    local a, b = hull[i], hull[i % #hull + 1]
    local line = lines[i]
    if not line then
      line = areaFrame:CreateLine(nil, "OVERLAY")
      lines[i] = line
    end
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(0.71, 0.57, 0.96, 0.9)
    line:SetThickness(thickness)
    line:SetStartPoint("TOPLEFT", areaFrame, a[1], -a[2])
    line:SetEndPoint("TOPLEFT", areaFrame, b[1], -b[2])
    line:Show()
  end
  for i = #hull + 1, #lines do lines[i]:Hide() end
end

local function Update()
  local canvas, mapID, width, height, scale = PSS.Map:GetCanvasInfo()
  if not canvas then
    HideAll()
    last.mapID = false
    return
  end
  if not dirty and last.mapID == mapID and last.width == width and last.height == height and last.scale == scale then
    return
  end
  last.mapID, last.width, last.height, last.scale = mapID, width, height, scale
  dirty = false
  HideAll()
  local R = PSS.RarePets
  local used, focusEntry = 0, nil
  -- Fallback when the client's zone map IDs differ from the classic ones:
  -- match the rare's zone name against the open map's name (English client).
  local mapName
  if mapID and C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, mapID)
    if ok and info then mapName = info.name end
  end
  for _, e in ipairs(Entries()) do
    local b = e.beast
    if (b.mapID == mapID or (mapName and e.zone == mapName)) and b.x and b.y then
      if RM.focus == b.npcID then focusEntry = e end
      if Enabled() or RM.focus == b.npcID then
        used = used + 1
        local pin = EnsureIcon(used, canvas)
        pin.entry = e
        pin.icon:SetTexture(PSS.FamilyIcon and PSS.FamilyIcon(e.family) or "Interface\\Icons\\Ability_Hunter_BeastCall")
        local tamed, wanted = R:IsCollected(e), R:IsWanted(e)
        local focused = RM.focus == b.npcID
        -- Purple = rare, gold = wanted or selected, grey = already tamed.
        if focused or wanted then pin.ring:SetVertexColor(0.95, 0.77, 0.30, 1)
        elseif tamed then pin.ring:SetVertexColor(0.35, 0.35, 0.35, 1)
        else pin.ring:SetVertexColor(0.71, 0.57, 0.96, 1) end
        if pin.icon.SetDesaturated then pin.icon:SetDesaturated(tamed and not focused) end
        pin:SetAlpha(tamed and not focused and 0.6 or 1)
        local base = ICON_SIZES[PetSkillScoutDB and PetSkillScoutDB.rareIconSize] or 16
        pin:SetSize(focused and base + 4 or base, focused and base + 4 or base)
        PSS.Map:Place(pin, canvas, b.x, b.y, width, height, scale)
        pin:Show()
      end
    end
  end
  RM.stats = {mapID=mapID, icons=used, width=width, height=height, scale=scale}
  -- Spawn area of the selected rare.
  if focusEntry then
    local pts = {}
    for i, p in ipairs(focusEntry.beast.spawnPoints or {}) do
      local dot = EnsureDot(i, canvas)
      PSS.Map:Place(dot, canvas, p[1], p[2], width, height, scale)
      dot:Show()
      table.insert(pts, {p[1] / 100 * width, p[2] / 100 * height})
    end
    DrawOutline(canvas, pts, scale)
  elseif areaFrame then
    areaFrame:Hide()
  end
end

-- /pss mapdebug: what the rare layer sees on the currently open map.
function RM:Debug()
  local canvas, mapID, width, height, scale = PSS.Map:GetCanvasInfo()
  if not canvas then PSS:Print("Map debug: open the world map first, then run /pss mapdebug."); return end
  local inZone = 0
  for _, e in ipairs(Entries()) do
    if e.beast.mapID == mapID then inZone = inZone + 1 end
  end
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  if info then
    PSS:Print(string.format("Map name: %s, type %s", tostring(info.name), tostring(info.mapType)))
  end
  local pin = iconPins[1]
  PSS:Print(string.format("Map debug: mapID=%s canvas=%dx%d scale=%.2f mapStrata=%s",
    tostring(mapID), width, height, scale, WorldMapFrame:GetFrameStrata() or "?"))
  PSS:Print(string.format("Rares on this map: %d, icons drawn: %d, enabled=%s, error=%s",
    inZone, self.stats and self.stats.icons or 0, tostring(Enabled()), tostring(self._lastError)))
  if pin and pin:IsShown() then
    PSS:Print(string.format("First icon: %s strata=%s level=%d visible=%s",
      pin.entry and pin.entry.name or "?", pin:GetFrameStrata(), pin:GetFrameLevel(), tostring(pin:IsVisible())))
  end
  if PSS.Map._lastPinError then PSS:Print("Beast pin error: "..PSS.Map._lastPinError) end
end

-- Opens the world map on a rare's zone and shows its spawn area.
function RM:Focus(entry)
  if not entry then return end
  local b = entry.beast
  PSS.selected = b
  self.focus = b.npcID
  dirty = true
  if WorldMapFrame then
    if type(ShowUIPanel) == "function" then pcall(ShowUIPanel, WorldMapFrame)
    elseif WorldMapFrame.Show then pcall(WorldMapFrame.Show, WorldMapFrame) end
    if b.mapID and type(WorldMapFrame.SetMapID) == "function" then
      pcall(WorldMapFrame.SetMapID, WorldMapFrame, b.mapID)
    end
  end
end

local driver = CreateFrame("Frame")
PSS:OnlyWithWorldMap(driver)
RM._driver = driver
driver:SetScript("OnUpdate", function(_, elapsed)
  elapsedSince = elapsedSince + (elapsed or 0)
  if elapsedSince < 0.2 then return end
  elapsedSince = 0
  local ok, err = pcall(Update)
  if not ok then RM._lastError = tostring(err) end
end)
driver.pssKey = "RareMap"
PSS:Every(driver, 0.2)
