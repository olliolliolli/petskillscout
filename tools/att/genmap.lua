-- Map points for revaddons.com from ATT's Forever database (MIT):
-- every NPC, quest giver / quest, object and tameable beast with coordinates.
-- Usage (from tools/att): lua5.1 genmap.lua <.contrib/.db> <out.json>
local BASE, OUT = arg[1], arg[2]
local pts = {}      -- key "kind:id" -> {kind, id, list of {x,y,map}, side, quest giver?}
local function add(kind, id, node)
  local list = {}
  local c = rawget(node, "coord")
  if type(c) == "table" then list[1] = c end
  local cs = rawget(node, "coords")
  if type(cs) == "table" then for _, p in ipairs(cs) do list[#list + 1] = p end end
  if #list == 0 then return end
  local k = kind .. ":" .. id
  local e = pts[k] or {kind = kind, id = id, c = {}}
  pts[k] = e
  for _, p in ipairs(list) do
    if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) and tonumber(p[3]) then
      e.c[#e.c + 1] = {tonumber(p[1]), tonumber(p[2]), tonumber(p[3])}
    end
  end
  local r = rawget(node, "races")
  if r ~= nil and r == rawget(_G, "ALLIANCE_ONLY") then e.side = "A" elseif r ~= nil and r == rawget(_G, "HORDE_ONLY") then e.side = "H" end
end
__visit = function(node)
  local q = rawget(node, "questID")
  if type(q) == "number" then add("q", q, node) return end
  local n = rawget(node, "npcID") or rawget(node, "creatureID")
  if type(n) == "number" and n > 0 then add("n", n, node) return end
  local o = rawget(node, "objectID")
  if type(o) == "number" then add("o", o, node) end
end
dofile("driver.lua")

-- names: from the comments next to the ids in the source files
local names = {n = {}, o = {}, q = {}}
for k, v in pairs(QNAME or {}) do names.q[k] = v end
for k, v in pairs(NNAME or {}) do names.n[k] = v end
for _, f in ipairs(__files(BASE .. "/forever")) do
  local fh = io.open(f, "rb"); local src = fh:read("*a"); fh:close()
  for line in src:gmatch("[^\n]+") do
    local id, nm = line:match("[^%w_]n%((%d+)%s*,.-%-%-%s*(.-)%s*$")
    if id and nm ~= "" and not names.n[tonumber(id)] then names.n[tonumber(id)] = nm end
    id, nm = line:match("[^%w_]o%((%d+)%s*,.-%-%-%s*(.-)%s*$")
    if id and nm ~= "" and not names.o[tonumber(id)] then names.o[tonumber(id)] = nm end
  end
end
-- JSON out
local function esc(s) return (tostring(s):gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end)) end
local out, n = {}, 0
for _, e in pairs(pts) do
  local nm = names[e.kind] and names[e.kind][e.id]
  local cs = {}
  for _, p in ipairs(e.c) do cs[#cs + 1] = string.format("[%.1f,%.1f,%d]", p[1], p[2], p[3]) end
  out[#out + 1] = string.format('{"k":"%s","id":%d,"n":"%s"%s,"c":[%s]}', e.kind, e.id, esc(nm or ""),
    e.side and (',"s":"' .. e.side .. '"') or "", table.concat(cs, ","))
  n = n + 1
end
local fh = assert(io.open(OUT, "w")); fh:write("[" .. table.concat(out, ",\n") .. "]\n"); fh:close()
io.stderr:write("map points " .. n .. "\n")
