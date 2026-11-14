local dir = arg[1]
arg = {[0] = arg[0], dir}
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
local Q = PSS.Quests
local pass, fail = 0, 0
local function ok(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. msg) end
end
local function keys(list) local t = {} for _, r in ipairs(list) do t[r.e and r.e.key or r.key] = r.status or true end return t end
local function reset()
  PetSkillScoutDB = {language = "en"}
  PSS:InitializeDB()
  MOCK.done, MOCK.inlog, MOCK.owned, MOCK.prints, MOCK.warnings, MOCK.equipped = {}, {}, {}, {}, {}, {}
  MOCK.level, MOCK.faction, MOCK.class, MOCK.combat = 30, "Alliance", "HUNTER", false
end

-- Data sanity -----------------------------------------------------------------
reset()
local seenKeys = {}
for _, e in ipairs(PSS.QuestData) do
  ok(not seenKeys[e.key], "unique key " .. e.key); seenKeys[e.key] = true
  ok(type(Q:MinLevel(e)) == "number" and Q:MinLevel(e) >= 1 and Q:MinLevel(e) <= 60, "lvl " .. e.key)
  ok(e.kind == "ranged" or e.kind == "quiver", "kind " .. e.key)
  ok(Q:Info(e).side == nil or Q:Info(e).side == "A" or Q:Info(e).side == "H", "side " .. e.key)
  if not e.unconfirmed then ok(PSS.QuestDB[Q:Primary(e)] ~= nil, "in QuestDB " .. e.key) end
  ok(type(e.zone) == "string" and type(e.name) == "string", "zone/name " .. e.key)
  ok(#e.items > 0, "items " .. e.key)
  for _, id in ipairs(e.items) do ok(e.inames and e.inames[id], "iname " .. e.key .. " " .. id) end
  ok(#(e.quests or {}) > 0 or e.forever == "new", "quest ids or learnable " .. e.key)
  if e.tag == "dungeon" or e.tag == "raid" then ok(e.inst, "inst " .. e.key) end
  if e.note then ok(PSS.Locale.en[e.note], "note key " .. e.key) end
  ok(Q:ZoneMapID(e) ~= nil, "zone map known " .. e.key)
end

-- Faction filter --------------------------------------------------------------
local ka = {}
for _, e in ipairs(Q:List()) do ka[e.key] = true end
ok(ka.daryl and ka.kraul and ka.library and not ka.skorn and ka.nesingwary, "alliance list")
MOCK.faction = "Horde"
local kh = {}
for _, e in ipairs(Q:List()) do kh[e.key] = true end
ok(kh.skorn and kh.kraul and kh.library and not kh.daryl and kh.nesingwary, "horde list")
local prev = 0
for _, e in ipairs(Q:List()) do ok(e.lvl >= prev, "sorted by level"); prev = e.lvl end

-- Status --------------------------------------------------------------------
reset()
local e = Q:Get("kraul")
ok(Q:Primary(e) == 1101, "alliance kraul quest")
ok(Q:Status(e, 30) == "ready", "kraul ready at 30 (unknown stats)")
ok(Q:Status(e, 27) == "soon", "kraul soon at 27")
ok(Q:Status(e, 20) == "later", "kraul later at 20")
MOCK.done[1101] = true
ok(Q:Status(e, 30) == "done", "kraul done by flag")
reset()
MOCK.owned[18714] = 1
ok(Q:Status(Q:Get("lamina"), 60) == "done", "lamina done by owned item")
MOCK.inlog[208] = 4
ok(Q:Status(Q:Get("nesingwary"), 41) == "active", "nesingwary active from log")
-- Maraudon: either version counts.
MOCK.done[7065] = true
ok(Q:IsDone(Q:Get("maraudon")), "maraudon alt final")

-- Gain / outgrown -------------------------------------------------------------
reset()
MOCK.level = 45
local nes = Q:Get("nesingwary")
local gain, best, known = Q:Gain(nes)
ok(known and gain > 0 and (best == 17686 or best == 17687), "gain with empty ranged slot")
-- Equip a much better gun (Sandstrider's Mark, in GearData) -> outgrown.
MOCK.equipped[18] = "|cff0070dd|Hitem:20646::::::::60:::|h[Sandstrider's Mark]|h|r"
gain, best, known = Q:Gain(nes)
ok(known and gain <= 0, "no gain vs better weapon (" .. tostring(gain) .. ")")
ok(Q:Status(nes, 45) == "outgrown", "outgrown status")
ok(not Q:Worth(nes, 45), "no reminder when outgrown")
-- Quivers have no score.
local g2, _, k2 = Q:Gain(Q:Get("vyrin"))
ok(g2 == nil and not k2, "quiver no gain")

-- Reminders -------------------------------------------------------------------
reset()
MOCK.level = 17
local fresh = Q:Check("level", 17)
local fk = keys(fresh)
ok(fk.vyrin and fk.sleeper and fk.daryl, "level 17 alliance reminders")
ok(not fk.kraul and not fk.skorn and not fk.nightWatch, "no higher-level / other faction reminders")
ok(#MOCK.prints >= 3, "printed lines")
ok(#MOCK.warnings == 1, "screen message on level up")
ok(MOCK.prints[1]:find("Hunter quest available") ~= nil, "alert text: " .. tostring(MOCK.prints[1]))
local again = Q:Check("level", 15)
ok(#again == 0, "no repeats")
-- Hidden entries and the option.
reset()
Q:SetHidden(Q:Get("vyrin"), true)
local fk2 = keys(Q:Check("level", 17))
ok(not fk2.vyrin and fk2.sleeper, "hidden not reminded")
reset()
PetSkillScoutDB.questAlert = false
ok(#Q:Check("level", 17) == 0, "option off")
reset()
MOCK.class = "WARRIOR"
ok(#Q:Check("level", 17) == 0, "not a hunter")
-- Login: one summary line.
reset()
MOCK.level = 18
MOCK.prints = {}
local f3 = Q:Check("login", 18)
ok(#f3 >= 2 and #MOCK.prints == 1 and MOCK.prints[1]:find("/pss quests"), "login summary")
ok(#MOCK.warnings == 0, "no screen message at login")
-- Long outgrown chains (unknown stats) are not announced at a high level.
reset()
MOCK.level = 50
MOCK.equipped[18] = "|cff0070dd|Hitem:20646::::::::60:::|h[Sandstrider's Mark]|h|r"
local fk4 = keys(Q:Check("login", 50))
ok(not fk4.daryl and not fk4.vyrin and not fk4.nightWatch, "old chains silent at 50")

-- Events: level up through the event frame, learning a new quest ID.
reset()
MOCK.level = 25
MOCK.Fire("PLAYER_LEVEL_UP", 25)
MOCK.RunTimers()
ok(PetSkillScoutDB.questNotified and PetSkillScoutDB.questNotified.ormer, "level-up event reminder")
reset()
MOCK.done[82208] = true
ok(Q:Status(Q:Get("library"), 30) == "done", "library done by quest 82208")
-- Library bow: usable from 40.
reset()
ok(Q:Get("library").req == 40, "library req")

-- Titles and names ------------------------------------------------------------
reset()
MOCK.titles[257] = "Die Prahlerei eines Jägers"
ok(Q:Title(Q:Get("daryl")) == "Die Prahlerei eines Jägers", "localized title from client")
MOCK.titles[257] = nil
ok(Q:Title(Q:Get("daryl")) == "A Hunter's Boast", "fallback title")
ok(Q:ItemName(Q:Get("kraul"), 274084) == "Quilboar Blaster", "fallback item name")
MOCK.items[274084] = {name = "Кабанячий бластер", q = 3}
ok(Q:ItemName(Q:Get("kraul"), 274084) == "Кабанячий бластер", "client item name")
local t = Q:Target(Q:Get("library"))
ok(t and t.mapID == 1453 and t.points[1][1] == 49, "library arrow (alliance giver, percent)")
MOCK.faction = "Horde"
t = Q:Target(Q:Get("library"))
ok(t and t.mapID == 1458 and t.points[1][1] == 74, "library arrow (horde giver)")
MOCK.faction = "Alliance"
t = Q:Target(Q:Get("daryl"))
ok(t and t.mapID == 1432 and t.points[1][1] == 83.4 and t.name == "Daryl the Youngling", "arrow from QuestDB")

-- UI ------------------------------------------------------------------------------
reset()
MOCK.level = 30
local UI = PSS.UI
UI:Create()
UI:Open("quests")
ok(UI.view == "quests", "view opened")
ok(UI.views.quests and UI.qRows and #UI.qRows == 9, "quest rows built")
local shown = 0
for _, r in ipairs(UI.qRows) do if r.data then shown = shown + 1 end end
ok(shown > 0, "rows filled (" .. shown .. ")")
ok(UI.qRows[1].name:GetText() ~= "", "row name")
ok(UI.qSummary:GetText():find("Available now") ~= nil, "summary " .. UI.qSummary:GetText())
-- Every filter renders.
for _, b in ipairs(UI.qFilters) do b.scripts.OnClick(b) end
ok(UI.questState.filter == "done", "filter switch")
UI.questState.filter = "all"; UI:UpdateQuests()
local all = 0
for _, r in ipairs(UI.qRows) do if r.data then all = all + 1 end end
ok(all == 9, "all filter fills rows")
-- Tooltip and buttons.
UI.qRows[1].scripts.OnEnter(UI.qRows[1])
ok(#GameTooltip.lines > 3, "row tooltip lines " .. #GameTooltip.lines)
local hideBtn = UI.qRows[1].hide
local key = UI.qRows[1].data.e.key
hideBtn.scripts.OnClick(hideBtn)
ok(PetSkillScoutDB.questHidden[key], "hide button")
MOCK.combat = true
MOCK.prints = {}
UI:OpenQuestMap(Q:Get("daryl"))
ok(MOCK.prints[1] and MOCK.prints[1]:find("combat"), "no map in combat")
-- Header: tabs fit in every language.
for _, lang in ipairs({"en", "uk", "pl", "de", "fr", "it", "es", "pt", "ru"}) do
  PetSkillScoutDB.language = lang
  UI:RefreshHeader()
  local last = UI.tabs[#UI.tabs]
  local x = last.points[1][4] + last.w
  ok(x <= 840, "tabs fit in " .. lang .. " (" .. math.floor(x) .. ")")
  print(lang, math.floor(x), UI.tabs[1].fs.fontSize); ok(UI.tabs[7].text == PSS.Locale[lang].tabQuests, "quests tab label " .. lang)
end
PetSkillScoutDB.language = "uk"
UI:UpdateQuests()
ok(UI.qSummary:GetText():find("Доступно") ~= nil, "uk summary")
-- Slash command.
UI:ShowView("beasts")
SlashCmdList.PETSKILLSCOUT("quests")
ok(UI.view == "quests", "/pss quests")

-- Locale: every key in all 7 languages, same format specifiers.
local en = PSS.Locale.en
local nkeys = 0
local src = io.open(dir .. "/Locale6.lua"):read("*a")
for k in src:gmatch("\n    ([%w_]+) = ") do end
for _, lang in ipairs({"uk", "pl", "de", "fr", "it", "es", "pt", "ru"}) do
  for k in pairs(en) do
    if k:match("^q") or k == "tabQuests" or k:match("^optQuest") then
      local v = PSS.Locale[lang][k]
      ok(v ~= nil, lang .. " has " .. k)
      if v and type(en[k]) == "string" then
        local a = select(2, en[k]:gsub("%%%a", "")); local b = select(2, v:gsub("%%%a", ""))
        ok(a == b, lang .. " format " .. k)
      end
      nkeys = nkeys + 1
    end
  end
end
ok(nkeys > 40, "locale keys checked " .. nkeys)

-- Chain start: Big Game Hunter (208) points to Welcome to the Jungle (583).
reset()
MOCK.level = 30
ok(Q:FirstStep(208) == 583, "first step of Big Game Hunter (" .. tostring(Q:FirstStep(208)) .. ")")
local tg = Q:Target(Q:Get("nesingwary"))
ok(tg and tg.quest == 583 and tg.mapID == 1434, "arrow to the chain start")

print(string.format("passed %d, failed %d", pass, fail))
os.exit(fail == 0 and 0 or 1)
