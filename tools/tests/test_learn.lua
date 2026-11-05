-- Quests learned in game: recording at the NPC, network merge, confirmation, gear lookup.
local dir = arg[1]
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
PetSkillScoutDB = {language = "en"}; PSS:InitializeDB()
local QL = PSS.QuestLearn
local pass, fail = 0, 0
local function ok(c, m) if c then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. m) end end
PSS.player = PSS.player or {}
PSS.player.faction = "Alliance"

-- A quest window at an NPC for a quest the database does not know.
local sent = {}
PSS.Sync.SendAll = function(_, msg) sent[#sent + 1] = msg; return true end
local oldGUID, oldName = UnitGUID, UnitName
UnitGUID = function(u) if u == "npc" then return "Creature-0-1-2-3-4242-0000" end end
UnitName = function(u) if u == "npc" then return "Gurf" end return "Tester" end
GetQuestID = function() return 990001 end
GetTitleText = function() return "Gurf's Dignity" end
GetNumQuestChoices = function() return 2 end
GetNumQuestRewards = function() return 0 end
GetQuestItemLink = function(kind, i) return "|cff1eff00|Hitem:" .. (12000 + i) .. "::|h[x]|h|r" end
local oldPos = PSS.Nav.PlayerPos
PSS.Nav.PlayerPos = function() return 1438, 0.556, 0.412 end
ok(PSS.QuestDB[990001] == nil, "test quest is unknown to the database")
MOCK.Fire("QUEST_DETAIL")
local rec = QL:Records()[990001]
ok(rec ~= nil, "unknown quest recorded at the NPC")
ok(rec and rec.g == 4242 and rec.gn == "Gurf", "quest giver NPC and name")
ok(rec and rec.r.Tester and rec.r.Tester.m == 1438 and math.abs(rec.r.Tester.x - 55.6) < 0.01, "position in map percent")
ok(rec and #rec.i == 2 and rec.i[1] == 12001, "reward items")
ok(rec and QL:Confirmed(rec), "own sighting counts as confirmed")
ok(#sent == 1 and sent[1]:find("^O~990001~4242~1438~55.6~41.2~A~12001,12002~Gurf's Dignity") ~= nil, "shared on the network: " .. tostring(sent[1]))

-- A quest the database knows with its giver and rewards is not recorded.
local knownID
for id, r in pairs(PSS.QuestDB) do if r.m and r.x and not r.i then knownID = id; break end end
GetQuestID = function() return knownID end
GetNumQuestChoices = function() return 0 end
MOCK.Fire("QUEST_DETAIL")
ok(QL:Records()[knownID] == nil, "known quest not recorded")
-- ... but a new reward on it is.
GetNumQuestChoices = function() return 1 end
MOCK.Fire("QUEST_COMPLETE")
ok(QL:Records()[knownID] ~= nil and QL:Records()[knownID].i[1] == 12001, "new reward on a known quest recorded")

-- Network: one report is not confirmed, two reports of the same spot are.
PSS.Sync:Receive("O~990002~77~1438~20~30~A~555~Alien Predators", "CHANNEL", "Bob-Realm")
local r2 = QL:Records()[990002]
ok(r2 and not QL:Confirmed(r2), "one network report is not confirmed")
PSS.Sync:Receive("O~990002~77~1438~21~31~A~555~Alien Predators", "CHANNEL", "Ann-Realm")
ok(QL:Confirmed(r2), "two players at the same spot confirm it")
PSS.Sync:Receive("O~990002~77~1438~80~80~A~~Alien Predators", "CHANNEL", "Eve-Realm")
local p, n = QL:Best(r2)
ok(p and p.x < 30 and n == 2, "a far-off report does not move the agreed spot")
PSS.Sync:Receive("O~990003~77~1438~250~-5~A~~Bad", "CHANNEL", "Bob-Realm")
ok(QL:Records()[990003] and next(QL:Records()[990003].r) == nil, "invalid coordinates are dropped")

-- Gear tab finds learned quests by their title (your faction only).
local G = PSS.Gear
local id, lr = G:QuestFor({src = {{t = "q", n = "Gurf's Dignity"}}})
ok(id == 990001 and lr.learned and lr.m == 1438 and lr.confirmed, "gear: learned quest giver for a quest reward")
local id2, lr2 = G:QuestFor({src = {{t = "q", n = "Alien Predators"}}})
ok(id2 == 990002 and lr2.reporters == 2, "gear: network quest with 2 reporters")
PSS.Sync:Receive("O~990004~78~1411~50~50~H~~Horde Only Thing", "CHANNEL", "Orc-Realm")
ok(G:QuestFor({src = {{t = "q", n = "Horde Only Thing"}}}) == nil, "other faction's learned quest is not offered")

-- Messages stay short and the separator cannot break them.
local m = QL:Message(1, {n = string.rep("x~", 200), i = {}, r = {}})
ok(#m <= 250 and select(2, m:gsub("~", "")) == 8, "message size and separators")

-- Switched off: nothing is recorded.
PetSkillScoutDB.questLearn = false
GetQuestID = function() return 990005 end
MOCK.Fire("QUEST_DETAIL")
ok(QL:Records()[990005] == nil, "off: nothing recorded")
PetSkillScoutDB.questLearn = nil

-- A login request is answered with what we know (after a short random delay).
sent = {}
PSS.Sync:Receive("P", "CHANNEL", "New-Realm")
MOCK.RunTimers()
ok(#sent >= 2, "pull answered with records: " .. #sent)

-- Network tab: online list, live feed, filters, counters.
local F = PSS.NetFeed
F.events = {}
local recv0 = F:Stats().recv or 0
PSS.Sync:Receive("H~2.7.1~120~10~3~5~Guild", "CHANNEL", "Mira-Realm")
local rare = PSS.RarePets.entries and PSS.RarePets.entries[1]
if not rare then PSS.RarePets:Build(); rare = PSS.RarePets.entries[1] end
PSS.Sync:Receive("S~" .. tostring(rare.npcID or 0) .. "~" .. tostring(rare.id) .. "~1429~40~50", "CHANNEL", "Mira-Realm")
PSS.Sync:Receive("O~990010~88~1438~10~10~A~~Lost Necklace", "CHANNEL", "Mira-Realm")
ok(#F.events == 3, "feed got join, rare and quest: " .. #F.events)
ok(F.events[1].kind == "quest" and F.events[1].a == "Lost Necklace", "newest first")
ok(#F:List("quest", true) == 1 and #F:List("rare", true) == 1 and #F:List("hunter", true) == 1, "filters")
ok((F:Stats().recv or 0) - recv0 == 3, "received counter")
local online = F:Online()
local seenMira = false
for _, h in ipairs(online) do if h.name == "Mira" and h.v == "2.7.1" then seenMira = true end end
ok(seenMira, "Mira is online with her version")
-- Own quest records count as sent and show as mine.
local sent0 = F:Stats().sent or 0
PSS.Sync.SendAll = nil  -- back to the real one (no channels in tests: nothing sent)
GetQuestID = function() return 990011 end
GetTitleText = function() return "Mine Quest" end
F:OnSent("O~990011~4242~1438~5~5~A~~Mine Quest")
ok((F:Stats().sent or 0) == sent0 + 1 and F.events[1].mine, "own record counted and marked as mine")
ok(#F:List("quest", false) == 1, "hide my own events")
-- The tab draws without errors.
local UI = PSS.UI
UI:Create()
local okDraw, err = pcall(UI.ShowView, UI, "network")
ok(okDraw, "network tab draws: " .. tostring(err))
ok(UI.netFeedRows[1].text:GetText():find("Mine Quest") ~= nil, "feed row text: " .. tostring(UI.netFeedRows[1].text:GetText()))
UnitGUID, UnitName, PSS.Nav.PlayerPos = oldGUID, oldName, oldPos

-- 3.0.0: relay between realms (vendors, rare spots) - answered with quests on "P".
do
  local RL = PSS.Relay
  local got = {}
  PSS.Sync.SendAll = function(_, msg) got[#got + 1] = msg; return true end
  PetSkillScoutDB.ammoVendors = {[3589] = {n = "Keina", m = 1438, x = 59.3, y = 41.1, k = "a"}}
  PetSkillScoutDB.rareSeen = {Nightscreech = {mapID = 1438, x = 51.4, y = 50.1, n = 1}}
  local n = RL:Answer(true)
  local v, x = false, false
  for _, m in ipairs(got) do
    if m:find("^V~3589~1438~59.3~41.1~a~Keina") then v = true end
    if m:find("^X~0~Nightscreech~1438~51.4~50.1") then x = true end
  end
  ok(n >= 2 and v and x, "relay answer has vendors and rare spots: " .. table.concat(got, " | "))
  -- Receiving a spot from another realm's hunter.
  PSS.Sync.handlers.X({"X", "1234", "Ghostfang", "1440", "40.0", "60.0", "3"}, "Mira Stone")
  local spots = PetSkillScoutDB.rareSpots.Ghostfang
  ok(spots and #spots == 1 and spots[1].x == 40 and spots.npc == 1234, "relayed rare spot stored")
  PSS.Sync.handlers.X({"X", "1234", "Ghostfang", "1440", "41.0", "60.5", "1"}, "Ole Brand")
  ok(#spots == 1 and spots[1].c, "same spot from a second hunter is confirmed, not duplicated")
  PSS.Sync.handlers.X({"X", "1234", "Ghostfang", "1440", "140", "60", "1"}, "Ole Brand")
  ok(#spots == 1, "bad coordinates ignored")
  -- Oldest first: a second answer sends other records before repeating.
  for i = 1, 20 do RL:AddSpot("R" .. i, 1, 1438, i, i, 1, "x") end
  got = {}; RL:Answer(true)
  local first = {}; for _, m in ipairs(got) do first[m] = true end
  got = {}; RL:Answer(true)
  local repeated = 0; for _, m in ipairs(got) do if first[m] and m:find("^X") then repeated = repeated + 1 end end
  ok(repeated < 15, "relay rotates records between answers (repeated " .. repeated .. ")")
  -- "P" is answered by both quests and relay.
  got = {}
  local QLp = PSS.Sync.handlers.P
  ok(type(QLp) == "function", "P handler chained")
  PetSkillScoutDB.relay = false
  ok(RL:Answer(true) == 0, "relay can be switched off")
  PetSkillScoutDB.relay = nil
  PSS.Sync.SendAll = nil
end

-- 3.0.1: built-in learned data is merged once and counts as confirmed.
do
  local RL, QL = PSS.Relay, PSS.QuestLearn
  PSS.LearnedData = {quests = {[990777] = {n = "Lost Bow", g = 5, f = "A", m = 1438, x = 10, y = 20, i = {123}}},
    vendors = {[777] = {n = "Ammo Joe", m = 1438, x = 30, y = 40, k = "ab"}},
    rares = {Snarl = {npc = 99, {m = 1438, x = 50, y = 50}}}}
  PetSkillScoutDB.learnedSeed = nil
  local n = RL:Seed()
  ok(n == 3, "seeded quest, vendor and rare spot: " .. n)
  ok(QL:Confirmed(QL:Records()[990777]), "built-in quest counts as confirmed")
  ok(PetSkillScoutDB.ammoVendors[777] and PetSkillScoutDB.ammoVendors[777].from == "data", "built-in vendor")
  ok(PetSkillScoutDB.rareSpots.Snarl[1].c, "built-in rare spot confirmed")
  ok(RL:Seed() == 0, "seeded only once per version")
  PSS.LearnedData = nil
end
print("passed " .. pass .. ", failed " .. fail)
os.exit(fail == 0 and 0 or 1)
