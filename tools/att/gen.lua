-- Build PetSkillScout/QuestDB.lua from ATT's Forever database (MIT).
dofile("driver.lua")
local out = arg[2]
local Q = __quests
local function removed(tl)
  if type(tl) ~= "table" then return false end
  local last = tl[#tl]
  return type(last) == "string" and (last:find("^removed") or last:find("^deleted")) ~= nil
end
local ALLY, HORDE = {}, {}
for _, r in ipairs(ALLIANCE_ONLY or {}) do ALLY[r] = true end
for _, r in ipairs(HORDE_ONLY or {}) do HORDE[r] = true end
local function side(races)
  if type(races) ~= "table" or #races == 0 then return nil end
  local a, h = 0, 0
  for _, r in ipairs(races) do if ALLY[r] then a = a + 1 elseif HORDE[r] then h = h + 1 end end
  if h == 0 and a > 0 then return "A" end
  if a == 0 and h > 0 then return "H" end
  return nil
end
local function list(v)
  if v == nil then return nil end
  if type(v) == "table" then return v end
  return {v}
end
local function num(v) return string.format("%g", v) end
local function arr(t)
  local s = {}
  for _, v in ipairs(t) do s[#s + 1] = type(v) == "number" and num(v) or string.format("%q", tostring(v)) end
  return "{" .. table.concat(s, ",") .. "}"
end
local ids = {}
for id in pairs(Q) do ids[#ids + 1] = id end
table.sort(ids)
local lines, npcs, used, stats = {}, {}, {}, {kept = 0, removed = 0, unobt = 0, pins = 0}
for _, id in ipairs(ids) do
  local n, ctx = Q[id].node, Q[id].ctx
  if n.u then stats.unobt = stats.unobt + 1
  elseif removed(n.timeline) then stats.removed = stats.removed + 1
  else
    local f = {}
    local g = n.qg or (type(n.qgs) == "table" and n.qgs[1])
    if g then f[#f + 1] = "g=" .. g; used[g] = true end
    local c = n.coord or (type(n.coords) == "table" and n.coords[1])
    if type(c) == "table" and type(c[1]) == "table" then c = c[1] end
    if type(c) == "table" and (type(c[1]) ~= "number" or type(c[2]) ~= "number" or type(c[3]) ~= "number") then c = nil end
    if type(c) == "table" and c[3] then f[#f + 1] = string.format("x=%s,y=%s,m=%d", num(c[1]), num(c[2]), c[3]); stats.pins = stats.pins + 1 end
    local lvl = n.lvl
    if type(lvl) == "table" then lvl = lvl[1] end
    if type(lvl) == "number" then f[#f + 1] = "l=" .. lvl end
    local sd = side(n.races)
    if sd then f[#f + 1] = 's="' .. sd .. '"'
    elseif type(n.races) == "table" and #n.races > 0 and #n.races < 12 then f[#f + 1] = "rc=" .. arr(n.races) end
    if type(n.classes) == "table" and #n.classes > 0 then f[#f + 1] = "cl=" .. arr(n.classes) end
    local pre = list(n.sourceQuests or n.sourceQuest)
    if pre then local t = {} for _, v in ipairs(pre) do if type(v) == "number" then t[#t + 1] = v end end pre = t end
    if pre and #pre > 0 then f[#f + 1] = "p=" .. arr(pre) end
    if tonumber(n.sourceQuestNumRequired) then f[#f + 1] = "pn=" .. n.sourceQuestNumRequired end
    local alt = list(n.altQuests)
    if alt then local t = {} for _, v in ipairs(alt) do if type(v) == "number" then t[#t + 1] = v end end alt = t end
    if alt and #alt > 0 then f[#f + 1] = "a=" .. arr(alt) end
    if n.isBreadcrumb then f[#f + 1] = "b=1" end
    if n.repeatable then f[#f + 1] = "r=1" end
    if tonumber(n.requireSkill) then f[#f + 1] = "sk=" .. tonumber(n.requireSkill) end
    if n.minReputation then f[#f + 1] = "mr=1" end
    if ctx.inst or ctx.root == "Instances" then f[#f + 1] = "d=1" end
    -- Objectives (n kill, i item, o object, other) and the first objective position; rewards.
    local obj, ox, items = {}, nil, {}
    for _, ch in ipairs(rawget(n, "groups") or {}) do
      if type(ch) == "table" then
        if ch.objectiveID then
          local pv = ch.provider or (type(ch.providers) == "table" and ch.providers[1])
          local t = (type(pv) == "table" and pv[1]) or ((ch.cr or ch.crs) and "n") or "x"
          obj[#obj + 1] = (t == "n" or t == "i" or t == "o") and t or "x"
          local oc = ch.coord or (type(ch.coords) == "table" and ch.coords[1])
          if type(oc) == "table" and type(oc[1]) == "table" then oc = oc[1] end
          if type(oc) == "table" and (type(oc[1]) ~= "number" or type(oc[2]) ~= "number" or type(oc[3]) ~= "number") then oc = nil end
          if not ox and type(oc) == "table" and oc[3] then ox = oc end
        elseif ch.itemID and not removed(ch.timeline) and not ch.u then
          if type(ch.itemID) == "number" then items[#items + 1] = ch.itemID end
        end
      end
    end
    if #obj > 0 then f[#f + 1] = 'o="' .. table.concat(obj) .. '"' end
    if ox then f[#f + 1] = string.format("ox=%s,oy=%s,om=%d", num(ox[1]), num(ox[2]), ox[3]) end
    if #items > 0 then f[#f + 1] = "i=" .. arr(items) end
    if QNAME[id] then f[#f + 1] = "n=" .. string.format("%q", QNAME[id]) end
    lines[#lines + 1] = string.format("[%d]={%s},", id, table.concat(f, ","))
    stats.kept = stats.kept + 1
  end
end
local nids = {}
for g in pairs(used) do if NNAME[g] then nids[#nids + 1] = g end end
table.sort(nids)
local fh = assert(io.open(out, "w"))
fh:write("-- Quests of WoW Forever (generated, do not edit by hand).\n")
fh:write("-- Data: AllTheThings by the ATT team (https://github.com/ATTWoWAddon/AllTheThings),\n")
fh:write("-- Forever database, MIT licence - the licence text is in QuestDB-LICENSE.txt.\n")
fh:write("-- Source commit " .. (arg[3] or "?") .. ". Fields: g quest giver NPC, x/y/m giver position (0-100, uiMapID),\n")
fh:write("-- l minimum level, s faction, rc races, cl classes, p previous quests (pn: how many of them),\n")
fh:write("-- a alternative quests, b breadcrumb, r repeatable, sk profession, mr reputation, d dungeon / raid,\n")
fh:write("-- o objectives (n kill, i item, o object, x other), ox/oy/om first objective position, i rewards, n name.\n")
fh:write("local PSS = PetSkillScout\nPSS.QuestDB = {\n")
fh:write(table.concat(lines, "\n"))
fh:write("\n}\nPSS.QuestNPC = {\n")
for _, g in ipairs(nids) do fh:write(string.format("[%d]=%q,\n", g, NNAME[g])) end
fh:write("}\n")
-- Reward items: name, quality, item level, required level, equip slot type (ATT ItemDB export).
local IDB = (AllTheThings and AllTheThings.ItemDB) or {}
local need = {}
for _, l in ipairs(lines) do
  local is = l:match(",i=(%b{})")
  if is then for v in is:gmatch("%d+") do need[tonumber(v)] = true end end
end
for _, v in ipairs({18713, 7064}) do need[v] = nil end
local iids = {}
for v in pairs(need) do if IDB[v] then iids[#iids + 1] = v end end
table.sort(iids)
fh:write("PSS.QuestItems = {\n")
for _, v in ipairs(iids) do
  local it = IDB[v]
  local f = {string.format("n=%q", it.name or "?")}
  if it.q then f[#f + 1] = "q=" .. it.q end
  if it.iLvl then f[#f + 1] = "il=" .. it.iLvl end
  if it.lvl then f[#f + 1] = "lv=" .. it.lvl end
  if it.equippable and it.inventoryType then f[#f + 1] = "inv=" .. it.inventoryType end
  if it.class then f[#f + 1] = "c=" .. it.class .. ",sc=" .. (it.subclass or 0) end
  if type(it.classes) == "table" then f[#f + 1] = "cl=" .. arr(it.classes) end
  fh:write(string.format("[%d]={%s},\n", v, table.concat(f, ",")))
end
fh:write("}\n")
fh:close()
io.stderr:write("reward items " .. #iids .. "\n")
io.stderr:write(string.format("quests kept %d (removed %d, unobtainable %d), with giver position %d, npc names %d\n",
  stats.kept, stats.removed, stats.unobt, stats.pins, #nids))
