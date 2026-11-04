-- Atlas of every tameable beast (AtlasData.lua): decoding, lookups and filters.
local PSS = PetSkillScout
PSS.Atlas = { list = {}, byNpc = {}, built = false }
local A = PSS.Atlas

local index
local function Decode(packed, fit)
  local D = PSS.AtlasData
  if not index then
    index = {}
    for i = 1, #D.alphabet do index[D.alphabet:sub(i, i)] = i - 1 end
  end
  local a, b, d = fit[1], fit[2], fit[3]
  local points = {}
  for i = 1, #packed - 3, 4 do
    local c1, c2, c3, c4 = index[packed:sub(i, i)], index[packed:sub(i+1, i+1)], index[packed:sub(i+2, i+2)], index[packed:sub(i+3, i+3)]
    if c1 and c2 and c3 and c4 then
      local X, Y = (c1 * 72 + c2) * 2, (c3 * 72 + c4) * 2
      local x, y = a * X + b, 1.5 * a * Y + d
      if x >= 0 and x <= 100 and y >= 0 and y <= 100 then
        table.insert(points, { math.floor(x * 10 + 0.5) / 10, math.floor(y * 10 + 0.5) / 10 })
      end
    end
  end
  return points
end

local function Anchor(points)
  local sx, sy = 0, 0
  for _, p in ipairs(points) do sx, sy = sx + p[1], sy + p[2] end
  sx, sy = sx / #points, sy / #points
  local best, ax, ay
  for _, p in ipairs(points) do
    local dd = (p[1] - sx) ^ 2 + (p[2] - sy) ^ 2
    if not best or dd < best then best, ax, ay = dd, p[1], p[2] end
  end
  return ax, ay
end

function A:Build()
  if self.built or not PSS.AtlasData then return end
  self.built = true
  local D = PSS.AtlasData
  -- Teaching skills from Database.lua, keyed by NPC ID.
  local teaches = {}
  for _, b in ipairs(PSS.Beasts or {}) do
    if b.npcID and b.ability then
      teaches[b.npcID] = teaches[b.npcID] or {}
      table.insert(teaches[b.npcID], { ability = b.ability, rank = b.rank })
    end
  end
  for _, row in ipairs(D.rows) do
    local npc, name, fam, lo, hi, rarity, speed, isNew, areas, packed = unpack(row)
    local rec = {
      id = "atlas-" .. npc, npcID = npc, name = name, family = D.families[fam],
      minLevel = lo > 0 and lo or nil, maxLevel = hi > 0 and hi or nil,
      rarity = rarity, elite = rarity == 1 or rarity == 3, isRare = rarity >= 2,
      speed = speed > 0 and speed or 2.0, fast = speed > 0 and speed < 2.0,
      new = isNew == 1, zones = {}, teaches = teaches[npc],
      displayID = PSS.DisplayIDs and PSS.DisplayIDs[npc] or nil,
      verifiedCoords = false, source = "mmonster Forever map",
    }
    for _, area in ipairs(areas) do
      local zone = D.zones[area]
      if zone then table.insert(rec.zones, zone) end
    end
    rec.zone = rec.zones[1]
    -- Coordinates: the first zone with packed points and a calibration.
    for _, area in ipairs(areas) do
      local zone = D.zones[area]
      local fit = zone and D.fits[zone]
      if fit and packed[area] then
        local points = Decode(packed[area], fit)
        if #points > 0 then
          rec.zone, rec.mapID, rec.spawnPoints = zone, fit[4], points
          rec.x, rec.y = Anchor(points)
          rec.verifiedCoords = true
          break
        end
      end
    end
    table.insert(self.list, rec)
    self.byNpc[npc] = rec
  end
  -- Teaching beasts from Database.lua that the map data does not list.
  for _, b in ipairs(PSS.Beasts or {}) do
    if b.npcID and not self.byNpc[b.npcID] then
      local rec = {
        id = "atlas-" .. b.npcID, npcID = b.npcID, name = b.name, family = b.family,
        minLevel = b.minLevel, maxLevel = b.maxLevel, rarity = 0, elite = false, isRare = false,
        speed = 2.0, fast = false, new = false, zones = b.zone and {b.zone} or {}, zone = b.zone,
        teaches = teaches[b.npcID], displayID = PSS.DisplayIDs and PSS.DisplayIDs[b.npcID] or nil,
        mapID = b.mapID, spawnPoints = b.spawnPoints, x = b.x, y = b.y,
        verifiedCoords = b.verifiedCoords, source = b.source,
      }
      if rec.x and math.abs(rec.x) <= 1 then rec.x, rec.y = rec.x * 100, rec.y * 100 end
      table.insert(self.list, rec)
      self.byNpc[b.npcID] = rec
    end
  end
  table.sort(self.list, function(x, y)
    local lx, ly = x.minLevel or 99, y.minLevel or 99
    if lx ~= ly then return lx < ly end
    return x.name < y.name
  end)
end

function A:Get(npcID)
  self:Build()
  return npcID and self.byNpc[npcID]
end

-- Filters: text (name/zone/family, any UI language), fast, rare, canTame (player level).
function A:Filter(text, onlyFast, onlyRare, canTame)
  self:Build()
  local out = {}
  local query = string.lower(text or "")
  local level = PSS.player and PSS.player.level or 60
  for _, rec in ipairs(self.list) do
    local ok = true
    if onlyFast and not rec.fast then ok = false end
    if ok and onlyRare and not rec.isRare then ok = false end
    if ok and canTame and (not rec.minLevel or rec.minLevel > level) then ok = false end
    if ok and query ~= "" then
      local hay = string.lower(rec.name .. " " .. table.concat(rec.zones, " ") .. " " .. (rec.family or "") ..
        " " .. (rec.family and PSS:NameFamily(rec.family) or ""))
      ok = string.find(hay, query, 1, true) ~= nil
    end
    if ok then table.insert(out, rec) end
  end
  return out
end

-- "attack 1.2s" (green when faster than the standard 2.0 s).
function A:SpeedText(rec)
  if not rec or not rec.speed then return "?" end
  local text = string.format(PSS:L("atlasSpeed"), rec.speed)
  if rec.fast then return "|cff7ee0a3" .. text .. "|r" end
  if rec.speed > 2.0 then return "|cffff9a6a" .. text .. "|r" end
  return text
end

function A:TeachesText(rec)
  if not (rec and rec.teaches) then return nil end
  local parts, seen = {}, {}
  for _, t in ipairs(rec.teaches) do
    local key = t.ability .. (t.rank or "")
    if not seen[key] then
      seen[key] = true
      table.insert(parts, PSS:NameAbility(t.ability) .. " " .. tostring(t.rank or "?"))
    end
  end
  return table.concat(parts, ", ")
end
