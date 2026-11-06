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
  GameTooltip:AddLine(PSS:Safe(W:NPCName(g.npc) or PSS:L("qwGiverUnknown")), 1, 0.82, 0)
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
  if PSS.Map.RaisePin then PSS.Map:RaisePin(pin, 9400) end
  return pin
end

-- Group the available quests of a map by quest giver position.
-- Givers the player marked as "not here" (right click on the pin): the
-- database position is wrong or the NPC appears only in some phase.
-- Key: npc:mapID. /pss pinsreset brings them back.
local function GiverKey(npc, mapID) return tostring(npc or 0) .. ":" .. tostring(mapID or 0) end
function QP:IsHiddenGiver(npc, mapID)
  local h = DB().questPinHidden
  return h and h[GiverKey(npc, mapID)] ~= nil
end
function QP:HideGiver(g)
  if not PetSkillScoutDB then return end
  PetSkillScoutDB.questPinHidden = PetSkillScoutDB.questPinHidden or {}
  PetSkillScoutDB.questPinHidden[GiverKey(g.npc, g.mapID)] = time and time() or 0
  if GameTooltip then GameTooltip:Hide() end
  PSS:Print(string.format(PSS:L("qPinHidden"), PSS.QuestWorth:NPCName(g.npc) or "?"))
  QP:Refresh()
end
function QP:ResetHidden()
  if PetSkillScoutDB then PetSkillScoutDB.questPinHidden = nil end
  QP:Refresh()
end

function QP:Groups(mapID, level)
  local W = PSS.QuestWorth
  local groups, byKey = {}, {}
  for _, x in ipairs(W:OnMap(mapID, level)) do
    local r = x.r
    if not QP:IsHiddenGiver(r.g, mapID) then
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
  return groups
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
      if pt then pin:SetPoint(pt, rel, rp, x + QP.OFFSET, y + QP.OFFSET) end
      pin:Show()
    end
  end
  QP.shown = used
end
QP.Update = Update

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
for _, e in ipairs({"QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "PLAYER_EQUIPMENT_CHANGED"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function() QP:Refresh() end)
driver.pssKey = "QuestPins"
PSS:Every(driver, 0.25)
