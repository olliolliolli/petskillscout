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
-- Like Pawn, an item's value is the sum of weight x amount over every stat
-- it has; the weights are our own, in ranged attack power:
-- * agi: 2 ranged AP plus the crit it gives; crit / hit / haste per 1 %.
-- * int: 15 mana each, valued like mp5 over a fight (Careful Aim is added
--   on top from your rank, see G:CarefulAimPct); spi: mostly out-of-combat
--   regeneration; res: per point of any resistance.
G.WEIGHTS = {
  MM = {agi = 2.6, ap = 1.0, rap = 1.0, map = 0.1, crit = 28, hit = 22, haste = 16, int = 0.5, spi = 0.15, sta = 0.4,
    str = 0.1, armor = 0.01, mp5 = 1.5, res = 0.05},
  BM = {agi = 2.5, ap = 1.05, rap = 1.0, map = 0.1, crit = 24, hit = 22, haste = 15, int = 0.6, spi = 0.15, sta = 0.4,
    str = 0.1, armor = 0.01, mp5 = 2.0, res = 0.05},
  SV = {agi = 2.8, ap = 1.0, rap = 1.0, map = 0.25, crit = 26, hit = 22, haste = 15, int = 0.5, spi = 0.15, sta = 0.4,
    str = 0.15, armor = 0.01, mp5 = 1.5, res = 0.05},
}
-- Pawn's rule: a change under 0.5 % of the equipped item's value is no change.
G.MIN_UPGRADE = 0.005
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
-- Quest rewards of WoW Forever (ATT, QuestDB / QuestItems) that the classic
-- item list lacks: new Forever items like Master Hunter's Wand. Inventory type
-- (Enum.InventoryType) -> slot kind and equip location.
local INV = {[1] = {"head", "INVTYPE_HEAD"}, [2] = {"neck", "INVTYPE_NECK"}, [3] = {"shoulder", "INVTYPE_SHOULDER"},
  [5] = {"chest", "INVTYPE_CHEST"}, [20] = {"chest", "INVTYPE_ROBE"}, [6] = {"waist", "INVTYPE_WAIST"},
  [7] = {"legs", "INVTYPE_LEGS"}, [8] = {"feet", "INVTYPE_FEET"}, [9] = {"wrist", "INVTYPE_WRIST"},
  [10] = {"hands", "INVTYPE_HAND"}, [11] = {"finger", "INVTYPE_FINGER"}, [12] = {"trinket", "INVTYPE_TRINKET"},
  [13] = {"onehand", "INVTYPE_WEAPON"}, [21] = {"mainhand", "INVTYPE_WEAPONMAINHAND"},
  [22] = {"offhand", "INVTYPE_WEAPONOFFHAND"}, [17] = {"twohand", "INVTYPE_2HWEAPON"},
  [15] = {"ranged", "INVTYPE_RANGED"}, [26] = {"ranged", "INVTYPE_RANGEDRIGHT"},
  [16] = {"back", "INVTYPE_CLOAK"}}
local function AddQuestRewards()
  local items, quests = PSS.QuestItems, PSS.QuestDB
  if not (items and quests) then return end
  local GC = PSS.GearCompare
  for qid, r in pairs(quests) do
    if type(r.i) == "table" then
      for _, id in ipairs(r.i) do
        local it = items[id]
        local inv = it and INV[it.inv]
        -- Only items ATT describes (name, item level) and that are not
        -- encrypted in the game; they arrive with the data updates.
        if inv and not byId[id] and (it.q or 0) >= 2 and type(it.n) == "string" and it.n ~= "" and it.il then
          local ok, from = true, nil
          if GC and GC.Usable then ok, from = GC:Usable(it.c, it.sc, inv[2]) end
          if ok then
            local lvl = math.max(r.l or 1, from or 0)
            local rec = {id = id, n = it.n, slot = inv[1], q = it.q, lvl = lvl, req = lvl, st = {}, fac = r.s,
              src = {{t = "q", n = r.n, f = r.s}}, forever = true}
            byId[id] = rec
            bySlot[rec.slot] = bySlot[rec.slot] or {}
            table.insert(bySlot[rec.slot], rec)
          end
        end
      end
    end
  end
end
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
  pcall(AddQuestRewards)
  -- Vendors from ATT (VendorDB): where the vendor stands, and the reputation
  -- the item needs (Revered with League of Arathor...), for every item.
  local V = PSS.VendorDB or {}
  for id, rec in pairs(byId) do
    local v = V[id]
    if v then
      rec.vendor = v
      if v.rep and not rec.rep then
        local val = v.rep[2] or 0
        rec.rep = v.rep[1]
        rec.rr = val >= 42000 and 7 or val >= 21000 and 6 or val >= 9000 and 5 or val >= 3000 and 4 or nil
      end
    end
  end
end
-- Faction name: our list first, then the game.
function G:RepName(fid)
  if self.REP_NAMES[fid] then return self.REP_NAMES[fid] end
  local fn = C_Reputation and C_Reputation.GetFactionDataByID
  if fn then
    local ok, d = pcall(fn, fid)
    if ok and type(d) == "table" and d.name then return d.name end
  end
  if GetFactionInfoByID then
    local ok, name = pcall(GetFactionInfoByID, fid)
    if ok and name then return name end
  end
  return "#" .. fid
end
function G:Get(id) Index(); return byId[id] end

-- Settings -----------------------------------------------------------------
local function DB() return PetSkillScoutDB or {} end
function G:Spec()
  local s = DB().gearSpec
  if s == "BM" or s == "MM" or s == "SV" then return s end
  return "MM"
end
function G:SetSpec(s)
  if PetSkillScoutDB then PetSkillScoutDB.gearSpec = s end
end
-- BiS mode takes every source (raids, rare drops, PvP) regardless of the toggles.
function G:IncludeRaids() return self.allSources or DB().gearRaids == true end
function G:IncludePvp() return self.allSources or DB().gearPvp == true end
function G:IncludeRare() return self.allSources or DB().gearRare == true end

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
  {"RESISTANCE0", "armor"}, {"RESISTANCE", "res"}, {"MANA_REGENERATION", "mp5"}, {"POWER_REGEN0", "mp5"},
}
-- Hit / crit in percent as the tooltip prints them ("Improves your chance to
-- hit by 0.3%"). GetItemStats gives Forever's own unit (3 for 0.3 %), which
-- was read as 3 % and made such items look far better than they are.
local pctCache = {}
local function TooltipPercents(link)
  local c = pctCache[link]
  if c ~= nil then return c or nil end
  if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then pctCache[link] = false; return nil end
  local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  local out = {}
  for _, line in ipairs(data.lines) do
    local t = line.leftText
    if type(t) == "string" and not (PSS.IsSecret and PSS.IsSecret(t)) then
      local low = t:lower()
      local n = tonumber(low:match("([%d%.]+)%s*%%"))
      if n then
        if low:find("critical") or low:find("крит") then out.crit = (out.crit or 0) + n
        elseif low:find("to hit") or low:find("влуч") then out.hit = (out.hit or 0) + n
        elseif low:find("haste") or low:find("швидк") or low:find("attack speed") then out.haste = (out.haste or 0) + n end
      end
    end
  end
  if next(out) then pctCache[link] = out end
  return out
end

-- An item's stats do not change: read once per link (the Gear tab asked
-- thousands of times per redraw, each with a tooltip scan).
local statCache = {}
local RuntimeStatsRaw
local function RuntimeStats(link)
  if type(link) ~= "string" then return nil end
  local c = statCache[link]
  if c then return c end
  c = RuntimeStatsRaw(link)
  if c then statCache[link] = c end
  return c
end
function RuntimeStatsRaw(link)
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
      elseif k:find("HASTE") then
        st.haste = (st.haste or 0) + (v > 5 and v / 14 or v)
      else
        for _, m in ipairs(STAT_KEYS) do
          if k:find(m[1]) then st[m[2]] = (st[m[2]] or 0) + v; break end
        end
      end
    end
  end
  if st.hit or st.crit or st.haste then
    local pct = TooltipPercents(link)
    if pct then
      if st.hit and pct.hit then st.hit = pct.hit end
      if st.crit and pct.crit then st.crit = pct.crit end
      if st.haste and pct.haste then st.haste = pct.haste end
    end
  end
  return next(st) and st or nil
end
G.RuntimeStats = RuntimeStats

local function ItemLink(id)
  local name, link = Call(C_Item and C_Item.GetItemInfo or GetItemInfo, id)
  return Plain(link), Plain(name)
end

local exists = {}
function G:Exists(id)
  local v = exists[id]
  if v == nil then
    local fn = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not fn then return true end
    local itemID, _, _, _, icon = Call(fn, id)
    v = Plain(itemID) ~= nil and Plain(icon) ~= nil
    exists[id] = v
  end
  return v
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
  -- Forever quest rewards carry no stats of their own: ask the client.
  if rec and rec.forever then self:Request(id) end
  if rec then return rec.st end
  self:Request(id)
  return nil
end

-- Careful Aim (Forever hunter talent, Marksmanship): attack power from
-- Intellect, 20 % per rank in the tooltip. The rank is read the way the
-- game's talent frame does (C_ClassTalents.GetActiveConfigID -> C_Traits);
-- the percent comes from the spell text when it can be read.
local CAREFUL_AIM = {["careful aim"] = true, ["ретельне прицілювання"] = true}
local aimPct
function G:CarefulAimPct()
  if aimPct ~= nil then return aimPct end
  aimPct = 0
  if not (C_ClassTalents and C_Traits and C_ClassTalents.GetActiveConfigID) then return 0 end
  local configID = Plain(Call(C_ClassTalents.GetActiveConfigID))
  local cfg = configID and Call(C_Traits.GetConfigInfo, configID)
  for _, tree in ipairs(cfg and cfg.treeIDs or {}) do
    for _, node in ipairs(Call(C_Traits.GetTreeNodes, tree) or {}) do
      local ni = Call(C_Traits.GetNodeInfo, configID, node)
      local rank = ni and Plain(ni.activeRank)
      local entry = ni and ((ni.activeEntry and ni.activeEntry.entryID) or (ni.entryIDs and ni.entryIDs[1]))
      local ei = entry and Call(C_Traits.GetEntryInfo, configID, entry)
      local di = ei and ei.definitionID and Call(C_Traits.GetDefinitionInfo, ei.definitionID)
      local spellID = di and Plain(di.spellID)
      local name = spellID and Plain(Call(C_Spell and C_Spell.GetSpellName, spellID))
      if type(name) == "string" and CAREFUL_AIM[name:lower()] then
        if type(rank) == "number" and rank > 0 then
          local per = 20
          local desc = Plain(Call(C_Spell and C_Spell.GetSpellDescription, spellID))
          local n = type(desc) == "string" and tonumber(desc:match("(%d+)%%"))
          -- The text is the first rank's when the spell is shared by ranks.
          if n and n > 0 and n <= 100 then per = n end
          aimPct = math.min(per * rank, 100)
          if n and n > 20 and n == 20 * rank then aimPct = n end
        end
        return aimPct
      end
    end
  end
  return aimPct
end
local aimEv = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE",
    "CHARACTER_POINTS_CHANGED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"}) do pcall(aimEv.RegisterEvent, aimEv, e) end
aimEv:SetScript("OnEvent", function()
  aimPct = nil
  if PSS.GearCompare and PSS.GearCompare.Reset then PSS.GearCompare:Reset() end
end)

function G:Score(st, slot, spec)
  if not st then return 0 end
  local w = self.WEIGHTS[spec or self:Spec()]
  local s = 0
  for k, v in pairs(st) do
    if w[k] then s = s + w[k] * v end
  end
  -- Intellect also gives ranged attack power with Careful Aim.
  if st.int then
    local pct = self:CarefulAimPct()
    if pct > 0 then s = s + st.int * pct / 100 * (w.rap or 1) end
  end
  if st.dps then
    if slot == "ranged" then s = s + st.dps * self.RANGED_DPS
    else s = s + st.dps * self.MELEE_DPS[spec or self:Spec()] end
  end
  return s
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
  -- Hunters in Forever cannot use thrown weapons.
  if rec.kind == "thrown" then return false end
  -- Only items the game client knows: the classic list also holds items that
  -- do not exist in Forever (shown as "?"). GetItemInfoInstant answers from
  -- the client database without a server query.
  if not self:Exists(rec.id) then return false end
  -- Forever quest rewards only once the game has told us their stats.
  if rec.forever then
    local st = self:Stats(rec.id)
    if not (st and st.live and next(st)) then return false end
  end
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
  if mode == "bis" then
    -- Best in slot at your level from every source (raids, rare drops, PvP).
    self.allSources = true
    local ok, plan, level = pcall(self.Plan, self, "now", spec)
    self.allSources = nil
    if ok then return plan, level end
    return {}, self:PlayerLevel()
  end
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
local DIFF_ORDER = {"dps", "agi", "ap", "rap", "crit", "hit", "haste", "sta", "int", "str", "spi", "mp5", "res", "armor"}
function G:Diff(new, old, slot)
  new, old = new or {}, old or {}
  local parts = {}
  for _, k in ipairs(DIFF_ORDER) do
    local d = (new[k] or 0) - (old[k] or 0)
    local pct = k == "crit" or k == "hit" or k == "haste"
    local min = pct and 0.05 or (k == "dps" and 0.1 or 0.999)
    if math.abs(d) >= min and not (k == "dps" and slot ~= "ranged" and #parts >= 2) then
      local label = L("stat_" .. k)
      if pct then
        table.insert(parts, string.format("%+.1f%% %s", d, label))
      elseif k == "dps" then
        table.insert(parts, string.format("%+.1f %s", d, label))
      else
        table.insert(parts, string.format("%+d %s", d > 0 and math.floor(d + 0.001) or math.ceil(d - 0.001), label))
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
    local pct = k == "crit" or k == "hit" or k == "haste"
    local min = pct and 0.05 or (k == "dps" and 0.1 or 0.999)
    if math.abs(d) >= min and not (k == "armor" and #parts >= 2) then
      local label, text = L("stat_" .. k)
      if pct then text = string.format("%+.1f%% %s", d, label)
      elseif k == "dps" then text = string.format("%+.1f %s", d, label)
      -- Like the game's own comparison: the fraction is dropped (14.7 -> 14).
      else text = string.format("%+d %s", d > 0 and math.floor(d + 0.001) or math.ceil(d - 0.001), label) end
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
    rep = "  ·  " .. self:RepName(rec.rep) .. (rank ~= "" and (" (" .. rank .. ")") or "")
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
    local hol = rec.vendor and rec.vendor.hol and ("  ·  " .. L("gearSeasonal")) or ""
    return s.n, L("gearKindVendor") .. (s.i and ("  ·  " .. s.i) or "") .. rep .. hol .. tail
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
    table.insert(lines, string.format(L("gearRep"), self:RepName(rec.rep),
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
-- Not UNIT_INVENTORY_CHANGED: it fires on every shot (ammo count).
for _, e in ipairs({"GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_LEVEL_UP"}) do
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
  -- Item data arrives for every item the game loads (tooltips, chat, other
  -- addons): redraw only for the ones this tab asked for.
  if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
    if not (type(unit) == "number" and requested[unit] == true) then return end
    requested[unit] = "got"
  end
  dirty = true
  -- New gear: redraw at once and again when the item's stats have arrived.
  -- Slot 0 is ammo (changes on every shot): nothing to redraw.
  if event == "PLAYER_EQUIPMENT_CHANGED" and unit ~= 0 and C_Timer then
    if PSS.GearCompare and PSS.GearCompare.Reset then pcall(PSS.GearCompare.Reset, PSS.GearCompare) end
    C_Timer.After(0.2, RedrawGear)
    C_Timer.After(1.5, RedrawGear)
  end
end)
local t = 0
G.frame:SetScript("OnUpdate", function(_, e)
  t = t + (e or 0)
  if t < 1.5 then return end
  t = 0
  if dirty then
    dirty = false
    RedrawGear()
  end
end)
G.frame.pssKey = "Gear"
PSS:Every(G.frame, 0.5)
