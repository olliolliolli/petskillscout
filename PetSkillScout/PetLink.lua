-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Pet cards in chat. "Share" puts "[PetSkillScout: Wolfie] Wolf 60, Bite 8..."
-- into your chat input; you send it yourself like any message. Other players
-- with PetSkillScout see the bracket as a link: clicking it asks your client for
-- the card (hidden whisper) and opens it with the 3D model. Players without the
-- addon simply read the text.
--   R~petName                  card request (whisper)
--   C~name~family~level~npc~display~skills~days~zone~tamed~loyalty~looks~rares~score
local PSS = PetSkillScout
PSS.PetLink = {}
local P = PSS.PetLink
local TAG = "PetSkillScout"
local SEP = "~"

local function L(key) return PSS:L(key) end
local function Clean(v, n) return (tostring(v or ""):gsub("[~|%[%]:]", "")):sub(1, n or 40) end
local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end

-- Card of the active pet: { name, family, level, npc, display, skills, days, zone, tamed, loyalty, ... }
function P:OwnCard()
  local pet = PSS.MyPet
  if not pet then return nil end
  if not pet.active then safe(pet.Scan, pet) end
  if not pet.active then return nil end
  local log = PSS.Collection and PSS.Collection:ActiveLog()
  local skills = {}
  for _, s in ipairs(pet.spells or {}) do
    if s.key and PSS.Abilities[s.key] then table.insert(skills, {key = s.key, rank = s.rank}) end
  end
  local guid = UnitGUID and PSS.Plain(UnitGUID("pet"))
  local npc = pet.npcID
  if not npc and type(guid) == "string" then
    local _, _, _, _, _, id = strsplit("-", guid)
    npc = tonumber(id)
  end
  local loyalty = C_PetInfo and safe(C_PetInfo.GetPetLoyalty)
  local score, looks, rares = 0, 0, 0
  if PSS.Achieve then score, looks, rares = PSS.Achieve:Stats() end
  return {
    name = pet.name, family = pet.family, level = pet.level, npc = npc,
    display = pet.displayID or (npc and PSS.DisplayIDs and PSS.DisplayIDs[npc]),
    skills = skills, days = PSS.Collection and PSS.Collection:DaysTogether(log),
    zone = log and log.zone, tamed = log and log.tamed, first = log and log.first,
    loyalty = type(loyalty) == "string" and loyalty or nil,
    looks = looks, rares = rares, score = score,
    hunter = UnitName and UnitName("player"), own = true,
  }
end

local function SkillsText(skills, sep)
  local parts = {}
  for _, s in ipairs(skills or {}) do
    table.insert(parts, PSS:NameAbility(s.key) .. (s.rank and (" " .. s.rank) or ""))
  end
  return table.concat(parts, sep or ", ")
end

function P:Encode(card)
  local skills = {}
  for _, s in ipairs(card.skills or {}) do table.insert(skills, s.key .. ":" .. tostring(s.rank or 0)) end
  local msg = table.concat({"C", Clean(card.name, 24), Clean(card.family, 20), tostring(card.level or 0),
    tostring(card.npc or 0), tostring(card.display or 0), table.concat(skills, ","):sub(1, 120),
    tostring(card.days or ""), Clean(card.zone, 30), card.tamed and "1" or "0", Clean(card.loyalty, 24),
    tostring(card.looks or 0), tostring(card.rares or 0), tostring(card.score or 0)}, SEP)
  return msg
end

function P:Decode(parts, who)
  local skills = {}
  for key, rank in tostring(parts[7] or ""):gmatch("([^:,]+):(%d+)") do
    if PSS.Abilities[key] then table.insert(skills, {key = key, rank = tonumber(rank)}) end
  end
  local function num(v) v = tonumber(v); if v and v > 0 then return v end end
  return {
    name = parts[2], family = PSS:CanonicalFamily(parts[3]), level = num(parts[4]),
    npc = num(parts[5]), display = num(parts[6]), skills = skills, days = tonumber(parts[8]),
    zone = parts[9] ~= "" and parts[9] or nil, tamed = parts[10] == "1",
    loyalty = parts[11] ~= "" and parts[11] or nil,
    looks = tonumber(parts[12]) or 0, rares = tonumber(parts[13]) or 0, score = tonumber(parts[14]) or 0,
    hunter = who,
  }
end

-- Share ---------------------------------------------------------------------------
function P:ShareText(card)
  card = card or self:OwnCard()
  if not card then return nil end
  local text = string.format("[%s: %s] %s %s", TAG, card.name or "?", PSS:NameFamily(card.family) or "?", tostring(card.level or "?"))
  local skills = SkillsText(card.skills)
  if skills ~= "" then text = text .. ", " .. skills end
  return PSS:Safe(text):sub(1, 250)
end

function P:Share()
  local text = self:ShareText()
  if not text then PSS:Print(L("petNone")) return end
  local box = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
  if box and box.Insert then box:Insert(text)
  elseif ChatFrame_OpenChat then ChatFrame_OpenChat(text)
  else PSS:Print(text) end
  if PetSkillScoutDB then PetSkillScoutDB.cardsShared = (PetSkillScoutDB.cardsShared or 0) + 1 end
  if PSS.Achieve then pcall(PSS.Achieve.Check, PSS.Achieve) end
end

-- Chat filter: [PetSkillScout: Name] becomes a link for addon users ---------------
local useAddonLink = EventRegistry ~= nil and EventRegistry.RegisterCallback ~= nil
local function LinkFor(author, pet)
  author, pet = Clean(author, 48), Clean(pet, 24)
  local data = useAddonLink and ("addon:" .. TAG .. ":card:") or "garrmission:pss:card:"
  return "|cff71d5ff|H" .. data .. author .. ":" .. pet .. "|h[" .. TAG .. ": " .. pet .. "]|h|r"
end

local PATTERN = "%[" .. TAG .. ": ([^%]]+)%]"
local function Convert(msg, author)
  -- Chat text can be a protected (secret) value on this client: never touch it then.
  if type(msg) ~= "string" or (PSS.IsSecret and (PSS.IsSecret(msg) or PSS.IsSecret(author))) then return nil end
  if not msg:find("[" .. TAG .. ":", 1, true) or msg:find("|H", 1, true) then return nil end
  return (msg:gsub(PATTERN, function(pet) return LinkFor(author, pet) end))
end
function P.Filter(_, _, msg, author, ...)
  local ok, new = pcall(Convert, msg, author)
  if not (ok and new) then return false end
  return false, new, author, ...
end

local EVENTS = {"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
  "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL",
  "CHAT_MSG_EMOTE"}
if ChatFrame_AddMessageEventFilter then
  for _, e in ipairs(EVENTS) do pcall(ChatFrame_AddMessageEventFilter, e, P.Filter) end
end

-- Clicks ---------------------------------------------------------------------------
local pending = {}
local lastLink, lastLinkAt = nil, -1
function P:HandleLink(link)
  if type(link) ~= "string" then return end
  local t, a, kind, author, pet = strsplit(":", link)
  if not (((t == "addon" and a == TAG) or (t == "garrmission" and a == "pss")) and kind == "card") then return end
  local now = GetTime and GetTime() or 0
  if link == lastLink and now - lastLinkAt < 0.5 then return end
  lastLink, lastLinkAt = link, now
  local me = UnitName and UnitName("player")
  local short = Ambiguate and Ambiguate(author or "", "short") or author
  if short == me then
    local card = self:OwnCard()
    if card and PSS.UI and PSS.UI.ShowCard then PSS.UI:ShowCard(card) end
    return
  end
  self:Request(author, pet, pet)
end

-- Ask a player for a card. key: pet name, or "#<look id>" for the showcase.
function P:Request(target, key, title)
  local short = Ambiguate and Ambiguate(target or "", "short") or target
  local who = (short or ""):gsub("[^%w\128-\255]", "")
  pending[who] = {t = GetTime and GetTime() or 0, pet = title or key}
  if PSS.Sync then PSS.Sync:Send("R" .. SEP .. Clean(key, 24), "WHISPER", target) end
  if PSS.UI and PSS.UI.ShowCard then PSS.UI:ShowCard({name = title or key, hunter = short, loading = true}) end
end

if EventRegistry and EventRegistry.RegisterCallback then
  pcall(EventRegistry.RegisterCallback, EventRegistry, "SetItemRef", function(_, link) P:HandleLink(link) end, P)
end
if hooksecurefunc then pcall(PSS.HookSecure, "SetItemRef", function(link) P:HandleLink(link) end) end

-- Whisper protocol ---------------------------------------------------------------
local lastReply = {}
local function OnRequest(parts, who, dist, sender)
  if dist ~= "WHISPER" then return end
  local now = GetTime and GetTime() or 0
  if lastReply[who] and now - lastReply[who] < 5 then return end
  lastReply[who] = now
  local key = parts[2] or ""
  local card
  if key:sub(1, 1) == "#" then
    card = PSS.Showcase and PSS.Showcase:CardForLook(tonumber(key:sub(2)))
  else
    card = P:OwnCard()
  end
  if not card then return end
  PSS.Sync:Send(P:Encode(card), "WHISPER", sender)
end

local function OnCard(parts, who, dist)
  if dist ~= "WHISPER" then return end
  local req = pending[who]
  if not req then return end
  pending[who] = nil
  local card = P:Decode(parts, who)
  if PSS.UI and PSS.UI.ShowCard then PSS.UI:ShowCard(card) end
end

-- No answer in time: say so on the card.
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
  local now = GetTime and GetTime() or 0
  for who, req in pairs(pending) do
    if now - req.t > 5 then
      pending[who] = nil
      if PSS.UI and PSS.UI.ShowCard then PSS.UI:ShowCard({name = req.pet, hunter = who, failed = true}) end
    end
  end
end)

if PSS.Sync then
  PSS.Sync.handlers.R = OnRequest
  PSS.Sync.handlers.C = OnCard
end
P.SkillsText = SkillsText
watch.pssKey = "PetLink"
PSS:Every(watch, 1)
