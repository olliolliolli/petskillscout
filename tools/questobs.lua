-- Report of quests learned in game, for the data update ("чек").
-- Usage: lua5.1 tools/questobs.lua <SavedVariables/PetSkillScout.lua> [PetSkillScout dir]
-- Prints every learned quest: confirmed or not, giver, position, rewards, and
-- whether the AllTheThings QuestDB of the addon already knows it.
local sv, dir = arg[1], arg[2] or "PetSkillScout"
assert(sv, "path to SavedVariables/PetSkillScout.lua")
PetSkillScout = {}
local okDB = pcall(dofile, dir .. "/QuestDB.lua")
local QDB = okDB and PetSkillScout.QuestDB or {}
dofile(sv)
local recs = PetSkillScoutDB and PetSkillScoutDB.questObs or {}
local NEAR = 3
local function dist(a, b)
  if a.m ~= b.m then return math.huge end
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end
local ids = {}
for id in pairs(recs) do ids[#ids + 1] = id end
table.sort(ids)
local confirmed = 0
print("quest\tstatus\treporters\tgiver\tmap\tx\ty\tfaction\trewards\tin QuestDB\ttitle")
for _, id in ipairs(ids) do
  local r = recs[id]
  local best, n = nil, 0
  for _, p in pairs(r.r or {}) do
    local c = 0
    for _, q in pairs(r.r) do if dist(p, q) <= NEAR then c = c + 1 end end
    if c > n then best, n = p, c end
  end
  local ok = best and (n >= 2 or r.me)
  if ok then confirmed = confirmed + 1 end
  local q = QDB[id]
  local inDB = q and ((q.m and q.x) and "yes" or "no position") or "no"
  print(table.concat({id, ok and "confirmed" or "unconfirmed", n, tostring(r.g or "") .. (r.gn and (" " .. r.gn) or ""),
    best and best.m or "", best and best.x or "", best and best.y or "", r.f or "", table.concat(r.i or {}, ","),
    inDB, r.n or ""}, "\t"))
end
print(string.format("records %d, confirmed %d", #ids, confirmed))
