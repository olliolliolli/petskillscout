-- Build PetSkillScout/VendorDB.lua from ATT's Forever database (MIT):
-- for gear sold by NPC vendors, where the vendor stands and the reputation
-- the item needs (ATT ItemDB minReputation), plus holiday-only vendors.
local BASE, OUT, COMMIT = arg[1], arg[2], arg[3]
local vend = {} -- item -> {npc, x, y, m, rep = {faction, value}, hol}
local function coordOf(n)
  local c = rawget(n, "coord") or (type(rawget(n, "coords")) == "table" and n.coords[1])
  if type(c) == "table" and type(c[1]) == "table" then c = c[1] end
  if type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" then return c end
end
local function items(node, out, depth)
  if type(node) ~= "table" or depth > 4 then return end
  local id = rawget(node, "itemID")
  if id then out[#out + 1] = node end
  local g = rawget(node, "groups") or rawget(node, "g")
  if type(g) == "table" then for _, ch in ipairs(g) do items(ch, out, depth + 1) end end
end
__visit = function(node)
  local npc = rawget(node, "npcID")
  if not npc then return end
  local c = coordOf(node)
  if not c then return end
  local list = {}
  items(node, list, 0)
  for _, it in ipairs(list) do
    local id = it.itemID
    if not vend[id] then
      vend[id] = {npc = npc, x = c[1], y = c[2], m = c[3], rep = rawget(it, "minReputation") or rawget(node, "minReputation"),
        hol = rawget(it, "e") or rawget(node, "e")}
    end
  end
end
dofile("driver.lua")
local DB = (_ and _.ItemDB) or ItemDB or {}
local n = 0
local fh = assert(io.open(OUT, "w"))
fh:write("-- Vendors of hunter-usable gear: generated from AllTheThings (Forever), commit " .. (COMMIT or "?") .. ", MIT licence (QuestDB-LICENSE.txt).\n")
fh:write("-- [item] = {npc, x, y, uiMapID, rep = {factionID, standing}, hol = event}\n")
fh:write("local PSS = PetSkillScout\nPSS.VendorDB = {\n")
local ids = {}
for id in pairs(vend) do ids[#ids + 1] = id end
table.sort(ids)
for _, id in ipairs(ids) do
  local v, d = vend[id], DB[id] or {}
  if d.equippable or d.class == 2 or d.class == 4 then
    local rep = v.rep or d.minReputation
    local f = string.format("[%d]={%d,%.1f,%.1f,%d", id, v.npc, v.x, v.y, v.m)
    if type(rep) == "table" and rep[1] then f = f .. string.format(",rep={%d,%d}", rep[1], rep[2] or 0) end
    if v.hol then f = f .. ",hol=" .. tostring(v.hol) end
    fh:write(f .. "},\n"); n = n + 1
  end
end
fh:write("}\n"); fh:close()
io.stderr:write("vendor gear items " .. n .. "\n")
