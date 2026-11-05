-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Realm network: every PetSkillScout user joins a hidden chat channel, so rare
-- sightings, kills, taming queues and ranking data reach all hunters with the
-- addon on the realm, not only the guild. The channel is removed from every chat
-- window, so nothing appears in chat. It can be switched off in Settings.
local PSS = PetSkillScout
PSS.Net = {}
local N = PSS.Net
N.CHANNEL = "PSSNet1"
local HELLO_EVERY, PEER_ONLINE, PEER_KEEP = 1200, 1800, 7 * 86400

local function Now() return time and time() or 0 end
local function Enabled()
  return PetSkillScoutDB and PetSkillScoutDB.netEnabled ~= false and PetSkillScoutDB.syncEnabled ~= false
end
N.Enabled = Enabled

local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
end

function N:ChannelID()
  if not Enabled() then return nil end
  local id = safe(GetChannelName, self.CHANNEL)
  if type(id) == "number" and id > 0 then return id end
end

-- Joining a channel from addon code is forbidden on this client, so the
-- player joins with one click on a secure button that runs "/join PSSNet1"
-- (the same as typing it). The client then rejoins it at every login.
-- Join / leave notices of the channel are filtered out of the chat.
local function IsOurs(...)
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if type(v) == "string" and not (PSS.IsSecret and PSS.IsSecret(v)) and v:find(N.CHANNEL, 1, true) then return true end
  end
  return false
end
local function NoticeFilter(_, _, ...)
  local ok, ours = pcall(IsOurs, ...)
  return ok and ours or false
end
if ChatFrame_AddMessageEventFilter then
  for _, e in ipairs({"CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL"}) do
    pcall(ChatFrame_AddMessageEventFilter, e, PSS:Timed("chat filter", NoticeFilter))
  end
end

local connect
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function MakeConnect()
  if connect or InCombat() then return connect end
  local b = CreateFrame("Button", "PetSkillScoutNetConnect", UIParent, "SecureActionButtonTemplate")
  b:SetSize(330, 54)
  b:SetPoint("TOP", UIParent, "TOP", 0, -140)
  b:SetFrameStrata("FULLSCREEN_DIALOG")
  b:SetToplevel(true)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", "/join " .. N.CHANNEL)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Buttons\\WHITE8X8")
  bg:SetVertexColor(0.05, 0.09, 0.07, 0.95)
  bg:SetAllPoints(b)
  local edge = b:CreateTexture(nil, "BORDER")
  edge:SetTexture("Interface\\Buttons\\WHITE8X8")
  edge:SetVertexColor(0.85, 0.68, 0.36, 1)
  edge:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
  edge:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
  edge:SetHeight(2)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture("Interface\\Buttons\\WHITE8X8")
  hl:SetVertexColor(0.85, 0.68, 0.36, 0.15)
  hl:SetAllPoints(b)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\AddOns\\PetSkillScout\\Textures\\PetSkillScoutLogo")
  icon:SetSize(40, 40)
  icon:SetPoint("LEFT", b, "LEFT", 8, 0)
  b.title = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.title:SetPoint("TOPLEFT", b, "TOPLEFT", 56, -10)
  b.title:SetWidth(240)
  b.title:SetJustifyH("LEFT")
  b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.sub:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -4)
  b.sub:SetWidth(240)
  b.sub:SetJustifyH("LEFT")
  b:SetScript("PostClick", function(self, _, down)
    if not PSS:ClickRan(down) then return end
    N.dismissed = true
    if not InCombat() then self:Hide() end
    N.checkIn = 3 -- confirm the channel shortly after joining
  end)
  -- Plain child button: closes the prompt for this session.
  local close = CreateFrame("Button", nil, b)
  close:SetSize(22, 22)
  close:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
  close.text = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  close.text:SetPoint("CENTER")
  close.text:SetText("X")
  close:SetScript("OnClick", function()
    N.dismissed = true
    if not InCombat() then b:Hide() end
    PSS:Print(PSS:L("netLater"))
  end)
  b:Hide()
  connect = b
  return b
end

-- Shows the one-click connect prompt (never in combat).
function N:ShowConnect(force, anchor)
  if not Enabled() or self:ChannelID() then return false end
  if self.dismissed and not force then return false end
  local b = MakeConnect()
  if not b or InCombat() then return false end
  b:ClearAllPoints()
  if anchor then
    -- Right under the button that asked for it (e.g. the header network chip).
    -- Screen position, not an anchor: a secure button tied to our window
    -- would be blocked when the window moves or closes in combat.
    local right, bottom = anchor:GetRight(), anchor:GetBottom()
    local ratio = (anchor:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    if right and bottom then
      b:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right * ratio, bottom * ratio - 6)
    else
      b:SetPoint("TOP", UIParent, "TOP", 0, -140)
    end
  else
    b:SetPoint("TOP", UIParent, "TOP", 0, -140)
  end
  b.title:SetText(PSS:Safe(PSS:L("netConnectTitle")))
  b.sub:SetText(PSS:Safe(PSS:L("netConnectSub")))
  b:Show()
  return true
end

function N:Join() return self:ShowConnect(true) end

-- Auto-join: the minimap button and the floating icon are secure buttons
-- too. While you are not in the channel, their left click also runs
-- "/join PSSNet1" (the same as typing it) - so the first time you open the
-- addon you are connected, no extra prompt. Attributes change out of combat.
N.joinButtons = {}
function N:AddJoinButton(b)
  if not b then return end
  self.joinButtons[#self.joinButtons + 1] = b
  self:UpdateJoinButtons()
end
-- After a click that may have joined: confirm in a moment, then drop the macro.
function N:AfterJoinClick()
  if not self:ChannelIDRaw() and Enabled() then self.checkIn = 3 end
end
function N:UpdateJoinButtons()
  if InCombat() then self.joinPending = true return end
  self.joinPending = false
  local want = Enabled() and PetSkillScoutDB and PetSkillScoutDB.netAutoJoin ~= false and not self:ChannelIDRaw()
  for _, b in ipairs(self.joinButtons) do
    if want then
      b:SetAttribute("type1", "macro")
      b:SetAttribute("macrotext1", "/join " .. N.CHANNEL)
    else
      b:SetAttribute("type1", nil)
      b:SetAttribute("macrotext1", nil)
    end
  end
end

function N:Leave()
  if connect and not InCombat() then connect:Hide() end
  if self:ChannelIDRaw() then PSS:Print(string.format(PSS:L("netLeaveHint"), self.CHANNEL)) end
end

function N:ChannelIDRaw()
  local id = safe(GetChannelName, self.CHANNEL)
  if type(id) == "number" and id > 0 then return id end
end

-- Peers: everyone who sent anything recently, plus their ranking data.
local function Peers()
  PetSkillScoutDB.peers = PetSkillScoutDB.peers or {}
  return PetSkillScoutDB.peers
end

function N:Seen(who, dist)
  if not PetSkillScoutDB then return end
  local p = Peers()[who] or {}
  p.t = Now()
  if dist == "GUILD" then p.guild = true end
  Peers()[who] = p
end

function N:OnlineCount()
  if not PetSkillScoutDB then return 0 end
  local n, now = 1, Now() -- you
  for _, p in pairs(Peers()) do if p.t and now - p.t < PEER_ONLINE then n = n + 1 end end
  return n
end

-- version compare: "1.10.0" > "1.9.2"
local function Newer(a, b)
  local pa, pb = {}, {}
  for n in tostring(a):gmatch("%d+") do table.insert(pa, tonumber(n)) end
  for n in tostring(b):gmatch("%d+") do table.insert(pb, tonumber(n)) end
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x > y end
  end
  return false
end
N.Newer = Newer

local newerSeen, warned = {}, false
local function CheckVersion(who, ver)
  if warned or not ver or not Newer(ver, PSS.version or "0") then return end
  newerSeen[who] = ver
  local n = 0
  for _ in pairs(newerSeen) do n = n + 1 end
  -- Two different players, so one odd client cannot trigger it.
  if n >= 2 then
    warned = true
    PSS:Print(string.format(PSS:L("netNewVersion"), ver))
  end
end

-- H~version~score~skins~rares~families~guildName
function N:HelloMessage()
  local A = PSS.Achieve
  local score, skins, rares, fams = 0, 0, 0, 0
  if A and A.Stats then score, skins, rares, fams = A:Stats() end
  local guild = GetGuildInfo and safe(GetGuildInfo, "player") or ""
  guild = tostring(guild or ""):gsub(PSS.Sync.SEP, ""):sub(1, 30)
  return table.concat({"H", tostring(PSS.version or "?"), score, skins, rares, fams, guild}, PSS.Sync.SEP)
end

local lastHello = -1e9
function N:Hello(force)
  if not (PSS.Sync and PetSkillScoutDB and PetSkillScoutDB.syncEnabled ~= false) then return end
  local now = Now()
  if not force and now - lastHello < 120 then self.pendingHello = true return end
  lastHello, self.pendingHello = now, nil
  PSS.Sync:SendAll(self:HelloMessage(), true)
  if PSS.Showcase then PSS.Showcase:Send() end
end

local function OnHello(parts, who, dist)
  local p = Peers()[who] or {}
  p.t, p.v = Now(), parts[2]
  p.score, p.skins, p.rares, p.fams = tonumber(parts[3]) or 0, tonumber(parts[4]) or 0, tonumber(parts[5]) or 0, tonumber(parts[6]) or 0
  p.g = parts[7] ~= "" and parts[7] or nil
  if dist == "GUILD" then p.guild = true end
  Peers()[who] = p
  CheckVersion(who, parts[2])
  if PSS.UI and PSS.UI.view == "collection" and PSS.UI.UpdateCollection then PSS.UI:UpdateCollection() end
end

-- Ranking rows: { name, score, skins, rares, fams, me, online, guild }
function N:Ranking(scope)
  local list = {}
  local now = Now()
  local myGuild = GetGuildInfo and safe(GetGuildInfo, "player")
  for name, p in pairs(PetSkillScoutDB and Peers() or {}) do
    if p.score and p.t and now - p.t < PEER_KEEP then
      local inGuild = p.guild or (myGuild and p.g == myGuild)
      if scope ~= "guild" or inGuild then
        table.insert(list, {name = name, score = p.score, skins = p.skins or 0, rares = p.rares or 0,
          fams = p.fams or 0, online = now - p.t < PEER_ONLINE, guild = inGuild})
      end
    end
  end
  local me = UnitName and UnitName("player") or "?"
  local score, skins, rares, fams = 0, 0, 0, 0
  if PSS.Achieve and PSS.Achieve.Stats then score, skins, rares, fams = PSS.Achieve:Stats() end
  table.insert(list, {name = me, score = score, skins = skins, rares = rares, fams = fams, online = true, me = true, guild = true})
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.skins ~= b.skins then return a.skins > b.skins end
    return a.name < b.name
  end)
  return list
end

local function Prune()
  if not PetSkillScoutDB then return end
  local now, n = Now(), 0
  for name, p in pairs(Peers()) do
    if not p.t or now - p.t > PEER_KEEP then Peers()[name] = nil else n = n + 1 end
  end
  -- Keep the saved table small on busy realms: drop the oldest without a score.
  if n > 600 then
    for name, p in pairs(Peers()) do if not p.score then Peers()[name] = nil end end
  end
end

N.frame = CreateFrame("Frame")
N.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(N.frame.RegisterEvent, N.frame, "PLAYER_REGEN_ENABLED")
local promptIn, helloIn = nil, nil
N.frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    if not N.started then
      N.started = true
      pcall(Prune)
      promptIn, helloIn = 15, 18
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if N.joinPending then pcall(N.UpdateJoinButtons, N) end
    if N.wantPrompt then N.wantPrompt = nil; pcall(N.ShowConnect, N) end
  end
end)
N.frame:SetScript("OnUpdate", function(_, elapsed)
  elapsed = elapsed or 0
  -- A score change during the throttle window is sent once it ends.
  if N.pendingHello and Now() - lastHello >= 120 then pcall(N.Hello, N) end
  if promptIn then
    promptIn = promptIn - elapsed
    if promptIn <= 0 then
      promptIn = nil
      if InCombat() then N.wantPrompt = true else pcall(N.ShowConnect, N) end
    end
  end
  if N.checkIn then
    N.checkIn = N.checkIn - elapsed
    if N.checkIn <= 0 then
      N.checkIn = nil
      pcall(N.UpdateJoinButtons, N)
      if N:ChannelID() then
        if connect and not InCombat() then connect:Hide() end
        PSS:Print(PSS:L("netJoined"))
        pcall(N.Hello, N, true)
      end
    end
  end
  if helloIn then
    helloIn = helloIn - elapsed
    if helloIn <= 0 then
      helloIn = HELLO_EVERY + math.random(0, 120)
      pcall(N.Hello, N, true)
    end
  end
end)

if PSS.Sync then PSS.Sync.handlers.H = OnHello end
N.frame.pssKey = "Net"
PSS:Every(N.frame, 0.5)
