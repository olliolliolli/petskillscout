-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Navigation helpers: player position, a TomTom-style direction arrow and
-- minimap icons for nearby rares, tracked beasts and the arrow target.
-- Nothing here moves the character; it only shows directions.
local PSS = PetSkillScout
PSS.Nav = {}
local Nav = PSS.Nav
local sizeCache = {}

local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end

-- Zone map (UIMapType.Zone) that contains the player, plus position 0..1.
function Nav:PlayerPos()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local mapID = safe(C_Map.GetBestMapForUnit, "player")
  local guard = 0
  while mapID and guard < 6 do
    local info = C_Map.GetMapInfo and safe(C_Map.GetMapInfo, mapID)
    if not info or info.mapType == 3 or (info.mapType or 0) < 3 then break end
    mapID, guard = info.parentMapID, guard + 1
  end
  if not mapID then return nil end
  local pos = safe(C_Map.GetPlayerMapPosition, mapID, "player")
  if not pos then return nil end
  local x, y = safe(pos.GetXY, pos)
  if not x or (x == 0 and y == 0) then return nil end
  return mapID, x, y
end

-- Zone size in yards (nil when the client has no API for it).
function Nav:MapSize(mapID)
  local cached = sizeCache[mapID]
  if cached == false then return nil end
  if cached ~= nil then return cached[1], cached[2] end
  local w, h = safe(C_Map and C_Map.GetMapWorldSize, mapID)
  -- Classic clients: measure the map corners in world yards instead.
  if not (w and w > 0) and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
    local _, p0 = safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local _, p1 = safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 0))
    local _, p2 = safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 1))
    if p0 and p1 and p2 and p0.GetXY then
      local x0, y0 = p0:GetXY()
      local x1, y1 = p1:GetXY()
      local x2, y2 = p2:GetXY()
      w = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
      h = math.sqrt((x2 - x0) ^ 2 + (y2 - y0) ^ 2)
    end
  end
  sizeCache[mapID] = (w and w > 0 and h and h > 0) and {w, h} or false
  return w, h
end

-- Offset to a point (percent coordinates) in yards east/south. Without a size
-- API, zone maps are 3:2, so percent units are scaled to keep the angle right.
function Nav:Offset(mapID, px, py, tx, ty)
  -- Exact: both points in world yards (world X points north, Y points west).
  local c1, x1, y1 = self:World(mapID, px, py)
  local c2, x2, y2 = self:World(mapID, tx / 100, ty / 100)
  if c1 and c2 and c1 == c2 then return -(y2 - y1), -(x2 - x1), true end
  local w, h = self:MapSize(mapID)
  if w then return (tx / 100 - px) * w, (ty / 100 - py) * h, true end
  return (tx / 100 - px) * 150, (ty / 100 - py) * 100, false
end

function Nav:Nearest(target, mapID, px, py)
  local best, bx, by, bd
  for _, p in ipairs(target.points or {}) do
    local dx, dy = self:Offset(mapID, px, py, p[1], p[2])
    local d = dx * dx + dy * dy
    if not best or d < best then best, bx, by, bd = d, dx, dy, math.sqrt(d) end
  end
  return bx, by, bd
end

-- World position (continent ID, yards) of a zone-map point; x, y are 0..1.
local worldMemo, worldMemoN = {}, 0
function Nav:World(mapID, x, y)
  if not (mapID and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local key = mapID .. ":" .. x .. ":" .. y
  local m = worldMemo[key]
  if m then return m[1], m[2], m[3] end
  local c, wx, wy = self:WorldRaw(mapID, x, y)
  if c then
    worldMemoN = worldMemoN + 1
    if worldMemoN > 2000 then worldMemo, worldMemoN = {}, 0 end
    worldMemo[key] = {c, wx, wy}
  end
  return c, wx, wy
end
function Nav:WorldRaw(mapID, x, y)
  local cont, pos = safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
  if not (cont and pos and pos.GetXY) then return nil end
  local wx, wy = safe(pos.GetXY, pos)
  if not wx then return nil end
  return cont, wx, wy
end

-- Distance in yards from the player to a point given in zone percent (0..100).
-- Returns yards (nil when unknown) and whether the point is on another continent.
function Nav:DistanceTo(mapID, tx, ty, from)
  local pm, px, py
  if from then pm, px, py = from[1], from[2], from[3] else pm, px, py = self:PlayerPos() end
  if not (pm and mapID and tx and ty) then return nil end
  if pm == mapID then
    local dx, dy = self:Offset(mapID, px, py, tx, ty)
    return math.sqrt(dx * dx + dy * dy), false
  end
  local c1, x1, y1 = self:World(pm, px, py)
  local c2, x2, y2 = self:World(mapID, tx / 100, ty / 100)
  if not (c1 and c2) then return nil end
  if c1 ~= c2 then return nil, true end
  return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2), false
end

-- "320 yd", "1.4 km"-style short distance text in yards.
function Nav:DistanceText(yards)
  if not yards then return nil end
  if yards >= 2000 then return string.format("%.1fk yd", yards / 1000) end
  return string.format("%d yd", math.floor(yards + 0.5))
end

-- Targets ------------------------------------------------------------------

function Nav:TargetFromBeast(b)
  if not (b and b.mapID) then return nil end
  local points = b.spawnPoints or (b.x and {{b.x, b.y}})
  if not points or #points == 0 then return nil end
  return {name = b.name, mapID = b.mapID, points = points, npcID = b.npcID, zone = b.zone}
end

function Nav:TargetFromAtlas(npcID)
  local a = PSS.Atlas and PSS.Atlas:Get(npcID)
  if not a then return nil end
  local mapID, points, zone = a.mapID, a.spawnPoints, a.zone
  -- Prefer the complete spawn list from Database.lua when available.
  for _, b in ipairs(PSS.Beasts or {}) do
    if b.npcID == npcID and b.mapID and b.spawnPoints then
      mapID, points, zone = b.mapID, b.spawnPoints, b.zone
      break
    end
  end
  if not (mapID and points and #points > 0) then return nil end
  return {name = a.name, mapID = mapID, points = points, npcID = npcID, zone = zone}
end

-- Arrow --------------------------------------------------------------------
local arrow
local COMPASS = {"N", "NW", "W", "SW", "S", "SE", "E", "NE"}

local function CreateArrow()
  if arrow then return arrow end
  arrow = CreateFrame("Button", "PetSkillScoutArrow", UIParent)
  arrow:SetSize(64, 64)
  arrow:SetFrameStrata("HIGH")
  arrow:SetClampedToScreen(true)
  arrow:SetMovable(true)
  arrow:EnableMouse(true)
  arrow:RegisterForDrag("LeftButton")
  arrow:RegisterForClicks("RightButtonUp")
  local pos = PetSkillScoutDB and PetSkillScoutDB.arrowPos
  if pos and pos.x then arrow:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
  else arrow:SetPoint("TOP", UIParent, "TOP", 0, -140) end
  arrow.tex = arrow:CreateTexture(nil, "ARTWORK")
  arrow.tex:SetTexture("Interface\\Minimap\\MinimapArrow")
  arrow.tex:SetSize(48, 48)
  arrow.tex:SetPoint("CENTER")
  arrow.name = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  arrow.name:SetPoint("TOP", arrow, "BOTTOM", 0, 2)
  arrow.dist = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  arrow.dist:SetPoint("TOP", arrow.name, "BOTTOM", 0, -2)
  arrow:SetScript("OnDragStart", function(self) self:StartMoving() end)
  arrow:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    if PetSkillScoutDB and x then PetSkillScoutDB.arrowPos = {x = x, y = y} end
  end)
  arrow:SetScript("OnClick", function() Nav:ClearTarget() end)
  arrow:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(PSS:Safe(Nav.target and Nav.target.name or "PetSkillScout"))
    GameTooltip:AddLine(PSS:Safe(PSS:L("arrowHint")), 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  arrow:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  local elapsedSince = 0
  arrow:SetScript("OnUpdate", function(self, elapsed)
    elapsedSince = elapsedSince + (elapsed or 0)
    if elapsedSince < 0.05 then return end
    elapsedSince = 0
    Nav:UpdateArrow()
  end)
  arrow:Hide()
  return arrow
end

function Nav:SetTarget(target)
  if not target then
    PSS:Print(PSS:L("arrowNoCoords"))
    return
  end
  self.target = target
  self.arrivedAt = nil
  CreateArrow()
  arrow.name:SetText(target.name or "?")
  arrow:Show()
  if PSS.Minimap then PSS.Minimap:Refresh() end
end

function Nav:ClearTarget()
  self.target = nil
  if arrow then arrow:Hide() end
  if PSS.Minimap then PSS.Minimap:Refresh() end
end

function Nav:UpdateArrow()
  local t = self.target
  if not t then arrow:Hide() return end
  local mapID, px, py = self:PlayerPos()
  if not mapID then
    arrow.tex:Hide()
    arrow.dist:SetText(PSS:L("arrowNoPosition"))
    return
  end
  if mapID ~= t.mapID then
    -- Different zone: point the player to the zone instead of a bearing.
    arrow.tex:Hide()
    local info = C_Map.GetMapInfo and safe(C_Map.GetMapInfo, t.mapID)
    arrow.dist:SetText(string.format(PSS:L("arrowGoTo"), info and info.name or t.zone or "?"))
    return
  end
  local dx, dy, dist = self:Nearest(t, mapID, px, py)
  if not dx then return end
  local _, _, yards = self:Offset(mapID, 0, 0, 0, 0)
  if yards then
    if dist < 12 then
      self.arrivedAt = self.arrivedAt or GetTime()
      arrow.tex:Hide()
      arrow.dist:SetText("|cff7ee0a3" .. PSS:L("arrowArrived") .. "|r")
      if GetTime() - self.arrivedAt > 6 then self:ClearTarget() end
      return
    end
    self.arrivedAt = nil
    arrow.dist:SetText(string.format("%d yd", math.floor(dist + 0.5)))
  else
    arrow.dist:SetText("")
  end
  -- Bearing measured like GetPlayerFacing: 0 = north, counter-clockwise.
  local bearing = math.atan2(-dx, -dy)
  local facing = GetPlayerFacing and GetPlayerFacing()
  if not facing or not arrow.tex.SetRotation then
    local idx = math.floor(((bearing % (2 * math.pi)) / (math.pi / 4)) + 0.5) % 8 + 1
    arrow.tex:Hide()
    arrow.dist:SetText((arrow.dist:GetText() or "") .. "  " .. COMPASS[idx])
    return
  end
  local rel = (bearing - facing) % (2 * math.pi)
  arrow.tex:Show()
  arrow.tex:SetRotation(rel)
  -- Green when facing the target, yellow to red as the angle grows.
  local off = math.abs(rel > math.pi and rel - 2 * math.pi or rel) / math.pi
  arrow.tex:SetVertexColor(math.min(1, off * 2), math.min(1, 2 - off * 2), 0.2)
end

-- Minimap icons --------------------------------------------------------------
PSS.Minimap = {}
local MM = PSS.Minimap
local pins = {}
MM._pins = pins
local OUTDOOR = {466 + 2/3, 400, 333 + 1/3, 266 + 2/3, 200, 133 + 1/3}
local INDOOR = {300, 240, 180, 120, 80, 50}
local indoors = false
local mmDirty, mmElapsed = true, 0

function MM:Refresh() mmDirty = true end

local function Enabled()
  return not PetSkillScoutDB or PetSkillScoutDB.minimapPins ~= false
end

-- Never by changing the minimap zoom: that fires MINIMAP_UPDATE_ZOOM and kept
-- the client busy in a loop (134 ms per second, see /pss cpu).
local function DetectIndoors()
  if IsIndoors then indoors = PSS.Plain(safe(IsIndoors)) and true or false end
end

local function Pin(i)
  local p = pins[i]
  if not p then
    p = CreateFrame("Button", nil, Minimap)
    p:SetSize(14, 14)
    p:SetFrameStrata(Minimap:GetFrameStrata())
    p:SetFrameLevel(Minimap:GetFrameLevel() + 20)
    p.ring = p:CreateTexture(nil, "BACKGROUND")
    p.ring:SetPoint("TOPLEFT", -1.5, 1.5)
    p.ring:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
    p.ring:SetTexture("Interface\\Buttons\\WHITE8X8")
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetAllPoints(p)
    p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    p:SetScript("OnEnter", function(self)
      if not GameTooltip then return end
      if self.group and PSS.QuestPins then PSS.QuestPins.Tooltip(self); return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(PSS:Safe(self.label or "?"), 1, 0.82, 0.25)
      if self.sub then GameTooltip:AddLine(PSS:Safe(self.sub), 0.8, 0.8, 0.8) end
      if self.dist then GameTooltip:AddLine(PSS:Safe(string.format("%d yd", math.floor(self.dist + 0.5))), 1, 1, 1) end
      GameTooltip:AddLine(PSS:Safe(PSS:L("minimapHint")), 0.6, 0.6, 0.6)
      if self.beastID then GameTooltip:AddLine(PSS:Safe(PSS:L("untrackHint")), 0.6, 0.6, 0.6) end
      GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    p:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        -- Quest giver: right click hides the pin ("giver not here").
        if self.group and PSS.QuestPins then PSS.QuestPins:HideGiver(self.group); return end
        -- Tracked beast: right click stops tracking it.
        if self.beastID then
          PSS:SetTracked(self.beastID, false)
          if GameTooltip then GameTooltip:Hide() end
          MM:Refresh()
          if PSS.UI and PSS.UI.Refresh then pcall(PSS.UI.Refresh, PSS.UI) end
          PSS:Print(string.format(PSS:L("untrackedPin"), self.label or "?"))
        end
        return
      end
      if self.target then Nav:SetTarget(self.target) end
    end)
    pins[i] = p
  end
  return p
end

-- Collects { target, icon, ring color, label, sub } for the player's zone.
local function Candidates(mapID)
  local list = {}
  local R = PSS.RarePets
  if R then
    if not R.entries or #R.entries == 0 then R:Build() end
    for _, e in ipairs(R.entries) do
      if e.beast.mapID == mapID and not R:IsCollected(e) then
        local t = Nav:TargetFromBeast(e.beast)
        if t then
          table.insert(list, {target = t, icon = PSS.FamilyIcon and PSS.FamilyIcon(e.family),
            color = {0.71, 0.57, 0.96}, label = e.name, sub = PSS:L("rarePets")})
        end
      end
    end
  end
  local tracked = PetSkillScoutDB and PetSkillScoutDB.tracked or {}
  for _, b in ipairs(PSS.Beasts or {}) do
    if tracked[b.id] and b.mapID == mapID then
      local t = Nav:TargetFromBeast(b)
      if t then
        table.insert(list, {target = t, icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
          color = {0.47, 0.79, 0.51}, beastID = b.id, label = b.name, sub = (PSS:NameAbility(b.ability) .. " " .. tostring(b.rank))})
      end
    end
  end
  if PSS.Atlas and next(tracked) then
    PSS.Atlas:Build()
    for _, rec in ipairs(PSS.Atlas.list) do
      if tracked[rec.id] and rec.mapID == mapID then
        local t = Nav:TargetFromAtlas(rec.npcID)
        if t then
          table.insert(list, {target = t, icon = "Interface\\Icons\\Ability_Hunter_BeastTaming",
            color = {0.47, 0.79, 0.51}, beastID = rec.id, label = rec.name, sub = PSS.Atlas:TeachesText(rec) or PSS:NameFamily(rec.family)})
        end
      end
    end
  end
  if PSS.Route and #PSS.Route:Goals() > 0 then
    local ok, stops = pcall(PSS.Route.Stops, PSS.Route)
    for _, stop in ipairs(ok and stops or {}) do
      if stop.beast and not stop.done and stop.beast.mapID == mapID then
        local t = PSS.Route:Target(stop)
        if t then
          table.insert(list, {target = t, icon = PSS.FamilyIcon and PSS.FamilyIcon(stop.beast.family),
            color = {0.95, 0.77, 0.30}, label = stop.beast.name, sub = PSS:L("tabRoute") .. ": " .. t.name})
        end
      end
    end
  end
  -- Quest givers with quests you can take now (same rating colours as the world map).
  local QP = PSS.QuestPins
  if QP and QP.MinimapEnabled and QP:MinimapEnabled() and PSS.QuestWorth then
    local ok, groups = pcall(QP.Groups, QP, mapID, PSS.QuestWorth:PlayerLevel())
    for _, g in ipairs(ok and groups or {}) do
      if g.best ~= "skip" or QP:ShowSkip() then
        table.insert(list, {quest = g, verdict = g.best, target = {name = PSS.QuestWorth:NPCName(g.npc)
          or PSS.QuestWorth:Title(g.quests[1].id), mapID = mapID, points = {{g.x, g.y}}}})
      end
    end
  end
  -- Objectives of quests in your log (same marks as on the world map).
  if QP and QP.MinimapEnabled and QP:MinimapEnabled() and QP.ObjectivesOn and QP:ObjectivesOn() then
    local ok, quests = pcall(QP.LogQuests, QP)
    for _, q in ipairs(ok and quests or {}) do
      local r = PSS.QuestDB and PSS.QuestDB[q.id]
      if r and r.om == mapID and r.ox and not q.done then
        table.insert(list, {obj = true, icon = "Interface/TargetingFrame/UI-RaidTargetingIcon_8",
          label = q.title or r.n, sub = PSS:L("qObjective"), target = {name = q.title or r.n, mapID = mapID, points = {{r.ox, r.oy}}}})
      end
    end
  end
  if QP and QP.MinimapEnabled and QP:MinimapEnabled() and QP.TurnIns then
    local ok, list2 = pcall(QP.TurnIns, QP, mapID)
    for _, q in ipairs(ok and list2 or {}) do
      table.insert(list, {obj = true, turnin = true, icon = QP.TURNIN_ICON, label = q.title, sub = PSS:L("qTurnIn"),
        target = {name = q.title, mapID = mapID, points = {{q.x, q.y}}}})
    end
  end
  if Nav.target and Nav.target.mapID == mapID then
    table.insert(list, {target = Nav.target, icon = "Interface\\Icons\\Ability_Hunter_Pathfinding",
      color = {0.95, 0.77, 0.30}, label = Nav.target.name, sub = PSS:L("arrowTarget"), edge = true})
  end
  return list
end

-- Spawn area of the rare selected on the world map (RareMap focus): the same
-- purple dots and outline, drawn on the minimap and clipped to its circle.
local areaDots, areaLines, areaHolder = {}, {}, nil
local function HideArea()
  for _, d in ipairs(areaDots) do d:Hide() end
  for _, l in ipairs(areaLines) do l:Hide() end
end
local function FocusEntry(mapID)
  local RM, R = PSS.RareMap, PSS.RarePets
  if not (RM and RM.focus and R and R.entries) then return nil end
  for _, e in ipairs(R.entries) do
    if e.beast.npcID == RM.focus and e.beast.mapID == mapID and e.beast.spawnPoints then return e end
  end
end
-- Part of segment a-b inside a circle of radius r around 0,0 (nil if none).
local function ClipToCircle(ax, ay, bx, by, r)
  local dx, dy = bx - ax, by - ay
  local A = dx * dx + dy * dy
  if A == 0 then return nil end
  local B = 2 * (ax * dx + ay * dy)
  local C = ax * ax + ay * ay - r * r
  local disc = B * B - 4 * A * C
  if disc <= 0 then return nil end
  local sq = math.sqrt(disc)
  local t1, t2 = math.max(0, (-B - sq) / (2 * A)), math.min(1, (-B + sq) / (2 * A))
  if t1 >= t2 then return nil end
  return ax + dx * t1, ay + dy * t1, ax + dx * t2, ay + dy * t2
end
local function Hull(points)
  if #points < 3 then return points end
  table.sort(points, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
  local function cross(o, a, b) return (a[1]-o[1])*(b[2]-o[2]) - (a[2]-o[2])*(b[1]-o[1]) end
  local lower, upper = {}, {}
  for _, p in ipairs(points) do
    while #lower >= 2 and cross(lower[#lower-1], lower[#lower], p) <= 0 do table.remove(lower) end
    lower[#lower + 1] = p
  end
  for i = #points, 1, -1 do
    local p = points[i]
    while #upper >= 2 and cross(upper[#upper-1], upper[#upper], p) <= 0 do table.remove(upper) end
    upper[#upper + 1] = p
  end
  table.remove(lower); table.remove(upper)
  for _, p in ipairs(upper) do lower[#lower + 1] = p end
  return lower
end
local function DrawArea(mapID, px, py, scale, rotate, facing)
  local e = FocusEntry(mapID)
  if not e then HideArea() return end
  if not areaHolder then
    areaHolder = CreateFrame("Frame", nil, Minimap)
    areaHolder:SetAllPoints(Minimap)
    areaHolder:SetFrameLevel(Minimap:GetFrameLevel() + 15)
    areaHolder:EnableMouse(false)
  end
  local half = Minimap:GetWidth() / 2
  local limit = half * 0.97
  local cs, sn = math.cos(-facing), math.sin(-facing)
  local pts, nd = {}, 0
  for _, p in ipairs(e.beast.spawnPoints) do
    local dx, dy = Nav:Offset(mapID, px, py, p[1], p[2])
    local ex, ny = dx, -dy
    if rotate then ex, ny = ex * cs - ny * sn, ex * sn + ny * cs end
    ex, ny = ex * scale, ny * scale
    pts[#pts + 1] = {ex, ny}
    if ex * ex + ny * ny <= limit * limit then
      nd = nd + 1
      local d = areaDots[nd]
      if not d then
        d = areaHolder:CreateTexture(nil, "OVERLAY")
        d:SetTexture("Interface\\Buttons\\WHITE8X8")
        d:SetSize(5, 5)
        areaDots[nd] = d
      end
      d:SetVertexColor(0.71, 0.57, 0.96, 1)
      d:ClearAllPoints()
      d:SetPoint("CENTER", Minimap, "CENTER", ex, ny)
      d:Show()
    end
  end
  for i = nd + 1, #areaDots do areaDots[i]:Hide() end
  local nl = 0
  if type(areaHolder.CreateLine) == "function" then
    local hull = Hull(pts)
    if #hull >= 2 then
      for i = 1, #hull do
        local a, b = hull[i], hull[i % #hull + 1]
        local x1, y1, x2, y2 = ClipToCircle(a[1], a[2], b[1], b[2], limit)
        if x1 then
          nl = nl + 1
          local l = areaLines[nl]
          if not l then
            l = areaHolder:CreateLine(nil, "ARTWORK")
            l:SetTexture("Interface\\Buttons\\WHITE8X8")
            l:SetThickness(1.5)
            areaLines[nl] = l
          end
          l:SetVertexColor(0.71, 0.57, 0.96, 0.85)
          l:SetStartPoint("CENTER", Minimap, x1, y1)
          l:SetEndPoint("CENTER", Minimap, x2, y2)
          l:Show()
        end
      end
    end
  end
  for i = nl + 1, #areaLines do areaLines[i]:Hide() end
end

local cached = {mapID = nil, list = {}}
local function UpdateMinimap()
  if not Minimap or not Enabled() then
    for _, p in ipairs(pins) do p:Hide() end
    HideArea()
    return
  end
  local mapID, px, py = Nav:PlayerPos()
  if not mapID then for _, p in ipairs(pins) do p:Hide() end HideArea() return end
  if mmDirty or cached.mapID ~= mapID then
    cached.mapID, cached.list = mapID, Candidates(mapID)
    mmDirty = false
    cached.fresh = true
  end
  local zoom = (Minimap:GetZoom() or 0) + 1
  local facingNow = GetPlayerFacing and GetPlayerFacing() or 0
  local rotNow = GetCVar and GetCVar("rotateMinimap") == "1"
  -- Standing still with the same zoom: the icons are already right.
  local st = cached.state
  if st and not cached.fresh and st.px == px and st.py == py and st.zoom == zoom and st.mapID == mapID
     and (not rotNow or st.facing == facingNow) and st.n == #cached.list
     and st.focus == (PSS.RareMap and PSS.RareMap.focus) then return end
  cached.state = {px = px, py = py, zoom = zoom, mapID = mapID, facing = facingNow, n = #cached.list,
    focus = PSS.RareMap and PSS.RareMap.focus}
  cached.fresh = false
  -- The client knows the exact view radius (yards); the zoom table is the fallback.
  local radius = Minimap.GetViewRadius and tonumber(safe(Minimap.GetViewRadius, Minimap))
  if not (radius and radius > 0) then radius = (indoors and INDOOR or OUTDOOR)[zoom] / 2 end
  local scale = (Minimap:GetWidth() / 2) / radius
  local facing = GetPlayerFacing and GetPlayerFacing() or 0
  local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
  local used = 0
  -- Reference for the quick moves between full passes (see MoveFast).
  local okU, wn, ww = pcall(UnitPosition, "player")
  wn, ww = okU and PSS.Plain(wn), okU and PSS.Plain(ww)
  cached.wn, cached.ww, cached.scale = wn, ww, scale
  for _, c in ipairs(cached.list) do
    local dx, dy, dist = Nav:Nearest(c.target, mapID, px, py)
    if dx then
      local ex, ny = dx, -dy
      local rawE, rawN = ex, ny
      if rotate then
        local cs, sn = math.cos(-facing), math.sin(-facing)
        ex, ny = ex * cs - ny * sn, ex * sn + ny * cs
      end
      local onMap = dist <= radius * 0.95
      if onMap or c.edge then
        if not onMap then
          local k = radius * 0.95 / dist
          ex, ny = ex * k, ny * k
        end
        used = used + 1
        local p = Pin(used)
        p.group = c.quest
        if c.quest then
          -- Quest giver: the "!" icon in its rating colour, no ring.
          p.icon:SetTexture(PSS.QuestPins.ICON)
          p.icon:SetTexCoord(0, 1, 0, 1)
          p.ring:Hide()
          PSS.QuestPins:Style(p, c.verdict)
          p.disc:Show(); p.discEdge:Show()
          if c.verdict == "ok" then p:SetSize(9, 9) else p:SetSize(10, 10) end
          local sz = c.verdict == "ok" and 9 or 10
          p.disc:SetSize(sz, sz); p.discEdge:SetSize(sz + 2, sz + 2)
          if not onMap then p:SetAlpha(0.6) end
        elseif c.obj then
          -- Quest objective: small mark, no ring. Turn-in "?": a bit bigger.
          local sz = c.turnin and 14 or 11
          p:SetSize(sz, sz)
          if p.disc then p.disc:Hide(); p.discEdge:Hide() end
          p.ring:Hide()
          p.icon:SetDesaturated(false)
          p.icon:SetVertexColor(1, 1, 1)
          p.icon:SetTexCoord(0, 1, 0, 1)
          p.icon:SetTexture(c.icon)
          p:SetAlpha(onMap and 0.85 or 0.5)
        else
          p:SetSize(14, 14)
          if p.disc then p.disc:Hide(); p.discEdge:Hide() end
          p.icon:SetDesaturated(false)
          p.icon:SetVertexColor(1, 1, 1)
          p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
          p.icon:SetTexture(c.icon)
          p.ring:Show()
          p.ring:SetVertexColor(c.color[1], c.color[2], c.color[3], 1)
          p:SetAlpha(onMap and 1 or 0.6)
        end
        p.label, p.sub, p.dist, p.target, p.beastID = c.label, c.sub, math.floor(dist), c.target, c.beastID
        p:ClearAllPoints()
        local off = 0 -- right on the giver, like the game's own "!"
        local sx, sy = 0, 0
        if c.quest and PSS.QuestPins and PSS.QuestPins.SpreadOffset then sx, sy = PSS.QuestPins.SpreadOffset(c.quest.spread, 4) end
        p:SetPoint("CENTER", Minimap, "CENTER", ex * scale + off + sx, ny * scale + off + sy)
        p.baseLevel = p.baseLevel or p:GetFrameLevel()
        p:SetFrameLevel(p.baseLevel + (c.turnin and 10 or 0))
        p:Show()
        p.mmE, p.mmN, p.mmSX, p.mmSY = onMap and rawE or nil, rawN, sx, sy
      end
    end
  end
  for i = used + 1, #pins do pins[i]:Hide() end
  cached.used = used
  DrawArea(mapID, px, py, scale, rotate, facing)
end

local driver = CreateFrame("Frame")
MM._driver = driver
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
driver:RegisterEvent("ZONE_CHANGED_INDOORS")
pcall(driver.RegisterEvent, driver, "MINIMAP_UPDATE_ZOOM")
driver:SetScript("OnEvent", function(_, event)
  -- A zoom change only moves the pins; the next pass sees it.
  if event == "MINIMAP_UPDATE_ZOOM" then return end
  pcall(DetectIndoors)
  mmDirty = true
end)
-- A full pass (which pins, how they look) runs 5 times a second. Between
-- passes, while you run or the map turns, the pins already on the minimap only
-- shift by how far you moved: no table work, no map lookups.
MM.FAST, MM.SLOW = 0.05, 0.2
function MM.Interval(speed, rotating)
  if (type(speed) == "number" and speed > 0) or rotating then return MM.FAST end
  return MM.SLOW
end
-- Pin offset (yards east, north) after you moved; rotated with the minimap.
function MM.Shift(e, n, movedE, movedN, cs, sn)
  e, n = e - movedE, n - movedN
  if cs then return e * cs - n * sn, e * sn + n * cs end
  return e, n
end
local function MoveFast()
  local used, s = cached.used or 0, cached.scale
  if used == 0 or not (s and cached.wn and UnitPosition) then return end
  local ok, wn, ww = pcall(UnitPosition, "player")
  wn, ww = ok and PSS.Plain(wn), ok and PSS.Plain(ww)
  if type(wn) ~= "number" or type(ww) ~= "number" then return end
  local movedN, movedE = wn - cached.wn, cached.ww - ww -- second value grows westwards
  local cs, sn
  if GetCVar and GetCVar("rotateMinimap") == "1" then
    local f = -(GetPlayerFacing and GetPlayerFacing() or 0)
    cs, sn = math.cos(f), math.sin(f)
  end
  for i = 1, used do
    local p = pins[i]
    if p and p.mmE then
      local e, n = MM.Shift(p.mmE, p.mmN, movedE, movedN, cs, sn)
      p:SetPoint("CENTER", Minimap, "CENTER", e * s + p.mmSX, n * s + p.mmSY)
    end
  end
end
driver:SetScript("OnUpdate", function(_, elapsed)
  mmElapsed = mmElapsed + (elapsed or 0)
  if mmElapsed < MM.SLOW then
    local speed = GetUnitSpeed and PSS.Plain(safe(GetUnitSpeed, "player"))
    local rotating = GetCVar and GetCVar("rotateMinimap") == "1"
    if MM.Interval(speed, rotating) == MM.FAST then pcall(MoveFast) end
    return
  end
  mmElapsed = 0
  local ok, err = pcall(UpdateMinimap)
  if not ok then MM._lastError = tostring(err) end
end)
driver.pssKey = "Nav minimap"
PSS:Every(driver, MM.FAST)
