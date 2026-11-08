-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Gear advisor for hunters (WoW Forever): best items per slot for a spec,
-- upgrades for the current level, where to get them and the gain over what
-- is equipped now.
-- Candidates and sources: PSS.GearData (wow-classic-items, MIT, see GearData.lua).
-- Stats: the real WoW Forever stats are read from the item in game
-- (GetItemStats); the Classic numbers are only a fallback until the item is
-- cached, and for equip effects the client does not report.
-- Stat weights are estimates (no official Forever numbers exist yet).
local PSS = PetSkillScout
PSS.Gear = {}
local G = PSS.Gear

local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Pack(...) return {n = select("#", ...), ...} end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = Pack(pcall(fn, ...))
  if not r[1] then return nil end
  return unpack(r, 2, r.n)
end
local function L(k) return PSS:L(k) end

-- Specs and weights (attack-power equivalents) -----------------------------
G.SPECS = {"BM", "MM", "SV"}
G.WEIGHTS = {
  MM = {agi = 2.4, ap = 1.0, rap = 1.0, map = 0.1, crit = 28, hit = 22, int = 0.25, sta = 0.2, str = 0.1, armor = 0.01, mp5 = 1.5},
  BM = {agi = 2.2, ap = 1.05, rap = 1.0, map = 0.1, crit = 24, hit = 22, int = 0.4, sta = 0.3, str = 0.1, armor = 0.01, mp5 = 2.0},
  SV = {agi = 2.7, ap = 1.0, rap = 1.0, map = 0.25, crit = 26, hit = 22, int = 0.25, sta = 0.3, str = 0.15, armor = 0.01, mp5 = 1.5},
}
-- Hunters fight at range: melee weapon damage counts for little.
G.RANGED_DPS, G.MELEE_DPS = 14, {MM = 1.2, BM = 1.2, SV = 2.0}

-- Slots shown in the tab, with the inventory slot of each.
G.SLOTS = {
  {key = "head", inv = 1, kinds = {"head"}},
  {key = "neck", inv = 2, kinds = {"neck"}},
  {key = "shoulder", inv = 3, kinds = {"shoulder"}},
  {key = "back", inv = 15, kinds = {"back"}},
  {key = "chest", inv = 5, kinds = {"chest"}},
  {key = "wrist", inv = 9, kinds = {"wrist"}},
  {key = "hands", inv = 10, kinds = {"hands"}},
  {key = "waist", inv = 6, kinds = {"waist"}},
  {key = "legs", inv = 7, kinds = {"legs"}},
  {key = "feet", inv = 8, kinds = {"feet"}},
  {key = "finger1", inv = 11, kinds = {"finger"}, pair = "finger2"},
  {key = "finger2", inv = 12, kinds = {"finger"}, pair = "finger1"},
  {key = "trinket1", inv = 13, kinds = {"trinket"}, pair = "trinket2"},
  {key = "trinket2", inv = 14, kinds = {"trinket"}, pair = "trinket1"},
  {key = "mainhand", inv = 16, kinds = {"twohand", "mainhand", "onehand"}},
  {key = "offhand", inv = 17, kinds = {"onehand", "offhand"}},
  {key = "ranged", inv = 18, kinds = {"ranged"}},
}
G.DUAL_WIELD_LEVEL = 20

-- Data index ---------------------------------------------------------------
local byId, bySlot
local function Index()
  if byId then return end
  byId, bySlot = {}, {}
  for _, list in ipairs({PSS.GearData or {}, PSS.CraftData or {}}) do
    for _, rec in ipairs(list) do
      if not byId[rec.id] then
        byId[rec.id] = rec
        bySlot[rec.slot] = bySlot[rec.slot] or {}
        table.insert(bySlot[rec.slot], rec)
      end
    end
  end
end
function G:Get(id) Index(); return byId[id] end

-- Settings -----------------------------------------------------------------
local function DB() return PetSkillScoutDB or {} end
function G:Spec()
  local s = DB().gearSpec
  if s == "BM" or s == "MM" or s == "SV" then return s end
  return "MM"
end
function G:SetSpec(s) if PetSkillScoutDB then PetSkillScoutDB.gearSpec = s end end
function G:IncludeRaids() return DB().gearRaids == true end
function G:IncludePvp() return DB().gearPvp == true end
function G:IncludeRare() return DB().gearRare == true end

-- Realistic sources: a quest, a vendor or a drop with at least 2% chance.
-- Rare world drops (BoE, auction house) only with the option on.
G.MIN_CHANCE = 2

function G:PlayerLevel()
  return Plain(Call(UnitLevel, "player")) or (PSS.player and PSS.player.level) or 1
end

-- Level cap of the realm (the beta runs at 30); the data covers 1-60.
function G:MaxLevel()
  local v = tonumber(DB().gearCap)
  if v and v >= 10 and v <= 60 then return v end
  local m = Plain(Call(GetMaxPlayerLevel)) or MAX_PLAYER_LEVEL or 60
  if type(m) ~= "number" or m < 10 then m = 60 end
  return math.min(m, 60)
end

local function Faction()
  local f = PSS.player and PSS.player.faction
  if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
end

-- Stats --------------------------------------------------------------------
-- Real Forever stats of an item, from the client (nil until cached).
local STAT_KEYS = {
  {"RANGED_ATTACK_POWER", "rap"}, {"ATTACK_POWER", "ap"}, {"AGILITY", "agi"}, {"STAMINA", "sta"},
  {"INTELLECT", "int"}, {"SPIRIT", "spi"}, {"STRENGTH", "str"}, {"DAMAGE_PER_SECOND", "dps"},
  {"RESISTANCE0", "armor"}, {"MANA_REGENERATION", "mp5"}, {"POWER_REGEN0", "mp5"},
}
local function RuntimeStats(link)
  if type(link) ~= "string" then return nil end
  local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
  local t = Call(fn, link)
  if type(t) ~= "table" or next(t) == nil then return nil end
  local st = {}
  for k, v in pairs(t) do
    v = Plain(v)
    if type(k) == "string" and type(v) == "number" and not k:find("SPELL") then
      if k:find("CRIT") then
        st.crit = (st.crit or 0) + (v > 5 and v / 14 or v)
      elseif k:find("HIT") then
        st.hit = (st.hit or 0) + (v > 5 and v / 14 or v)
      else
        for _, m in ipairs(STAT_KEYS) do
          if k:find(m[1]) then st[m[2]] = (st[m[2]] or 0) + v; break end
        end
      end
    end
  end
  return next(st) and st or nil
end
G.RuntimeStats = RuntimeStats

local function ItemLink(id)
  local name, link = Call(C_Item and C_Item.GetItemInfo or GetItemInfo, id)
  return Plain(link), Plain(name)
end

local requested = {}
function G:Request(id)
  if not id or requested[id] then return end
  requested[id] = true
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id)
  else Call(GetItemInfo, id) end
end

-- Forever stats when the item is cached; Classic equip effects the client
-- does not list (crit / hit / attack power from "Equip:" lines) are added.
function G:Stats(id, link)
  local rec = byId and byId[id] or self:Get(id)
  -- A plain "item:<id>" link works for cached items too.
  link = link or ItemLink(id) or ("item:" .. id)
  local st = RuntimeStats(link)
  if st then
    if rec then
      for _, k in ipairs({"crit", "hit", "ap", "rap", "map", "mp5"}) do
        if st[k] == nil and rec.st[k] then st[k] = rec.st[k] end
      end
    end
    st.live = true
    return st
  end
  if rec then return rec.st end
  self:Request(id)
  return nil
end

function G:Score(st, slot, spec)
  if not st then return 0 end
  local w = self.WEIGHTS[spec or self:Spec()]
  local s = 0
  for k, v in pairs(st) do
    if w[k] then s = s + w[k] * v end
  end
  if st.dps then
    if slot == "ranged" then s = s + st.dps * self.RANGED_DPS
    else s = s + st.dps * self.MELEE_DPS[spec or self:Spec()] end
  end
  return s
end

function G:ItemScore(id, spec, link)
  local rec = self:Get(id)
  return self:Score(self:Stats(id, link), rec and rec.slot or "other", spec)
end

-- Equipped item of an inventory slot: id, link, score.
function G:Equipped(inv, spec)
  local link = Plain(Call(GetInventoryItemLink, "player", inv))
  if type(link) ~= "string" then return nil, nil, 0, nil end
  local id = tonumber(link:match("item:(%d+)"))
  local slotKey = inv == 18 and "ranged" or "other"
  local st = RuntimeStats(link) or (id and self:Get(id) and self:Get(id).st)
  if id and self:Get(id) then st = self:Stats(id, link) end
  return id, link, self:Score(st, slotKey, spec), st
end

-- Availability ----------------------------------------------------------------
-- Sources this character can use: quests of the other faction are dropped,
-- raid-only / PvP items only with the options on.
function G:Sources(rec)
  local fac = Faction()
  local out = {}
  for _, s in ipairs(rec.src or {}) do
    if s.t == "c" then
      -- Crafted: only for your own professions (also when the skill is still too low).
      if self:ProfSkill(s.p) then table.insert(out, s) end
    elseif not (s.t == "q" and s.f and fac and s.f ~= fac) then
      table.insert(out, s)
    end
  end
  return out
end

-- Professions -------------------------------------------------------------------
-- Learned professions and skill, by English name (skill line IDs are the same
-- in every language). Cached for 10 s.
G.PROF_LINES = {[165] = "Leatherworking", [164] = "Blacksmithing", [197] = "Tailoring",
  [202] = "Engineering", [171] = "Alchemy", [333] = "Enchanting"}
local PROF_EN = {}
for _, n in pairs(G.PROF_LINES) do PROF_EN[n] = true end
local profCache, profAt = nil, -1e9
function G:Professions()
  local now = GetTime and GetTime() or 0
  if profCache and now - profAt < 10 then return profCache end
  local out = {}
  if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
    local list = {Call(GetProfessions)}
    for i = 1, 2 do
      local idx = Plain(list[i])
      if idx then
        local _, _, rank, maxRank, _, _, line = Call(GetProfessionInfo, idx)
        local name = self.PROF_LINES[tonumber(Plain(line)) or 0]
        if name then out[name] = {rank = tonumber(Plain(rank)) or 0, max = tonumber(Plain(maxRank)) or 0} end
      end
    end
  end
  if not next(out) and type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
    -- Older clients: the skill list (English names only; other languages
    -- fall back to the localised names below).
    local n = tonumber(Plain(Call(GetNumSkillLines))) or 0
    for i = 1, n do
      local name, header, _, rank, _, _, maxRank = Call(GetSkillLineInfo, i)
      name = Plain(name)
      if name and not Plain(header) then
        local en = PROF_EN[name] and name
        if not en then
          for line, eng in pairs(self.PROF_LINES) do
            local loc = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName and Call(C_TradeSkillUI.GetTradeSkillDisplayName, line)
            if Plain(loc) == name then en = eng end
          end
        end
        if en then out[en] = {rank = tonumber(Plain(rank)) or 0, max = tonumber(Plain(maxRank)) or 0} end
      end
    end
  end
  -- Anything missing: the quest module merges the skill list and spell book.
  if PSS.QuestWorth and PSS.QuestWorth.Skills then
    for line, rank in pairs(PSS.QuestWorth:Skills()) do
      local name = type(line) == "number" and self.PROF_LINES[line]
      if name and not out[name] then out[name] = {rank = rank, max = 0} end
    end
  end
  profCache, profAt = out, now
  return out
end
function G:ProfSkill(name)
  local p = self:Professions()[name]
  return p and p.rank
end
function G:ProfName(en)
  local k = "prof" .. tostring(en)
  local t = L(k)
  return t ~= k and t or tostring(en)
end

function G:Practical(rec)
  for _, s in ipairs(self:Sources(rec)) do
    if s.t == "q" or s.t == "v" or s.t == "c" then return true end
    if s.t == "d" and (s.c or 0) >= self.MIN_CHANCE then return true end
  end
  return false
end

-- relaxed: also rare drops (used when the slot is empty and nothing practical exists).
function G:Allowed(rec, maxLevel, relaxed)
  if rec.lvl > maxLevel then return false end
  local fac = Faction()
  if rec.fac and fac and rec.fac ~= fac then return false end
  if rec.raid and not self:IncludeRaids() then return false end
  if rec.pvp and not self:IncludePvp() then return false end
  if #self:Sources(rec) == 0 then return false end
  return relaxed or self:IncludeRare() or self:Practical(rec)
end

-- Ranked candidates for a slot key at a level.
function G:Candidates(slotDef, spec, maxLevel, limit, relaxed)
  Index()
  local list = {}
  for _, kind in ipairs(slotDef.kinds) do
    for _, rec in ipairs(bySlot[kind] or {}) do
      if self:Allowed(rec, maxLevel, relaxed) then
        list[#list + 1] = {rec = rec, score = self:Score(self:Stats(rec.id), rec.slot, spec)}
      end
    end
  end
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.rec.id < b.rec.id
  end)
  if limit then for i = #list, limit + 1, -1 do list[i] = nil end end
  return list
end

-- Plan for every slot ---------------------------------------------------------
-- mode "now": best items you can wear at your level, compared with what is
-- equipped; mode "max": the best items at the level cap.
-- Each entry: {slot, pick = {rec, score}, alts = {...}, equipped = {id, link,
-- score}, gain (percent, nil when nothing equipped), better (bool)}.
function G:Plan(mode, spec)
  spec = spec or self:Spec()
  local level = mode == "max" and self:MaxLevel() or self:PlayerLevel()
  local plan, used = {}, {}
  local bySlotKey = {}
  for _, def in ipairs(self.SLOTS) do
    local eqId, eqLink, eqScore, eqStats = self:Equipped(def.inv, spec)
    local cands = self:Candidates(def, spec, level, 12)
    local e = {slot = def, equipped = {id = eqId, link = eqLink, score = eqScore, st = eqStats}, alts = {}}
    -- Pairs (rings, trinkets): the second slot skips the first slot's pick;
    -- unique items are taken once.
    for _, c in ipairs(cands) do
      if not used[c.rec.id] then
        if not e.pick then e.pick = c else table.insert(e.alts, c) end
      end
    end
    -- Empty slot and nothing practical: anything is better than nothing, so
    -- rare drops are offered too.
    if not e.pick and not eqId then
      for _, c in ipairs(self:Candidates(def, spec, level, 12, true)) do
        if not used[c.rec.id] then
          if not e.pick then e.pick = c; e.relaxed = true else table.insert(e.alts, c) end
        end
      end
    end
    -- Still nothing at your level: the nearest item that comes later
    -- (lowest required level, best score among those), shown as "from level N".
    if not e.pick and not eqId and mode ~= "max" then
      local best
      for _, c in ipairs(self:Candidates(def, spec, self:MaxLevel(), nil, true)) do
        if not used[c.rec.id] and (not best or c.rec.lvl < best.rec.lvl
           or (c.rec.lvl == best.rec.lvl and c.score > best.score)) then best = c end
      end
      e.upcoming = best
    end
    if e.pick and def.pair then used[e.pick.rec.id] = true end
    bySlotKey[def.key] = e
    table.insert(plan, e)
  end
  -- Weapons: a two-hander against main hand + off hand (dual wield from 20).
  local mh, oh = bySlotKey.mainhand, bySlotKey.offhand
  if mh and oh then
    local canDual = level >= self.DUAL_WIELD_LEVEL
    local best2h, best1h
    for _, c in ipairs(self:Candidates(mh.slot, spec, level, 12)) do
      if c.rec.slot == "twohand" then best2h = best2h or c else best1h = best1h or c end
    end
    local ohBest
    for _, c in ipairs(oh.pick and {oh.pick} or {}) do ohBest = c end
    if best1h and ohBest and ohBest.rec.id == best1h.rec.id then
      -- the same one-hander cannot be in both hands unless there are two; use the next
      ohBest = oh.alts[1]
    end
    local dual = (best1h and best1h.score or 0) + (canDual and ohBest and ohBest.score or 0)
    if best2h and best2h.score >= dual then
      mh.pick, oh.pick, oh.twoHand = best2h, nil, true
    else
      mh.pick = best1h or mh.pick
      oh.pick = canDual and ohBest or nil
    end
    if not canDual then oh.locked = self.DUAL_WIELD_LEVEL end
  end
  for _, e in ipairs(plan) do
    local eq = e.equipped.score or 0
    if e.pick then
      if e.equipped.id == e.pick.rec.id then
        e.wearing = true
      elseif eq > 0 then
        e.gain = (e.pick.score - eq) / eq * 100
      end
      e.better = (e.pick.score > eq + 0.5 or not e.equipped.id) and not e.wearing
    end
  end
  return plan, level
end

-- Stat changes against the equipped item, most important first:
-- "+5 agi · +2 sta · -3 int" (at most 4 entries).
local DIFF_ORDER = {"dps", "agi", "ap", "rap", "crit", "hit", "sta", "int", "str", "spi", "mp5", "armor"}
function G:Diff(new, old, slot)
  new, old = new or {}, old or {}
  local parts = {}
  for _, k in ipairs(DIFF_ORDER) do
    local d = (new[k] or 0) - (old[k] or 0)
    local pct = k == "crit" or k == "hit"
    local min = pct and 0.05 or (k == "dps" and 0.1 or 0.5)
    if math.abs(d) >= min and not (k == "dps" and slot ~= "ranged" and #parts >= 2) then
      local label = L("stat_" .. k)
      if pct then
        table.insert(parts, string.format("%+.1f%% %s", d, label))
      elseif k == "dps" then
        table.insert(parts, string.format("%+.1f %s", d, label))
      else
        table.insert(parts, string.format("%+d %s", math.floor(d + (d > 0 and 0.5 or -0.5)), label))
      end
      if #parts >= 4 then break end
    end
  end
  return table.concat(parts, "  ·  ")
end

-- Structured stat changes: {{text, up}, ...}, most important first.
function G:DiffParts(new, old, slot, max)
  new, old = new or {}, old or {}
  local parts = {}
  for _, k in ipairs(DIFF_ORDER) do
    local d = (new[k] or 0) - (old[k] or 0)
    local pct = k == "crit" or k == "hit"
    local min = pct and 0.05 or (k == "dps" and 0.1 or 0.5)
    if math.abs(d) >= min and not (k == "armor" and #parts >= 2) then
      local label, text = L("stat_" .. k)
      if pct then text = string.format("%+.1f%% %s", d, label)
      elseif k == "dps" then text = string.format("%+.1f %s", d, label)
      else text = string.format("%+d %s", math.floor(d + (d > 0 and 0.5 or -0.5)), label) end
      table.insert(parts, {text = text, up = d > 0})
      if #parts >= (max or 3) then break end
    end
  end
  return parts
end

-- The main source as two short lines: who / what, and kind · place · chance.
-- Quest behind the first quest source of an item: QuestDB entry matched by the
-- quest name (gear data has no quest IDs). Prefers your faction and a quest
-- with a known quest giver position.
local questByName
-- Name of the first quest source of an item (nil when it is not a quest reward).
function G:QuestSourceName(rec)
  for _, x in ipairs(self:Sources(rec)) do if x.t == "q" then return x.n end end
end
function G:QuestFor(rec)
  local s
  for _, x in ipairs(self:Sources(rec)) do if x.t == "q" then s = x; break end end
  if not (s and s.n and PSS.QuestDB) then return nil end
  if not questByName then
    questByName = {}
    for id, r in pairs(PSS.QuestDB) do
      if r.n then
        -- Chains are stored as "Name (2/7)": index them under the plain name.
        local k = r.n:gsub("%s*%(%d+/%d+%)$", ""):lower()
        questByName[k] = questByName[k] or {}
        table.insert(questByName[k], id)
      end
    end
    for _, ids in pairs(questByName) do table.sort(ids) end
  end
  local fac = Faction()
  local best, bestScore
  for _, id in ipairs(questByName[s.n:lower()] or {}) do
    local r = PSS.QuestDB[id]
    local score = 0
    if r.s and fac and r.s ~= fac then score = score - 10 end
    if r.m and r.x then score = score + 2 end
    -- A chain starts at its first step: that is where you go.
    local step, total = (r.n or ""):match("%((%d+)/(%d+)%)$")
    if step == "1" then score = score + 1 end
    if not bestScore or score > bestScore then best, bestScore = id, score end
  end
  if not best or bestScore < 0 or not (PSS.QuestDB[best].m and PSS.QuestDB[best].x) then
    -- Not in the database (or no giver position there): quests learned in game.
    local L = PSS.QuestLearn
    local lid, lr
    if L then lid, lr = L:ByTitle(s.n) end
    if lid and lr.m and lr.x then return lid, lr end
    if not best or bestScore < 0 then return nil end
  end
  local r = PSS.QuestDB[best]
  local _, total = (r.n or ""):match("%((%d+)/(%d+)%)$")
  return best, r, tonumber(total)
end

function G:SourceShort(rec)
  local s = self:Sources(rec)[1]
  if not s then return nil end
  local more = #self:Sources(rec) - 1
  local tail = more > 0 and ("  ·  " .. string.format(L("gearMore"), more)) or ""
  local rep = ""
  if rec.rep then
    local rank = rec.rr and L("gearRepRank" .. rec.rr) or ""
    rep = "  ·  " .. (self.REP_NAMES[rec.rep] or "") .. (rank ~= "" and (" (" .. rank .. ")") or "")
  end
  if s.t == "d" then
    local who = s.n .. ((s.r == 2 or s.r == 4) and (" (" .. L("gearRare") .. ")") or "")
    local where = s.i or s.z or (s.l and string.format(L("gearLevelN"), s.l)) or ""
    return who, L("gearKindDrop") .. (where ~= "" and ("  ·  " .. where) or "") .. "  ·  " .. self:Chance(s.c) .. tail
  elseif s.t == "w" then
    return L("gearKindWorld"), self:Chance(s.c) .. tail
  elseif s.t == "z" then
    return s.z or "?", L("gearKindZone") .. tail
  elseif s.t == "q" then
    local where = s.z and ("  ·  " .. s.z) or ""
    return s.n, L("gearKindQuest") .. where .. rep .. tail
  elseif s.t == "v" then
    return s.n, L("gearKindVendor") .. (s.i and ("  ·  " .. s.i) or "") .. rep .. tail
  elseif s.t == "c" then
    local have = self:ProfSkill(s.p) or 0
    local need = tonumber(s.s) or 1
    local state = have >= need and ("|cff70d070" .. L("gearCraftReady") .. "|r")
      or ("|cffff7a5a" .. string.format(L("gearCraftNeed"), have) .. "|r")
    return self:ProfName(s.p) .. " " .. need, L("gearKindCraft") .. "  ·  " .. state .. tail
  end
end

-- Text helpers ------------------------------------------------------------------
function G:Chance(c)
  c = tonumber(c) or 0
  if c >= 10 then return string.format("%d%%", math.floor(c + 0.5)) end
  if c >= 1 then return string.format("%.1f%%", c) end
  if c >= 0.01 then return string.format("%.2f%%", c) end
  return "<0.01%"
end

-- Reputation factions of the items in the data.
G.REP_NAMES = {[509] = "League of Arathor", [510] = "The Defilers", [729] = "Frostwolf Clan", [730] = "Stormpike Guard",
  [889] = "Warsong Outriders", [890] = "Silverwing Sentinels", [910] = "Brood of Nozdormu", [529] = "Argent Dawn",
  [576] = "Timbermaw Hold", [609] = "Cenarion Circle", [59] = "Thorium Brotherhood", [270] = "Zandalar Tribe",
  [749] = "Hydraxian Waterlords", [87] = "Bloodsail Buccaneers", [21] = "Booty Bay", [369] = "Gadgetzan",
  [470] = "Ratchet", [577] = "Everlook", [809] = "Shen'dralar", [68] = "Undercity", [72] = "Stormwind",
  [47] = "Ironforge", [69] = "Darnassus", [76] = "Orgrimmar", [81] = "Thunder Bluff", [530] = "Darkspear Trolls",
  [54] = "Gnomeregan Exiles", [911] = "Silvermoon City", [930] = "Exodar"}

-- One line per source, most useful first.
function G:SourceLines(rec)
  local lines = {}
  if rec.rep then
    local rank = rec.rr and L("gearRepRank" .. rec.rr)
    table.insert(lines, string.format(L("gearRep"), self.REP_NAMES[rec.rep] or ("#" .. rec.rep),
      rank and rank ~= ("gearRepRank" .. rec.rr) and rank or ""))
  end
  for _, s in ipairs(self:Sources(rec)) do
    if s.t == "d" then
      local where = s.i or s.z or (s.l and string.format(L("gearLevelN"), s.l)) or "?"
      local who = s.n .. ((s.r == 2 or s.r == 4) and (" (" .. L("gearRare") .. ")") or "")
      table.insert(lines, string.format(L("gearSrcDrop"), who, where, self:Chance(s.c)))
    elseif s.t == "w" then
      if s.l1 then
        table.insert(lines, string.format(L("gearSrcWorld"), s.l1, s.l2 or s.l1, self:Chance(s.c)))
      else
        table.insert(lines, string.format(L("gearSrcRareWorld"), self:Chance(s.c)))
      end
    elseif s.t == "z" then
      table.insert(lines, string.format(L("gearSrcZone"), s.z or "?"))
    elseif s.t == "q" then
      if s.l then
        table.insert(lines, string.format(L("gearSrcQuest"), s.n, s.l, s.z and (", " .. s.z) or ""))
      else
        table.insert(lines, string.format(L("gearSrcQuestShort"), s.n))
      end
    elseif s.t == "v" then
      table.insert(lines, string.format(L("gearSrcVendor"), s.n .. (s.i and (" (" .. s.i .. ")") or "")))
    elseif s.t == "c" then
      local have = self:ProfSkill(s.p) or 0
      table.insert(lines, string.format(L("gearSrcCraft"), self:ProfName(s.p), tonumber(s.s) or 1, have))
      local parts = {}
      for _, r in ipairs(s.r or {}) do
        local name = C_Item and C_Item.GetItemNameByID and Call(C_Item.GetItemNameByID, r[1])
        if not Plain(name) and C_Item and C_Item.RequestLoadItemDataByID then Call(C_Item.RequestLoadItemDataByID, r[1]) end
        parts[#parts + 1] = (r[2] or 1) .. "x " .. (Plain(name) or ("#" .. r[1]))
      end
      if #parts > 0 then table.insert(lines, L("gearReagents") .. ": " .. table.concat(parts, ", ")) end
    end
  end
  return lines
end

-- Display name and quality colour (localised name once the item is cached).
local QUALITY = {[2] = {0.12, 1, 0}, [3] = {0, 0.44, 0.87}, [4] = {0.64, 0.21, 0.93}, [5] = {1, 0.5, 0}}
function G:Name(rec)
  local _, name = ItemLink(rec.id)
  local c = QUALITY[rec.q] or {1, 1, 1}
  return name or rec.n, c
end

function G:Icon(id)
  local tex = C_Item and C_Item.GetItemIconByID and Call(C_Item.GetItemIconByID, id)
  if not tex and GetItemIcon then tex = Call(GetItemIcon, id) end
  return Plain(tex) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Cache refresh: when items arrive, the open tab redraws (throttled).
G.frame = CreateFrame("Frame")
for _, e in ipairs({"GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP",
    "UNIT_INVENTORY_CHANGED"}) do
  pcall(G.frame.RegisterEvent, G.frame, e)
end
local dirty = false
local function RedrawGear()
  local UI = PSS.UI
  local f = _G.PetSkillScoutFrame
  if UI and UI.view == "gear" and UI.UpdateGear and f and f:IsShown() then pcall(UI.UpdateGear, UI) end
end
G.Redraw = RedrawGear
G.frame:SetScript("OnEvent", function(_, event, unit)
  if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
  dirty = true
  -- New gear: redraw at once and again when the item's stats have arrived.
  if (event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED") and C_Timer then
    if PSS.GearCompare and PSS.GearCompare.Reset then pcall(PSS.GearCompare.Reset, PSS.GearCompare) end
    C_Timer.After(0.2, RedrawGear)
    C_Timer.After(1.5, RedrawGear)
  end
end)
local t = 0
G.frame:SetScript("OnUpdate", function(_, e)
  t = t + (e or 0)
  if t < 0.5 then return end
  t = 0
  if dirty then
    dirty = false
    local UI = PSS.UI
    if UI and UI.view == "gear" and UI.UpdateGear then pcall(UI.UpdateGear, UI) end
  end
end)
G.frame.pssKey = "Gear"
PSS:Every(G.frame, 0.5)
