-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Training point planner: which skill ranks fit into the pet's training points
-- and 4 skill slots, with presets for solo, dungeons and PvP. Only a plan: the
-- skills are still taught at Beast Training by the player.
local PSS = PetSkillScout
PSS.Planner = {}
local P = PSS.Planner
P.SLOTS = 4

local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
end
local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end

-- total training points of the pet (nil when the client does not tell).
function P:Budget()
  local fn = (C_PetInfo and C_PetInfo.GetPetTrainingPoints) or GetPetTrainingPoints
  local total, spent = safe(fn)
  if Secret(total) or Secret(spent) then return nil end
  total = tonumber(total)
  if not total or total <= 0 then return nil end
  return math.floor(total), tonumber(spent) and math.floor(spent) or nil
end

local function Pet() return PSS.MyPet and PSS.MyPet.active and PSS.MyPet or nil end

function P:Keys(pet)
  pet = pet or Pet()
  local out = {}
  for _, key in ipairs(pet and PSS.FamilySkills and PSS.FamilySkills[pet.family] or {}) do
    if PSS.Abilities[key] and PSS.Ranks[key] and #PSS.Ranks[key] > 0 then table.insert(out, key) end
  end
  return out
end

function P:Cost(key, rank)
  local meta = rank and rank > 0 and PSS.Ranks[key] and PSS.Ranks[key][rank]
  if not meta then return 0, false end
  return meta.tp or 0, meta.tp ~= nil
end

-- Highest rank the pet's level allows.
function P:MaxAllowed(key, petLevel)
  local best = 0
  for r, meta in ipairs(PSS.Ranks[key] or {}) do
    if not petLevel or (meta.petLevel or 0) <= petLevel then best = r end
  end
  return best
end

function P:Current(pet)
  local cur = {}
  for _, s in ipairs((pet or Pet() or {}).spells or {}) do
    if s.key and s.rank and PSS.Ranks[s.key] then cur[s.key] = math.max(cur[s.key] or 0, s.rank) end
  end
  return cur
end

local function PlanKey(pet)
  local guid = UnitGUID and UnitGUID("pet")
  if type(guid) == "string" and not Secret(guid) then return guid end
  return pet and pet.name or "?"
end

function P:Plan(pet)
  pet = pet or Pet()
  if not (pet and PetSkillScoutDB) then return {} end
  PetSkillScoutDB.tpPlans = PetSkillScoutDB.tpPlans or {}
  local key = PlanKey(pet)
  if not PetSkillScoutDB.tpPlans[key] then
    local copy = {}
    for k, v in pairs(self:Current(pet)) do copy[k] = v end
    PetSkillScoutDB.tpPlans[key] = copy
  end
  return PetSkillScoutDB.tpPlans[key]
end

function P:SetPlan(plan, pet)
  pet = pet or Pet()
  if not (pet and PetSkillScoutDB) then return end
  PetSkillScoutDB.tpPlans = PetSkillScoutDB.tpPlans or {}
  PetSkillScoutDB.tpPlans[PlanKey(pet)] = plan
end

-- cost, slots used, any cost unknown
function P:Totals(plan)
  local cost, slots, unknown = 0, 0, false
  for key, rank in pairs(plan or {}) do
    if rank and rank > 0 then
      local c, known = self:Cost(key, rank)
      cost, slots = cost + c, slots + 1
      if not known then unknown = true end
    end
  end
  return cost, slots, unknown
end

-- Set one skill (rank 0 removes it). Returns false when slots are full.
function P:Set(key, rank)
  local plan = self:Plan()
  if rank > 0 and not (plan[key] and plan[key] > 0) then
    local _, slots = self:Totals(plan)
    if slots >= self.SLOTS then return false end
  end
  plan[key] = rank > 0 and rank or nil
  return true
end

-- Presets -------------------------------------------------------------------------
local MOVE = {Dash = true, Dive = true}
local DAMAGE = {Bite = true, Claw = true}
local ROLES = {
  solo = {"damage", "signature", "Growl", "move", "Cower"},
  dungeon = {"damage", "signature", "Cower", "move"},
  pvp = {"move", "damage", "signature", "Cower"},
}

local function Ordered(keys, role)
  local out, used = {}, {}
  local function add(k) if k and not used[k] then used[k] = true; table.insert(out, k) end end
  for _, slot in ipairs(ROLES[role] or ROLES.solo) do
    for _, k in ipairs(keys) do
      local kind = PSS.Abilities[k] and PSS.Abilities[k].kind
      if slot == "damage" and DAMAGE[k] then add(k)
      elseif slot == "move" and MOVE[k] then add(k)
      elseif slot == "signature" and kind == "family" then add(k)
      elseif slot == k then add(k) end
    end
  end
  return out
end
P.Ordered = Ordered

-- Greedy: each skill in role order at the highest rank that still fits.
function P:Preset(role, pet)
  pet = pet or Pet()
  if not pet then return nil end
  local budget = self:Budget()
  local plan, cost, slots = {}, 0, 0
  for _, key in ipairs(Ordered(self:Keys(pet), role)) do
    if slots >= self.SLOTS then break end
    for r = self:MaxAllowed(key, pet.level), 1, -1 do
      local c = self:Cost(key, r)
      if not budget or cost + c <= budget then
        plan[key], cost, slots = r, cost + c, slots + 1
        break
      end
    end
  end
  self:SetPlan(plan, pet)
  return plan
end

-- Ranks in the plan that the hunter does not know yet and wild beasts teach.
function P:Missing(plan)
  local out = {}
  for key, rank in pairs(plan or self:Plan()) do
    local learn = PSS.Abilities[key] and PSS.Abilities[key].learn
    local known = PSS.Route and PSS.Route:KnownRank(key) or 0
    if learn == "beast" and rank and rank > known then table.insert(out, {key = key, rank = rank}) end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

function P:ToRoute()
  local added = 0
  for _, m in ipairs(self:Missing()) do
    if PSS.Route and PSS.Route:Add(m.key, m.rank) then added = added + 1 end
  end
  return added
end
