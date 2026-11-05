-- Builds PetSkillScout/LearnedData.lua from SavedVariables, for the data update ("чек").
-- Usage: lua5.1 tools/learned.lua <SavedVariables/PetSkillScout.lua> [more SavedVariables ...]
-- Takes only confirmed records: quests seen by you or by 2+ hunters at the same spot,
-- rare spots seen by you or confirmed by 2 hunters, ammo vendors with a position.
-- Merges with the LearnedData.lua already in the addon (nothing is ever dropped).
local OUT = "PetSkillScout/LearnedData.lua"
local NEAR = 3
local function dist(a, b)
  if not (a and b) or a.m ~= b.m then return math.huge end
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end
PetSkillScout = {}
pcall(dofile, OUT)
local base = PetSkillScout.LearnedData or {}
local data = {quests = base.quests or {}, vendors = base.vendors or {}, rares = base.rares or {}}
local added = {quests = 0, vendors = 0, rares = 0}
for _, sv in ipairs(arg) do
  PetSkillScoutDB = nil
  dofile(sv)
  local db = PetSkillScoutDB or {}
  for id, r in pairs(db.questObs or {}) do
    local best, n = nil, 0
    for _, p in pairs(r.r or {}) do
      local c = 0
      for _, q in pairs(r.r) do if dist(p, q) <= NEAR then c = c + 1 end end
      if c > n then best, n = p, c end
    end
    -- Your own records count even without a position (new rewards are worth it).
    if ((best and n >= 2) or r.me) and not data.quests[id] then
      best = best or {}
      data.quests[id] = {n = r.n, g = r.g, gn = r.gn, f = r.f, m = best.m, x = best.x, y = best.y, i = r.i}
      added.quests = added.quests + 1
    end
  end
  for npc, v in pairs(db.ammoVendors or {}) do
    if v.m and v.x and v.y and not data.vendors[npc] then
      data.vendors[npc] = {n = v.n, m = v.m, x = v.x, y = v.y, k = v.k, z = v.z}
      added.vendors = added.vendors + 1
    end
  end
  local function addSpot(id, npc, m, x, y)
    local list = data.rares[id] or {}
    data.rares[id] = list
    list.npc = list.npc or npc
    for _, p in ipairs(list) do if dist(p, {m = m, x = x, y = y}) <= 2 then return end end
    list[#list + 1] = {m = m, x = x, y = y}
    added.rares = added.rares + 1
  end
  for id, rec in pairs(db.rareSeen or {}) do
    if rec.mapID and rec.x and rec.y then addSpot(id, nil, rec.mapID, rec.x, rec.y) end
  end
  for id, list in pairs(db.rareSpots or {}) do
    for _, p in ipairs(list) do
      if p.c or not p.by then addSpot(id, list.npc, p.m, p.x, p.y) end
    end
  end
end
-- Write (sorted, stable output).
local function q(s) return string.format("%q", tostring(s)) end
local function keys(t) local k = {} for x in pairs(t) do k[#k + 1] = x end table.sort(k, function(a, b) return tostring(a) < tostring(b) end) return k end
local function key(k) return type(k) == "number" and ("[" .. k .. "]") or ("[" .. q(k) .. "]") end
local L = {"-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.",
  "-- Data learned in game by PetSkillScout users (own observations), built by tools/learned.lua.",
  "-- Quests: giver and rewards; vendors: ammo vendors; rares: places rares were seen.",
  "PetSkillScout.LearnedData = {", "quests = {"}
for _, id in ipairs(keys(data.quests)) do
  local r = data.quests[id]
  L[#L + 1] = string.format("  %s = {n = %s, g = %s, gn = %s, f = %s, m = %s, x = %s, y = %s, i = {%s}},", key(id),
    r.n and q(r.n) or "nil", r.g or "nil", r.gn and q(r.gn) or "nil", r.f and q(r.f) or "nil",
    tostring(r.m or "nil"), tostring(r.x or "nil"), tostring(r.y or "nil"),
    table.concat(r.i or {}, ", "))
end
L[#L + 1] = "},"; L[#L + 1] = "vendors = {"
for _, id in ipairs(keys(data.vendors)) do
  local v = data.vendors[id]
  L[#L + 1] = string.format("  %s = {n = %s, m = %s, x = %s, y = %s, k = %s, z = %s},", key(id), q(v.n or "?"), v.m, v.x, v.y,
    q(v.k or ""), v.z and q(v.z) or "nil")
end
L[#L + 1] = "},"; L[#L + 1] = "rares = {"
for _, id in ipairs(keys(data.rares)) do
  local list = data.rares[id]
  local pts = {}
  for _, p in ipairs(list) do pts[#pts + 1] = string.format("{m = %s, x = %s, y = %s}", p.m, p.x, p.y) end
  L[#L + 1] = string.format("  %s = {npc = %s, %s},", key(id), list.npc or "nil", table.concat(pts, ", "))
end
L[#L + 1] = "},"; L[#L + 1] = "}"
local f = assert(io.open(OUT, "w")); f:write(table.concat(L, "\n") .. "\n"); f:close()
print(string.format("LearnedData: +%d quests, +%d vendors, +%d rare spots", added.quests, added.vendors, added.rares))
