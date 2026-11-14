-- Run ATT's own Forever database through its DSL (lua5.1) and dump quests.
local BASE = arg[1]  -- .../.contrib/.db
local TAGS = {ANYCLASSIC=true, FOREVER=true, CAMELOT=true, CLASSIC=true, CRIEVE=true, EXPLORATION=true, OBJECTIVES=true, NOSIMPLIFY=true}
local VER = {1, 60, 1}
local EXP = {CLASSIC="1.0.0", TBC="2.0.1", WRATH="3.0.2", CATA="4.0.1", MOP="5.0.4", WOD="6.0.2", LEGION="7.0.3",
  BFA="8.0.1", SL="9.0.1", DF="10.0.2", TWW="11.0.2", MID="12.0.0"}
local function parsever(s)
  s = EXP[s] or s
  local t = {}
  for n in s:gmatch("%d+") do t[#t + 1] = tonumber(n) end
  if #t == 0 then return nil end
  return t
end
local function cmp(a, b)
  for i = 1, 4 do local x, y = a[i] or 0, b[i] or 0; if x ~= y then return x < y and -1 or 1 end end
  return 0
end
local function cond(expr)
  expr = expr:gsub("^%s+", ""):gsub("%s+$", "")
  local parts = {}
  for orpart in (expr .. " OR "):gmatch("(.-) OR ") do parts[#parts + 1] = orpart end
  for _, orpart in ipairs(parts) do
    local all = true
    for andpart in (orpart .. " AND "):gmatch("(.-) AND ") do
      local p = andpart:gsub("^%s+", ""):gsub("%s+$", "")
      local neg = false
      if p:match("^NOT ") then neg = true; p = p:sub(5) end
      local v
      local op, x = p:match("^(%u+)%s+(%S+)$")
      if op == "AFTER" or op == "BEFORE" then
        local pv = parsever(x)
        if pv then local c = cmp(VER, pv); v = (op == "AFTER") and c >= 0 or c < 0 else v = false end
      else v = TAGS[p] == true end
      if neg then v = not v end
      if not v then all = false end
    end
    if all then return true end
  end
  return false
end
local function preprocess(src)
  local out, stack = {}, {}
  local function active() for _, s in ipairs(stack) do if not s.on then return false end end return true end
  for line in (src .. "\n"):gmatch("(.-)\r?\n") do
    local d, rest = line:match("^%s*%-%-%s*#(%a+)%s*(.-)%s*$")
    if d == "if" then local p = active(); local c = cond(rest); table.insert(stack, {on = c, taken = c, parent = p}); out[#out+1] = ""
    elseif d == "elseif" then local s = stack[#stack]; if s.taken then s.on = false else s.on = cond(rest); s.taken = s.on end; out[#out+1] = ""
    elseif d == "else" then local s = stack[#stack]; s.on = not s.taken; s.taken = true; out[#out+1] = ""
    elseif d == "endif" then table.remove(stack); out[#out+1] = ""
    else out[#out+1] = active() and line or "" end
  end
  return table.concat(out, "\n")
end
QNAME, NNAME = {}, {}
local function run(path)
  local f = assert(io.open(path, "rb")); local src = f:read("*a"); f:close()
  src = src:gsub("^\239\187\191", "")
  for line in src:gmatch("[^\n]+") do
    local qid, qn = line:match("q%((%d+)%s*,.-%-%-%s*(.-)%s*$")
    if qid and qn ~= "" and not QNAME[tonumber(qid)] then QNAME[tonumber(qid)] = qn end
    local nid, nn = line:match("qgs?%s*=%s*{?%s*(%d+)%s*,?%s*}?,?%s*%-%-%s*(.-)%s*$")
    if nid and nn ~= "" and not NNAME[tonumber(nid)] then NNAME[tonumber(nid)] = nn end
  end
  CurrentSubFileName = path
  local chunk, err = loadstring(preprocess(src), "@" .. path)
  if not chunk then chunk, err = loadstring((preprocess(src):gsub("%[%[", "[==[", 0)), "@" .. path) end
  if not chunk then io.stderr:write("PARSE " .. err .. "\n"); return false end
  local ok, e = pcall(chunk)
  if not ok then if not QUIET then io.stderr:write("RUN " .. path .. ": " .. tostring(e) .. "\n") end; return false end
  return true
end
local function files(dir)
  local p = io.popen('find "' .. dir .. '" -name "*.lua" | LC_ALL=C sort')
  local t = {}
  for l in p:lines() do t[#t + 1] = l end
  p:close()
  return t
end
_G.__run, _G.__files, _G.__BASE = run, files, BASE
run(BASE .. "/shared/.main.lua")
MISSING = {}
setmetatable(_G, {__index = function(t, k) if k ~= "CurrentSubFileName" then MISSING[k] = (MISSING[k] or 0) + 1 end end})
print = function() end
local pending = {}
for _, sub in ipairs({"constants", "functions", "lib", "modules", "objects"}) do
  for _, f in ipairs(files(BASE .. "/shared/" .. sub)) do
    if not f:find("/unused/") then pending[#pending + 1] = f end
  end
end
for pass = 1, 8 do
  local left = {}
  QUIET = pass < 8
  for _, f in ipairs(pending) do if not run(f) then left[#left + 1] = f end end
  io.stderr:write("shared pass " .. pass .. ": " .. #left .. " left\n")
  if #left == 0 or #left == #pending then pending = left; break end
  pending = left
end
for _, d in ipairs({"constants", "structures", "exports"}) do for _, f in ipairs(files(BASE .. "/forever/.config/" .. d)) do run(f) end end
local nok, nfail = 0, 0
for _, f in ipairs(files(BASE .. "/forever")) do
  if not f:find("/%.config/") and not f:find("00 %- Missing DB") then
    if run(f) then nok = nok + 1 else nfail = nfail + 1 end
  end
end
io.stderr:write(string.format("data files ok %d, failed %d\n", nok, nfail))
-- Walk the roots: collect every quest with inherited map / instance context.
local quests, count = {}, 0
local function walk(node, ctx, depth)
  if type(node) ~= "table" or depth > 60 then return end
  if __visit then __visit(node) end -- genpets.lua
  local c = ctx
  if node.mapID or node.instanceID or node.maps or node.headerID or node.npcID then
    c = {}
    for k, v in pairs(ctx) do c[k] = v end
    if node.mapID then c.map = node.mapID end
    if node.instanceID then c.inst = node.instanceID end
    if node.maps and not node.questID then c.maps = node.maps end
  end
  -- Holiday content (ROOTS.Holidays, or a node with an event): seasonal NPCs
  -- stand there only during the event.
  -- holiday = the event ID (EVENTS.*, the same IDs as the game calendar), or
  -- -1 when the node is under ROOTS.Holidays without an event.
  local ev = tonumber(rawget(node, "e"))
  if ev or (ctx.root and ROOTS and ctx.root == tostring(ROOTS.Holidays) and not c.holiday) then
    if c == ctx then c = {}; for k, v in pairs(ctx) do c[k] = v end end
    c.holiday = ev or c.holiday or -1
  end
  if rawget(node, "questID") then
    count = count + 1
    local id = node.questID
    local prev = quests[id]
    if not prev or (not prev.coord and (node.coord or node.coords)) then
      quests[id] = {node = node, ctx = c, holiday = c.holiday or (prev and prev.holiday)}
    elseif c.holiday and not prev.holiday then
      prev.holiday = c.holiday
    end
  end
  local g = rawget(node, "groups") or rawget(node, "g")
  if type(g) == "table" then for _, ch in ipairs(g) do walk(ch, c, depth + 1) end end
  for i = 1, #node do if type(node[i]) == "table" then walk(node[i], c, depth + 1) end end
end
for k, v in pairs(AllTheThings) do
  if type(v) == "table" then walk(v, {root = tostring(k)}, 0) end
end
_G.__quests = quests
io.stderr:write("quest objects " .. count .. "\n")
local ms = {} for k, v in pairs(MISSING) do ms[#ms+1] = k .. "=" .. v end table.sort(ms) io.stderr:write("MISSING " .. table.concat(ms, " ") .. "\n")
