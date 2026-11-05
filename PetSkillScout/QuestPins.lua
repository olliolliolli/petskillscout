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
    pin:SetScript("OnClick", function(self)
      local g = self.group
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
function QP:Groups(mapID, level)
  local W = PSS.QuestWorth
  local groups, byKey = {}, {}
  for _, x in ipairs(W:OnMap(mapID, level)) do
    local r = x.r
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
  return groups
end

function QP:Style(pin, verdict)
  pin.icon:SetDesaturated(verdict ~= "ok")
  local c = PSS.QuestWorth.COLORS[verdict]
  if verdict == "ok" then pin.icon:SetVertexColor(1, 1, 1) else pin.icon:SetVertexColor(c[1] * 1.2, c[2] * 1.2, c[3] * 1.2) end
  pin:SetSize(verdict == "great" and 22 or 18, verdict == "great" and 22 or 18)
  pin:SetAlpha(verdict == "skip" and 0.75 or 1)
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
