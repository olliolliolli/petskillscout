-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Quest givers on the world map: one "!" per quest giver with quests you can
-- pick up now (PSS.QuestDB, AllTheThings Forever data, MIT).
-- Purple = worth it (experience per minute or a gear upgrade), yellow =
-- normal, grey = not worth the time (can be switched off).
-- Click: arrow to the quest giver. Pins are drawn on the map canvas next to
-- the game's own markers; nothing of the game's map is changed.
local PSS = PetSkillScout
PSS.QuestPins = {}
local QP = PSS.QuestPins

local pins = {}
local elapsedSince, dirty = 0, true
local last = {mapID = false, width = 0, height = 0, scale = 0, level = 0}
local ICON = "Interface\\GossipFrame\\AvailableQuestIcon"
local ORDER = {great = 1, ok = 2, skip = 3}

local function DB() return PetSkillScoutDB or {} end
function QP:Enabled() return DB().questPins ~= false end
function QP:ShowSkip() return DB().questPinsSkip ~= false end
function QP:MinimapEnabled() return QP:Enabled() and DB().questMinimap ~= false end
function QP:Refresh() dirty = true; if PSS.Minimap then PSS.Minimap:Refresh() end end
QP.ICON = ICON

local function HideAll() for _, p in ipairs(pins) do p:Hide() end end

function QP.Tooltip(pin)
  local g = pin.group
  if not (g and GameTooltip) then return end
  local W = PSS.QuestWorth
  GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
  local names = {}
  for _, npc in ipairs(g.npcs or {g.npc}) do
    local n = W:NPCName(npc)
    if n then names[#names + 1] = n end
  end
  GameTooltip:AddLine(PSS:Safe(#names > 0 and table.concat(names, ", ") or PSS:L("qwGiverUnknown")), 1, 0.82, 0, true)
  for _, x in ipairs(g.quests) do
    local c = W.COLORS[x.rate.verdict]
    GameTooltip:AddLine(PSS:Safe(W:Title(x.id) .. "  (" .. PSS:L("qw_" .. x.rate.verdict) .. ")"), c[1], c[2], c[3])
    GameTooltip:AddLine(PSS:Safe("   " .. W:Summary(x.rate)), 0.85, 0.85, 0.85)
  end
  GameTooltip:AddLine(PSS:Safe(PSS:L("qwPinHint")), 0.6, 0.6, 0.6, true)
  GameTooltip:AddLine(PSS:Safe(PSS:L("qPinHideHint")), 0.6, 0.6, 0.6, true)
  GameTooltip:Show()
end

local function Ensure(i, canvas)
  local pin = pins[i]
  if not pin then
    pin = CreateFrame("Button", nil, canvas)
    pin:SetSize(18, 18)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints(pin)
    pin.icon:SetTexture(ICON)
    pin:SetScript("OnEnter", QP.Tooltip)
    pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:SetScript("OnClick", function(self, button)
      local g = self.group
      if button == "RightButton" then
        if g then QP:HideGiver(g) end
        return
      end
      if g and PSS.Nav then
        PSS.Nav:SetTarget({name = PSS.QuestWorth:NPCName(g.npc) or PSS.QuestWorth:Title(g.quests[1].id),
          mapID = g.mapID, points = {{g.x, g.y}}})
      end
    end)
    pins[i] = pin
  end
  if pin:GetParent() ~= canvas then pin:SetParent(canvas) end
  QP.Lower(pin, canvas)
  return pin
end

-- Group the available quests of a map by quest giver position.
-- Givers the player marked as "not here" (right click on the pin): the
-- database position is wrong or the NPC appears only in some phase.
-- Key: npc:mapID. /pss pinsreset brings them back.
-- The key includes the rounded position: when players later find the giver
-- somewhere else (QuestLearn), the new pin is not hidden.
local function GiverKey(npc, mapID, x, y)
  return string.format("%s:%s:%d:%d", tostring(npc or 0), tostring(mapID or 0),
    math.floor((x or 0) / 2 + 0.5), math.floor((y or 0) / 2 + 0.5))
end
function QP:IsHiddenGiver(npc, mapID, x, y)
  local h = DB().questPinHidden
  return h and h[GiverKey(npc, mapID, x, y)] ~= nil
end
function QP:HideGiver(g)
  if not PetSkillScoutDB then return end
  PetSkillScoutDB.questPinHidden = PetSkillScoutDB.questPinHidden or {}
  PetSkillScoutDB.questPinHidden[GiverKey(g.npc, g.mapID, g.x, g.y)] = time and time() or 0
  if GameTooltip then GameTooltip:Hide() end
  PSS:Print(string.format(PSS:L("qPinHidden"), PSS.QuestWorth:NPCName(g.npc) or "?"))
  QP:Refresh()
end
function QP:ResetHidden()
  if PetSkillScoutDB then PetSkillScoutDB.questPinHidden = nil end
  QP:Refresh()
end

-- Our quest pins sit under the game's own quest icons (turn-in "?" and
-- available "!"), so those are never covered: same strata as the map pins,
-- frame level of the area-POI layer (below quests), or just above the canvas.
function QP.Lower(pin, canvas)
  local strata = canvas.GetFrameStrata and canvas:GetFrameStrata()
  if strata then pin:SetFrameStrata(strata) end
  local level
  local mgr = WorldMapFrame and WorldMapFrame.GetPinFrameLevelsManager and WorldMapFrame:GetPinFrameLevelsManager()
  if mgr and mgr.GetValidFrameLevel then
    for _, k in ipairs({"PIN_FRAME_LEVEL_AREA_POI", "PIN_FRAME_LEVEL_FLIGHT_POINT", "PIN_FRAME_LEVEL_DIG_SITE"}) do
      local ok, v = pcall(mgr.GetValidFrameLevel, mgr, k)
      if ok and type(v) == "number" then level = v break end
    end
  end
  pin:SetFrameLevel(level or ((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 20))
end

-- Ring slot n (1, 2, ...) -> pixel offset, radius r (6 slots per ring).
function QP.SpreadOffset(n, r)
  if not n then return 0, 0 end
  local ring = math.floor((n - 1) / 6) + 1
  local a = ((n - 1) % 6) * math.pi / 3 + (ring - 1) * math.pi / 6
  return math.cos(a) * r * ring, math.sin(a) * r * ring
end

function QP:Groups(mapID, level)
  local W = PSS.QuestWorth
  local groups, byKey = {}, {}
  for _, x in ipairs(W:OnMap(mapID, level)) do
    local r = x.r
    if not QP:IsHiddenGiver(r.g, mapID, r.x, r.y) then
    local key = (r.g or 0) .. ":" .. r.x .. ":" .. r.y
    local g = byKey[key]
    if not g then
      g = {npc = r.g, x = r.x, y = r.y, mapID = mapID, quests = {}, best = "skip"}
      byKey[key] = g
      groups[#groups + 1] = g
    end
    g.quests[#g.quests + 1] = x
    if ORDER[x.rate.verdict] < ORDER[g.best] then g.best = x.rate.verdict end
    end
  end
  -- One pin per quest giver: the same NPC listed at slightly different
  -- spots is merged; different NPCs never are. Pins of different givers that
  -- would overlap are spread around the spot (g.spread = 1, 2, ... = ring slot).
  local merged = {}
  for _, g in ipairs(groups) do
    local into
    for _, m in ipairs(merged) do
      local dx, dy = g.x - m.x, g.y - m.y
      if g.npc and m.npc == g.npc and dx * dx + dy * dy < 1.0 then into = m break end
    end
    if into then
      for _, q in ipairs(g.quests) do into.quests[#into.quests + 1] = q end
      if ORDER[g.best] < ORDER[into.best] then into.best = g.best end
    else
      merged[#merged + 1] = g
    end
  end
  for i2, g in ipairs(merged) do
    local n = 0
    for k = 1, i2 - 1 do
      local m = merged[k]
      local dx, dy = g.x - m.x, g.y - m.y
      if dx * dx + dy * dy < 0.36 then n = n + 1 end
    end
    g.spread = n > 0 and n or nil
  end
  return merged
end

-- Our "!" sits a little up and right of the giver (the game draws its own "!"
-- right on the giver) on a round backing in the rating colour, so a grey
-- "not worth it" pin is readable even next to the game's yellow one.
QP.OFFSET = 9
local DISC = "Interface/CHARACTERFRAME/TempPortraitAlphaMask"
local function Backing(pin)
  if pin.disc then return end
  pin.discEdge = pin:CreateTexture(nil, "BACKGROUND", nil, -2)
  pin.discEdge:SetTexture(DISC)
  pin.discEdge:SetPoint("CENTER")
  pin.disc = pin:CreateTexture(nil, "BACKGROUND", nil, -1)
  pin.disc:SetTexture(DISC)
  pin.disc:SetPoint("CENTER")
end
QP.Backing = Backing
function QP:Style(pin, verdict)
  Backing(pin)
  local size = verdict == "great" and 22 or 18
  pin.discEdge:SetSize(size + 4, size + 4)
  pin.disc:SetSize(size, size)
  if verdict == "great" then
    pin.discEdge:SetVertexColor(0.74, 0.45, 1, 1); pin.disc:SetVertexColor(0.16, 0.06, 0.26, 0.95)
  elseif verdict == "skip" then
    pin.discEdge:SetVertexColor(0.55, 0.55, 0.55, 1); pin.disc:SetVertexColor(0.08, 0.08, 0.08, 0.9)
  else
    pin.discEdge:SetVertexColor(1, 0.82, 0, 1); pin.disc:SetVertexColor(0.18, 0.13, 0.02, 0.9)
  end
  pin.icon:SetDesaturated(verdict ~= "ok")
  local c = PSS.QuestWorth.COLORS[verdict]
  if verdict == "ok" then pin.icon:SetVertexColor(1, 1, 1) else pin.icon:SetVertexColor(c[1] * 1.2, c[2] * 1.2, c[3] * 1.2) end
  pin:SetSize(verdict == "great" and 22 or 18, verdict == "great" and 22 or 18)
  pin:SetAlpha(1)
end

local function Update()
  if not (PSS.Map and PSS.Map.GetCanvasInfo and PSS.QuestWorth) then return end
  local canvas, mapID, width, height, scale = PSS.Map:GetCanvasInfo()
  if not canvas or not QP:Enabled() then HideAll(); last.mapID = false; return end
  local level = PSS.QuestWorth:PlayerLevel()
  if not dirty and last.mapID == mapID and last.width == width and last.height == height
     and last.scale == scale and last.level == level then return end
  last.mapID, last.width, last.height, last.scale, last.level = mapID, width, height, scale, level
  dirty = false
  HideAll()
  local used = 0
  for _, g in ipairs(QP:Groups(mapID, level)) do
    if g.best ~= "skip" or QP:ShowSkip() then
      used = used + 1
      local pin = Ensure(used, canvas)
      pin.group = g
      QP:Style(pin, g.best)
      PSS.Map:Place(pin, canvas, g.x, g.y, width, height, scale)
      local pt, rel, rp, x, y = pin:GetPoint(1)
      local sx, sy = QP.SpreadOffset(g.spread, 14)
      if pt then pin:SetPoint(pt, rel, rp, x + QP.OFFSET + sx, y + QP.OFFSET + sy) end
      pin:Show()
    end
  end
  QP.shown = used
  QP:UpdateObjectives(canvas, mapID, width, height, scale)
end
QP.Update = Update

-- Objectives of quests in your log (first objective position from the
-- database): a small target mark, under the game's own quest icons.
local objPins = {}
function QP:ObjectivesOn() return QP:Enabled() and DB().questObjPins ~= false end
function QP:LogQuests()
  local out = {}
  local api = C_QuestLog
  if api and api.GetNumQuestLogEntries and api.GetInfo then
    local n = tonumber(PSS.IsSecret(api.GetNumQuestLogEntries()) and 0 or api.GetNumQuestLogEntries()) or 0
    for i = 1, n do
      local ok, info = pcall(api.GetInfo, i)
      if ok and type(info) == "table" and not info.isHeader and info.questID and not PSS.IsSecret(info.questID) then
        local done = api.IsComplete and select(2, pcall(api.IsComplete, info.questID))
        out[#out + 1] = {id = info.questID, done = done == true, title = info.title}
      end
    end
  elseif GetNumQuestLogEntries and GetQuestLogTitle then
    local n = tonumber((GetNumQuestLogEntries())) or 0
    for i = 1, n do
      local title, _, _, header, _, complete, _, id = GetQuestLogTitle(i)
      if not header and id then out[#out + 1] = {id = id, done = complete == 1, title = title} end
    end
  end
  return out
end
function QP:UpdateObjectives(canvas, mapID, width, height, scale)
  for _, p in ipairs(objPins) do p:Hide() end
  if not self:ObjectivesOn() then return end
  local used = 0
  for _, q in ipairs(self:LogQuests()) do
    local r = PSS.QuestDB and PSS.QuestDB[q.id]
    if r and r.om == mapID and r.ox and not q.done then
      used = used + 1
      local pin = objPins[used]
      if not pin then
        pin = CreateFrame("Frame", nil, canvas)
        pin:SetSize(14, 14)
        pin.icon = pin:CreateTexture(nil, "ARTWORK")
        pin.icon:SetAllPoints(pin)
        pin.icon:SetTexture("Interface/TargetingFrame/UI-RaidTargetingIcon_8")
        pin:EnableMouse(true)
        pin:SetScript("OnEnter", function(self)
          if not GameTooltip then return end
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:AddLine(PSS:Safe(self.title or "?"), 1, 0.82, 0)
          GameTooltip:AddLine(PSS:Safe(PSS:L("qObjective")), 0.8, 0.8, 0.8)
          GameTooltip:Show()
        end)
        pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        objPins[used] = pin
      end
      if pin:GetParent() ~= canvas then pin:SetParent(canvas) end
      QP.Lower(pin, canvas)
      pin.title = q.title or (PSS.QuestWorth and PSS.QuestWorth:Title(q.id)) or r.n
      PSS.Map:Place(pin, canvas, r.ox, r.oy, width, height, scale)
      pin:SetAlpha(0.85)
      pin:Show()
    end
  end
end

local driver = CreateFrame("Frame")
PSS:OnlyWithWorldMap(driver)
QP._driver = driver
driver:SetScript("OnUpdate", function(_, elapsed)
  elapsedSince = elapsedSince + (elapsed or 0)
  if elapsedSince < 0.25 then return end
  elapsedSince = 0
  local ok, err = pcall(Update)
  if not ok then QP._lastError = tostring(err) end
end)
local ev = CreateFrame("Frame")
for _, e in ipairs({"QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED",
    "UNIT_QUEST_LOG_CHANGED", "QUESTLINE_UPDATE"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() QP:Refresh() end)
driver.pssKey = "QuestPins"
PSS:Every(driver, 0.25)
