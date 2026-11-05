-- Taming queue at rare spawns: hunters with PetSkillScout who wait for the same
-- rare see who came first and whose turn it is. You join automatically when you
-- are near the spawn area of a rare you marked as wanted (or with the Join
-- button); the queue is shared through the realm network and your group.
--   Q~rare~j~age  joined (age = seconds since joining)
--   Q~rare~p~age  still here (every minute)
--   Q~rare~l~0    left
--   Q~rare~d~0    tamed it
local PSS = PetSkillScout
PSS.Queue = {lists = {}}
local Q = PSS.Queue
local PING, EXPIRE, NEAR, FAR = 60, 180, 150, 450

local function Now() return time and time() or 0 end
local function L(key) return PSS:L(key) end
local function Me() return UnitName and UnitName("player") or "?" end
local function Enabled() return not PetSkillScoutDB or PetSkillScoutDB.queueEnabled ~= false end

local function List(id)
  Q.lists[id] = Q.lists[id] or {}
  return Q.lists[id]
end

local function Send(op, id, age)
  if PSS.Sync then PSS.Sync:SendAll(table.concat({"Q", id, op, tostring(math.floor(age or 0))}, PSS.Sync.SEP), true) end
end

-- Ordered queue: { {who, joined, me}, ... }
function Q:Ordered(id)
  local now, out = Now(), {}
  for who, r in pairs(List(id)) do
    if who == Me() or now - (r.ping or 0) < EXPIRE then
      table.insert(out, {who = who, joined = r.joined, me = who == Me()})
    else
      List(id)[who] = nil
    end
  end
  table.sort(out, function(a, b)
    if a.joined ~= b.joined then return a.joined < b.joined end
    return a.who < b.who
  end)
  return out
end

function Q:Position(id)
  for i, r in ipairs(self:Ordered(id)) do if r.me then return i end end
end

local function EntryById(id)
  local R = PSS.RarePets
  if not R then return nil end
  if not R.entries or #R.entries == 0 then R:Build() end
  for _, e in ipairs(R.entries) do if e.id == id then return e end end
end

function Q:Join(entry)
  if not (entry and Enabled()) then return end
  if self.mine == entry.id then return end
  if self.mine then self:Leave() end
  self.mine, self.since, self.lastPing, self.away = entry.id, Now(), Now(), nil
  List(entry.id)[Me()] = {joined = self.since, ping = self.since}
  Send("j", entry.id, 0)
  local pos = self:Position(entry.id)
  PSS:Print(string.format(L("queueJoined"), entry.name, pos or 1))
  self:Refresh()
end

function Q:Leave(silent)
  if not self.mine then return end
  Send("l", self.mine, 0)
  List(self.mine)[Me()] = nil
  if not silent then PSS:Print(string.format(L("queueLeft"), (EntryById(self.mine) or {}).name or "?")) end
  self.mine, self.since = nil, nil
  self:Refresh()
end

-- You tamed the rare: tell the others and leave the queue.
function Q:Done(entry)
  if not entry then return end
  if self.mine == entry.id then
    Send("d", entry.id, 0)
    List(entry.id)[Me()] = nil
    if self.since and Now() - self.since > 30 and PetSkillScoutDB then
      PetSkillScoutDB.queueTames = (PetSkillScoutDB.queueTames or 0) + 1
    end
    self.mine, self.since = nil, nil
    self:Refresh()
  end
end

local function OnQueue(parts, who)
  local id, op, age = parts[2], parts[3], tonumber(parts[4]) or 0
  if not (id and EntryById(id)) then return end
  local list = List(id)
  local now = Now()
  if op == "j" or op == "p" then
    if age < 0 or age > 6 * 3600 then return end
    local r = list[who] or {}
    -- Keep the earliest join time we heard for this player.
    local joined = now - age
    if op == "j" or not r.joined then r.joined = joined else r.joined = math.min(r.joined, joined) end
    r.ping = now
    list[who] = r
  elseif op == "l" then
    list[who] = nil
  elseif op == "d" then
    list[who] = nil
    if Q.mine == id then
      local entry = EntryById(id)
      local pos = Q:Position(id)
      PSS:Print(string.format(L("queueTamedBy"), who, entry and entry.name or "?", pos or 1))
    end
  end
  Q:Refresh()
end

-- Rare spotted: tell the player whether it is their turn.
function Q:OnSpotted(entry)
  if not (entry and self.mine == entry.id) then return end
  local pos = self:Position(entry.id)
  if pos == 1 then
    PSS:Print(L("queueYourTurn"))
    if RaidNotice_AddMessage and RaidWarningFrame then
      pcall(RaidNotice_AddMessage, RaidWarningFrame, PSS:Safe(L("queueYourTurn")), ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
    end
  elseif pos then
    local first = self:Ordered(entry.id)[1]
    PSS:Print(string.format(L("queueNotYet"), pos, first and first.who or "?"))
  end
end

-- Automatic join / leave by distance to the spawn area -------------------------
local function NearestRare()
  local R, Nav = PSS.RarePets, PSS.Nav
  if not (R and Nav) then return nil end
  local mapID, px, py = Nav:PlayerPos()
  if not mapID then return nil end
  if not R.entries or #R.entries == 0 then R:Build() end
  local best, bestD
  for _, e in ipairs(R.entries) do
    if e.beast.mapID == mapID and not R:IsCollected(e) then
      local t = Nav:TargetFromBeast(e.beast)
      if t then
        local _, _, d = Nav:Nearest(t, mapID, px, py)
        if d and (not bestD or d < bestD) then best, bestD = e, d end
      end
    end
  end
  return best, bestD
end
Q.NearestRare = NearestRare

function Q:Tick()
  if not Enabled() then if self.mine then self:Leave(true) end return end
  local R = PSS.RarePets
  local entry, d = NearestRare()
  self.near, self.nearDist = entry, d
  local now = Now()
  if self.mine then
    local mineEntry = EntryById(self.mine)
    if mineEntry and R and R:IsCollected(mineEntry) then self:Done(mineEntry) return end
    local here = entry and entry.id == self.mine and d and d < FAR
    if here then self.away = nil
    else
      self.away = self.away or now
      if now - self.away > 120 then self:Leave() return end
    end
    if now - (self.lastPing or 0) >= PING then
      self.lastPing = now
      List(self.mine)[Me()] = {joined = self.since, ping = now}
      Send("p", self.mine, now - self.since)
    end
  elseif entry and d and d < NEAR and R:IsWanted(entry) and (not PetSkillScoutDB or PetSkillScoutDB.queueAuto ~= false) then
    if self.declined ~= entry.id then self:Join(entry) end
  end
  self:Refresh()
end

-- Small on-screen panel ----------------------------------------------------------
local panel
local LINES = 6
local function MakePanel()
  if panel then return panel end
  panel = CreateFrame("Frame", "PetSkillScoutQueue", UIParent)
  panel:SetSize(240, 60)
  panel:SetFrameStrata("MEDIUM")
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", function(f) if IsShiftKeyDown and IsShiftKeyDown() then f:StartMoving() end end)
  panel:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    local x, y = f:GetCenter()
    if PetSkillScoutDB and x then PetSkillScoutDB.queuePos = {x = x, y = y} end
  end)
  local pos = PetSkillScoutDB and PetSkillScoutDB.queuePos
  if pos and pos.x then panel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
  else panel:SetPoint("TOP", UIParent, "TOP", 0, -210) end
  local bg = panel:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(0.05, 0.07, 0.06, 0.88)
  bg:SetAllPoints(panel)
  local line = panel:CreateTexture(nil, "BORDER")
  line:SetTexture("Interface\\Buttons\\WHITE8X8")
  line:SetVertexColor(0.85, 0.68, 0.36, 1)
  line:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
  line:SetHeight(2)
  panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
  panel.title:SetWidth(170)
  panel.title:SetJustifyH("LEFT")
  panel.lines = {}
  for i = 1, LINES do
    local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -12 - i * 16)
    fs:SetWidth(216)
    fs:SetJustifyH("LEFT")
    panel.lines[i] = fs
  end
  panel.button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  panel.button:SetSize(64, 20)
  panel.button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -5)
  panel.button:SetScript("OnClick", function()
    if Q.mine then
      Q.declined = Q.mine
      Q:Leave()
    elseif Q.near then
      Q.declined = nil
      Q:Join(Q.near)
    end
  end)
  panel:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(PSS:Safe(L("queueTitle")))
    GameTooltip:AddLine(PSS:Safe(L("queueHint")), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  panel:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  panel:Hide()
  return panel
end

local function Ago(sec)
  if PSS.RareTimer then return PSS.RareTimer:Duration(sec) end
  return string.format(L("unitMin"), math.floor(sec / 60))
end

function Q:Refresh()
  if PSS.UI and PSS.UI.view == "rares" and PSS.UI.UpdateRares then PSS.UI:UpdateRares() end
  local id = self.mine or (self.near and self.nearDist and self.nearDist < FAR and self.near.id)
  local list = id and self:Ordered(id) or {}
  local show = Enabled() and id and (self.mine or #list > 0)
  if not show then if panel then panel:Hide() end return end
  MakePanel()
  local entry = EntryById(id)
  panel.title:SetText(PSS:Safe(string.format(L("queueFor"), entry and entry.name or "?")))
  panel.button:SetText(PSS:Safe(self.mine and L("queueLeave") or L("queueJoin")))
  local now = Now()
  for i, fs in ipairs(panel.lines) do
    local r = list[i]
    if r then
      local name = r.me and ("|cffe3c06d" .. L("queueYou") .. "|r") or r.who
      fs:SetText(PSS:Safe(string.format("%d. %s  -  %s", i, name, Ago(now - r.joined))))
      fs:Show()
    elseif i == #list + 1 and #list > LINES then
      fs:SetText("...")
      fs:Show()
    else
      fs:Hide()
    end
  end
  if #list == 0 then
    panel.lines[1]:SetText(PSS:Safe(L("queueEmpty")))
    panel.lines[1]:Show()
  end
  panel:SetHeight(36 + math.max(1, math.min(#list, LINES)) * 16)
  panel:Show()
end

-- Text for the rare tiles: "3 hunters waiting" / "you are 2nd".
function Q:TileText(entry)
  local list = self:Ordered(entry.id)
  if #list == 0 then return nil end
  local pos = self:Position(entry.id)
  if pos then return string.format(L("queueTilePos"), pos, #list) end
  return string.format(L("queueTileCount"), #list)
end

if PSS.Sync then PSS.Sync.handlers.Q = OnQueue end

Q.frame = CreateFrame("Frame")
local tick = 0
Q.frame:SetScript("OnUpdate", function(_, elapsed)
  tick = tick + (elapsed or 0)
  if tick < 5 then return end
  tick = 0
  pcall(Q.Tick, Q)
end)
Q.frame.pssKey = "Queue"
PSS:Every(Q.frame, 1)
