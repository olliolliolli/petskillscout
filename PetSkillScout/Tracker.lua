-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
local PSS = PetSkillScout

-- A rank filter of "All" (or nil) matches every rank of the selected ability.
local function RankMatches(beastRank, wanted)
  if wanted == nil or wanted == "All" then return true end
  return tonumber(beastRank) == tonumber(wanted)
end

function PSS:GetCandidates()
  local out = {}
  local f = self.filters
  for _, b in ipairs(self.Beasts or {}) do
    local ok = b.ability == f.ability and RankMatches(b.rank, f.rank)
    if ok and f.family and f.family ~= "All" and b.family ~= f.family then ok = false end
    if ok and b.maxLevel and b.maxLevel < (tonumber(f.minLevel) or 1) then ok = false end
    if ok and b.minLevel and b.minLevel > (tonumber(f.maxLevel) or 60) then ok = false end
    if ok and f.faction and f.faction ~= "All" and b.faction ~= "All" and b.faction ~= f.faction then ok = false end
    if ok then
      b._score = self:ScoreBeast(b)
      table.insert(out, b)
    end
  end
  table.sort(out, function(a, b)
    local sa, sb = a._score or 999999, b._score or 999999
    if sa ~= sb then return sa < sb end
    return (a.name or "") < (b.name or "")
  end)
  return out
end

-- Lower score = better candidate. This is a sorting heuristic, not route finding:
-- same zone first, then faction and level fit, then straight-line map distance.
function PSS:ScoreBeast(b)
  local p = self.player or {}
  local level = p.level or 1
  local score = 100000
  if b.zone and p.zone and b.zone == p.zone then score = score - 50000 end
  if b.faction == p.faction then score = score - 1000 end
  if b.faction == "All" then score = score - 500 end
  if b.minLevel and b.minLevel <= level + 2 and b.maxLevel and b.maxLevel >= level - 8 then score = score - 250 end
  if b.verifiedCoords and b.x and b.y and p.x and p.y and b.mapID and p.mapID == b.mapID then
    local bx, by = b.x, b.y
    if math.abs(bx) > 1 then bx = bx / 100 end
    if math.abs(by) > 1 then by = by / 100 end
    -- Distance in map-percent units (0..~141); only used for ordering.
    local dx, dy = (bx - p.x) * 100, (by - p.y) * 100
    score = score + math.sqrt(dx * dx + dy * dy)
  end
  return score
end
