-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Hidden addon messages between PetSkillScout users: guild, group and the realm
-- network (a hidden chat channel every PetSkillScout user joins). Nothing here
-- writes to visible chat; received data is only stored and displayed.
--   S~npc~rare~map~x~y        rare seen alive
--   K~npc~rare~age~how        rare died / was tamed (age in seconds)
--   V~npc~map~x~y~kinds~name  ammo vendor
--   H~ver~score~skins~rares~families~guild   hello / ranking (Net.lua)
--   Q~rare~op~age             taming queue (Queue.lua)
--   R~pet / C~...             pet card request / reply by whisper (PetLink.lua)
local PSS = PetSkillScout
PSS.Sync = {handlers = {}}
local S = PSS.Sync
local PREFIX = "PSSRare1"
local SEP = "~"
S.PREFIX, S.SEP = PREFIX, SEP
local lastSent, lastAny, lastNotified = {}, -1e9, {}

local function Enabled() return not PetSkillScoutDB or PetSkillScoutDB.syncEnabled ~= false end
local function Now() return GetTime and GetTime() or 0 end
S.Enabled = Enabled

local registered = false
local function Register()
  if registered then return true end
  local fn = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
  if type(fn) == "function" and pcall(fn, PREFIX) then registered = true end
  return registered
end
S.Register = Register

-- Sending with a small token bucket so bursts never hit the server throttle.
local queue, tokens, lastRefill = {}, 8, nil
local function RawSend(msg, dist, target)
  if dist == "WHISPER" and PSS.Net and PSS.Net.NoteWhisper and type(target) == "string" then PSS.Net:NoteWhisper(target) end
  local fn = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
  if type(fn) == "function" then S:NoteSent(msg); pcall(fn, PREFIX, msg, dist, target) end
end
local function Refill()
  local now = Now()
  if lastRefill then tokens = math.min(8, tokens + (now - lastRefill)) end
  lastRefill = now
end
-- WoW Forever accepts addon messages in chat channels but never delivers
-- them, and channel text from addons is only allowed during a key press
-- (/pss netdiag). The realm network therefore whispers each member of the
-- network channel (Net.lua keeps the list); the token bucket below paces it.
function S:Send(msg, dist, target)
  if type(msg) ~= "string" or #msg > 250 then return end
  if dist == "CHANNEL" then
    local N = PSS.Net
    if not (N and N.Members) then return end
    for _, m in ipairs(N:Members(msg:match("^(%a)"))) do self:Send(msg, "WHISPER", m.target) end
    return
  end
  if not Register() then return end
  Refill()
  if tokens >= 1 and #queue == 0 then
    tokens = tokens - 1
    RawSend(msg, dist, target)
  elseif #queue < 120 then
    table.insert(queue, {msg, dist, target})
  end
end

-- Distributions for a broadcast. net = also send to the realm network.
local function Channels(net)
  local out = {}
  if IsInGuild and IsInGuild() then table.insert(out, {"GUILD"}) end
  if IsInRaid and IsInRaid() then
    table.insert(out, {"RAID"})
  elseif (IsInGroup and IsInGroup()) or (GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) then
    table.insert(out, {"PARTY"})
  end
  if net and PSS.Net then
    local id = PSS.Net:ChannelID()
    if id then table.insert(out, {"CHANNEL", id}) end
  end
  return out
end
S.Channels = Channels

function S:SendAll(msg, net)
  if type(msg) ~= "string" or #msg > 250 then return false end
  local channels = Channels(net)
  for _, c in ipairs(channels) do self:Send(msg, c[1], c[2]) end
  if #channels > 0 and PSS.NetFeed then pcall(PSS.NetFeed.OnSent, PSS.NetFeed, msg) end
  return #channels > 0
end
local function SendAll(msg) return S:SendAll(msg, true) end

-- Called when this player sees a rare (RarePets:RecordSeen).
function S:Broadcast(entry, rec)
  if not (Enabled() and entry and rec and Register()) then return end
  local now = Now()
  if lastSent[entry.id] and now - lastSent[entry.id] < 120 then return end
  if now - lastAny < 2 then return end
  local channels = Channels(true)
  if #channels == 0 then return end
  lastSent[entry.id], lastAny = now, now
  local npc = entry.beast and tonumber(entry.beast.npcID) or 0
  local msg = table.concat({"S", tostring(npc), entry.id, tostring(rec.mapID or 0),
    rec.x and string.format("%.1f", rec.x) or "", rec.y and string.format("%.1f", rec.y) or ""}, SEP)
  if #msg > 250 then return end
  for _, c in ipairs(channels) do self:Send(msg, c[1], c[2]) end
  if PetSkillScoutDB then PetSkillScoutDB.reportsSent = (PetSkillScoutDB.reportsSent or 0) + 1 end
end

-- Rare died / was tamed: "K~npc~id~ageSeconds~how". Age, not a timestamp, so
-- clients with different clocks agree.
function S:BroadcastKill(entry, rec)
  if not (Enabled() and entry and rec and rec.gone and Register()) then return end
  local npc = entry.beast and tonumber(entry.beast.npcID) or 0
  local age = math.max(0, (time and time() or rec.gone) - rec.gone)
  SendAll(table.concat({"K", tostring(npc), entry.id, tostring(math.floor(age)), rec.how or "kill"}, SEP))
end

-- Ammo vendor learned: "V~npc~map~x~y~kinds~name".
function S:BroadcastVendor(npc, rec)
  if not (Enabled() and npc and rec and rec.m and Register()) then return end
  local name = tostring(rec.n or "?"):gsub(SEP, ""):sub(1, 40)
  SendAll(table.concat({"V", tostring(npc), tostring(rec.m), string.format("%.1f", rec.x), string.format("%.1f", rec.y),
    rec.k or "", name}, SEP))
end

local function FindEntry(npc, id)
  local R = PSS.RarePets
  if not R then return nil end
  if not R.entries or #R.entries == 0 then R:Build() end
  if npc and R.byNpcID[npc] then return R.byNpcID[npc] end
  for _, e in ipairs(R.entries) do if e.id == id then return e end end
end
S.FindEntry = FindEntry

local function Coord(v)
  v = tonumber(v)
  if v and v >= 0 and v <= 100 then return v end
end
S.Coord = Coord

-- "Hunter saw it 5 min ago (34.5, 56.1)"
function S:Last(entry)
  local store = entry and PetSkillScoutDB and PetSkillScoutDB.rareShared
  return store and store[entry.id]
end

function S:Text(entry)
  local rec = self:Last(entry)
  if not (rec and rec.t and rec.who) then return nil end
  local age = math.max(0, (time and time() or rec.t) - rec.t)
  local text
  if age < 60 then
    text = string.format(PSS:L("syncSeenByNow"), rec.who)
  else
    local unit
    if age < 3600 then unit = string.format(PSS:L("unitMin"), math.floor(age / 60))
    elseif age < 86400 then unit = string.format(PSS:L("unitHour"), math.floor(age / 3600))
    else unit = string.format(PSS:L("unitDay"), math.floor(age / 86400)) end
    text = string.format(PSS:L("syncSeenBy"), rec.who, unit)
  end
  if rec.x and rec.y then text = text .. string.format(" (%.1f, %.1f)", rec.x, rec.y) end
  return text
end

local function Notify(entry, rec, dist)
  local mode = PetSkillScoutDB and PetSkillScoutDB.syncNotify or "wanted"
  if mode == "off" then return end
  -- The realm network is busy: only wanted rares are announced from it.
  if dist == "CHANNEL" then mode = "wanted" end
  local R = PSS.RarePets
  if R:IsCollected(entry) then return end
  local wanted = R:IsWanted(entry)
  if mode == "wanted" and not wanted then return end
  local now = Now()
  if lastNotified[entry.id] and now - lastNotified[entry.id] < 300 then return end
  lastNotified[entry.id] = now
  local where = entry.zone or "?"
  if rec.x and rec.y then where = where .. string.format(" %.1f, %.1f", rec.x, rec.y) end
  PSS:Print(string.format(PSS:L("syncSpotted"), rec.who, entry.name, where))
  if wanted and RaidNotice_AddMessage and RaidWarningFrame then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, PSS:Safe(PSS:L("rareWarning") .. entry.name .. " (" .. rec.who .. ")"),
      ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
  end
end

-- Senders above 30 messages a minute are ignored for that minute.
local rate = {}
local function Flooding(who)
  local now = Now()
  local r = rate[who]
  if not r or now - r.t > 60 then r = {t = now, n = 0}; rate[who] = r end
  r.n = r.n + 1
  return r.n > 30
end

-- Is this sender you? Your own messages come back from the guild and the
-- network channel, and the name there can be longer than UnitName("player")
-- ("First Last", "Name-Realm"). A message you sent a moment ago, coming back
-- under a name that starts with yours, is you - and that name is remembered.
local sentAt = {}
function S:NoteSent(msg) sentAt[msg] = Now() end
local function Squash(s) return (tostring(s or ""):gsub("[%s%-]", ""):lower()) end
function S:MyNames()
  local d = PetSkillScoutDB
  d.myNetNames = d.myNetNames or {}
  return d.myNetNames
end
function S:IsMe(who, msg)
  local me = UnitName and UnitName("player")
  if not me then return false end
  if who == me or self:MyNames()[who] then return true end
  local hit = false
  local full = GetUnitName and GetUnitName("player", true)
  if type(full) == "string" and Squash(full) == Squash(who) then hit = true end
  local t = msg and sentAt[msg]
  if t and Now() - t < 60 and Squash(who):sub(1, #Squash(me)) == Squash(me) then hit = true end
  if not hit then return false end
  self:MyNames()[who] = true
  -- Drop the "second you" saved by older versions.
  local peers = PetSkillScoutDB.peers
  if peers then peers[who] = nil; peers[(who:gsub("%s", ""))] = nil end
  return true
end


function S:Receive(msg, channel, sender)
  if not (PetSkillScoutDB and Enabled()) or type(msg) ~= "string" or #msg > 250 or type(sender) ~= "string" then return end
  local who = Ambiguate and Ambiguate(sender, "short") or sender
  who = who:match("^[^-]+") or who -- "Name-Realm" -> "Name"
  -- Forever names are "First Last": keep the space, drop anything odd.
  who = (who:gsub("[^%w\128-\255 ]", ""):gsub("^%s+", ""):gsub("%s+$", "")):sub(1, 32)
  if who == "" or S:IsMe(who, msg) then return end
  if Flooding(who) then return end
  local parts = {strsplit(SEP, msg)}
  -- No chat escape codes or control characters from other players.
  for i = 1, #parts do parts[i] = parts[i]:gsub("[|%c]", "") end
  local kind = parts[1]
  if PSS.Net and PSS.Net.Seen then PSS.Net:Seen(who, channel) end
  if channel == "WHISPER" and PSS.Net and PSS.Net.AddMember then PSS.Net:AddMember(who, sender); PSS.Net:Confirm(who) end
  if PSS.NetFeed then pcall(PSS.NetFeed.OnMessage, PSS.NetFeed, parts, who) end
  local handler = self.handlers[kind]
  if handler then
    pcall(handler, parts, who, channel, sender)
    return
  end
  local _, npc, id, map, x, y, extra = unpack(parts)
  if kind == "V" then
    -- V~npc~mapID~x~y~kinds~name: shifted into id, map, x, y, extra here.
    local vnpc, vmap, vx, vy = tonumber(npc), tonumber(id), Coord(map), Coord(x)
    if PSS.Ammo and vnpc and vmap and vx and vy then
      local kinds = tostring(y or ""):gsub("[^ab]", "")
      PSS.Ammo:Learn(vnpc, {n = tostring(extra or "?"):sub(1, 40), m = vmap, x = vx, y = vy,
        k = kinds ~= "" and kinds or nil}, who)
    end
    return
  end
  if kind == "K" then
    local entry = FindEntry(tonumber(npc), id)
    local age = tonumber(map)
    if entry and age and age >= 0 and age < 86400 and PSS.RareTimer then
      local how = (x == "tame" or x == "corpse") and x or "kill"
      PSS.RareTimer:MarkGone(entry, how, who, (time and time() or 0) - age, true)
    end
    return
  end
  if kind ~= "S" or not id then return end
  local entry = FindEntry(tonumber(npc), id)
  if not entry then return end
  if PSS.RareTimer then PSS.RareTimer:SeenAlive(entry) end
  local rec = {who = who, t = time and time() or 0, mapID = tonumber(map), x = Coord(x), y = Coord(y), ch = channel}
  PetSkillScoutDB.rareShared = PetSkillScoutDB.rareShared or {}
  PetSkillScoutDB.rareShared[entry.id] = rec
  if PSS.RareMap then PSS.RareMap:Refresh() end
  if PSS.UI and PSS.UI.view == "rares" and PSS.UI.UpdateRares then PSS.UI:UpdateRares() end
  Notify(entry, rec, channel)
end

S.frame = CreateFrame("Frame")
pcall(S.frame.RegisterEvent, S.frame, "CHAT_MSG_ADDON")
pcall(S.frame.RegisterEvent, S.frame, "CHAT_MSG_ADDON_LOGGED")
pcall(S.frame.RegisterEvent, S.frame, "CHAT_MSG_CHANNEL")
pcall(S.frame.RegisterEvent, S.frame, "PLAYER_LOGIN")
-- Diagnostics (/pss netdiag) ------------------------------------------------
-- Every incoming message of our prefix is counted by distribution (also our
-- own echoes), so the saved file shows whether the realm channel delivers.
local diag
local function CountRaw(channel)
  local d = PetSkillScoutDB
  if not d then return end
  d.netRaw = d.netRaw or {}
  local k = tostring(channel or "?")
  d.netRaw[k] = (d.netRaw[k] or 0) + 1
end
local function ResultName(r)
  if type(r) == "number" and Enum and type(Enum.SendAddonMessageResult) == "table" then
    for name, v in pairs(Enum.SendAddonMessageResult) do if v == r then return name .. " (" .. r .. ")" end end
  end
  return tostring(r)
end
function S:Diag()
  local P = function(t) PSS:Print("netdiag: " .. t) end
  local isReg = C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered
  P("prefix " .. PREFIX .. " registered=" .. tostring(Register()) ..
    (isReg and (" / client=" .. tostring(select(2, pcall(isReg, PREFIX)))) or ""))
  local id = PSS.Net and PSS.Net:ChannelIDRaw()
  P("channel " .. (PSS.Net and PSS.Net.CHANNEL or "?") .. " id=" .. tostring(id) ..
    " network on=" .. tostring(PSS.Net and PSS.Net.Enabled and PSS.Net.Enabled()))
  local fn = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
  if type(fn) ~= "function" then P("SendAddonMessage missing") return end
  local nonce = tostring(math.random(100000, 999999))
  diag = {nonce = nonce, t = Now(), got = {}}
  local dists = {}
  if id then dists[#dists + 1] = {"CHANNEL", id} end
  if IsInGuild and IsInGuild() then dists[#dists + 1] = {"GUILD"} end
  if IsInGroup and IsInGroup() then dists[#dists + 1] = {"PARTY"} end
  -- Whisper to yourself by the full name (Forever names are "First Last").
  local full = GetUnitName and GetUnitName("player", true) or (UnitName and UnitName("player"))
  dists[#dists + 1] = {"WHISPER", full}
  for _, d in ipairs(dists) do
    local ok, r = pcall(fn, PREFIX, "D" .. SEP .. nonce, d[1], d[2])
    P(string.format("send %s -> %s", d[1] .. (d[1] == "WHISPER" and (" " .. tostring(d[2])) or ""), ok and ResultName(r) or ("error " .. tostring(r))))
  end
  -- Logged variant of the addon message (some servers only relay that one).
  local logged = C_ChatInfo and C_ChatInfo.SendAddonMessageLogged
  if id and type(logged) == "function" then
    local ok, r = pcall(logged, PREFIX, "D" .. SEP .. nonce .. SEP .. "L", "CHANNEL", id)
    P("send CHANNEL logged -> " .. (ok and ResultName(r) or ("error " .. tostring(r))))
  end
  -- Plain chat text in the channel (hidden from chat by the addon's filter).
  local say = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if id and type(say) == "function" then
    local ok, r = pcall(say, "PSS" .. SEP .. "D" .. SEP .. nonce, "CHANNEL", nil, id)
    P("send CHANNEL text -> " .. (ok and ("called " .. tostring(r)) or ("error " .. tostring(r))))
  end
  local raw = {}
  for k, v in pairs(PetSkillScoutDB and PetSkillScoutDB.netRaw or {}) do raw[#raw + 1] = k .. "=" .. v end
  P("received so far by type: " .. (#raw > 0 and table.concat(raw, ", ") or "none"))
  local function report()
    local got = {}
    for k in pairs(diag.got) do got[#got + 1] = k end
    table.sort(got)
    P("echo back after 6 s: " .. (#got > 0 and table.concat(got, ", ") or "NONE") ..
      (id and not diag.got.CHANNEL and "  -> the realm channel does not deliver addon messages" or ""))
  end
  if C_Timer and C_Timer.After then C_Timer.After(6, report) end
end

S.frame:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender, ...)
  if event == "PLAYER_LOGIN" then Register() return end
  if event == "CHAT_MSG_CHANNEL" then
    -- Only the /pss netdiag text test (sent from the slash command).
    if diag and prefix == "PSS" .. SEP .. "D" .. SEP .. diag.nonce then diag.got["CHANNEL text"] = true end
    return
  end
  if prefix ~= PREFIX then return end
  pcall(CountRaw, channel)
  if type(msg) == "string" and msg:sub(1, 2) == "D" .. SEP then
    if diag and msg:sub(3, 2 + #diag.nonce) == diag.nonce then
      diag.got[tostring(channel) .. (msg:find(SEP .. "L$") and " logged" or "")] = true
    end
    return
  end
  S:Receive(msg, channel, sender)
end)
S.frame:SetScript("OnUpdate", function()
  if #queue == 0 then return end
  Refill()
  while tokens >= 1 and #queue > 0 do
    local m = table.remove(queue, 1)
    tokens = tokens - 1
    RawSend(m[1], m[2], m[3])
  end
end)
Register()
S.frame.pssKey = "Sync queue"
PSS:Every(S.frame, 0.2)
