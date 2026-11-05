local dir = arg[1]
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
local W, QP, QA = PSS.QuestWorth, PSS.QuestPins, PSS.QuestAuto
local pass, fail = 0, 0
local function ok(c, m) if c then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. m) end end
-- Extra client API.
MOCK.race, MOCK.classID, MOCK.server, MOCK.logXP, MOCK.objectives, MOCK.tags = 1, 3, 100000, {}, {}, {}
function UnitRace() return "Human", "Human", MOCK.race end
function UnitClass() return "Hunter", MOCK.class, MOCK.classID end
function GetServerTime() return MOCK.server end
function GetQuestLogRewardXP(id) return MOCK.logXP[id] or 0 end
C_QuestLog.GetQuestObjectives = function(id) return MOCK.objectives[id] end
C_QuestLog.GetQuestTagInfo = function(id) return MOCK.tags[id] end
local function reset()
  PetSkillScoutDB = {language = "en"}; PSS:InitializeDB()
  MOCK.done, MOCK.inlog, MOCK.owned, MOCK.prints, MOCK.equipped = {}, {}, {}, {}, {}
  MOCK.level, MOCK.faction, MOCK.class, MOCK.classID, MOCK.race = 12, "Alliance", "HUNTER", 3, 1
  MOCK.logXP, MOCK.objectives, MOCK.tags = {}, {}, {}
  if PSS.GearCompare and PSS.GearCompare.Reset then PSS.GearCompare:Reset() end
end

-- Database ----------------------------------------------------------------------
reset()
local n = 0
for id, r in pairs(PSS.QuestDB) do
  n = n + 1
  if r.x then ok(r.x >= 0 and r.x <= 100 and r.y >= 0 and r.y <= 100 and r.m, "coords " .. id) end
  if r.s then ok(r.s == "A" or r.s == "H", "side " .. id) end
end
ok(n > 4000, "QuestDB size " .. n)
ok(PSS.QuestNPC[1187] == "Daryl the Youngling", "npc name")
ok(PSS.QuestItems[277254] and PSS.QuestItems[277254].n == "Truthseeker's Bow", "quest item names")

-- Availability ---------------------------------------------------------------------
ok(W:Available(257, 12), "A Hunter's Boast available at 12 (alliance)")
local okL, why = W:Available(257, 10)
ok(not okL and why == "level", "too low")
MOCK.faction = "Horde"
local okS, whyS = W:Available(257, 12)
ok(not okS and whyS == "side", "wrong faction")
MOCK.faction = "Alliance"
MOCK.done[257] = true
ok(select(2, W:Available(257, 12)) == "done", "done")
MOCK.done[257] = nil
MOCK.inlog[257] = 2
ok(select(2, W:Available(257, 12)) == "log", "in log")
MOCK.inlog[257] = nil
-- Prerequisites: Vyrin's Revenge (2/2) needs 271.
ok(select(2, W:Available(531, 20)) == "prev", "needs previous quest")
MOCK.done[271] = true
ok(W:Available(531, 20), "previous done")
-- Class quests: Stave of the Ancients is hunter only.
MOCK.classID = 1
ok(select(2, W:Available(7636, 60)) == "class", "class gate")

-- XP and time --------------------------------------------------------------------------
reset()
local xp, exact = W:XP(257, 12)
ok(not exact and xp > 300 and xp < 3000, "estimated xp " .. xp)
ok(W:EstimateXP(20, 30) < W:EstimateXP(20, 20) * 0.2, "grey quests give little")
MOCK.logXP[257] = 1234
xp, exact = W:XP(257, 12)
ok(exact and xp == 1234, "xp from client")
ok(PetSkillScoutDB.questXP[257] == 1234, "xp saved")
local m1 = W:Minutes(257, 12)
ok(m1 >= 5 and m1 <= 40, "estimated minutes " .. m1)
-- Dungeon quests take long.
local md = W:Minutes(1101, 30)
ok(md >= 35, "dungeon minutes " .. md)
-- Learned time: accept at t, turn in 6 minutes later.
W:OnAccepted(257); MOCK.server = MOCK.server + 360; W:OnTurnedIn(257, 1300)
local m2, learned = W:Minutes(257, 12)
ok(learned and m2 == 6, "learned minutes " .. tostring(m2))
ok(PetSkillScoutDB.questXP[257] == 1300, "turn-in xp saved")
-- Log objectives refine the estimate.
reset()
MOCK.inlog[257] = 1
MOCK.objectives[257] = {{type = "monster", numRequired = 6, numFulfilled = 0}}
local m3 = W:Minutes(257, 12)
ok(m3 < m1 + 5, "log objectives minutes " .. m3)

-- Verdicts ------------------------------------------------------------------------------
reset()
-- Hunter list quest: worth it while the reward is useful.
ok(W:Rate(257, 12).verdict == "great", "hunter quest great")
-- A grey quest far below your level is not worth it.
MOCK.level = 40
local found
for id, r in pairs(PSS.QuestDB) do
  if r.l and r.l <= 8 and not r.i and r.s ~= "H" and not r.p and not r.cl and not r.rc and not r.sk and not r.mr then found = id; break end
end
ok(found and W:Rate(found, 40).verdict == "skip", "low quest skipped at 40 (" .. tostring(found) .. ")")
-- Same quest at its own level is fine.
MOCK.level = 6
ok(W:Rate(found, 6).verdict ~= "skip", "low quest ok at its level")
-- Gear upgrade makes a quest great.
reset()
MOCK.level = 30
local orig = PSS.GearCompare.Compare
PSS.GearCompare.Compare = function() return {delta = 25, canUse = true, reqLevel = 25} end
local any
for id, r in pairs(PSS.QuestDB) do if r.i and r.l == 25 and r.s ~= "H" and not r.p then any = id; break end end
local rate = W:Rate(any, 30)
ok(rate.verdict == "great" and rate.gear == 25 and rate.gearItem, "gear upgrade great")
PSS.GearCompare.Compare = orig
ok(W:Summary(rate):find("XP") and W:Summary(rate):find("min"), "summary text " .. W:Summary(rate))

-- Map pins --------------------------------------------------------------------------------
reset()
local canvas = MOCK.newObj("Canvas"); canvas.w, canvas.h = 1000, 667
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame")
getmetatable(WorldMapFrame).m_GetCanvas = function() return canvas end
getmetatable(WorldMapFrame).m_GetMapID = function() return 1432 end
getmetatable(WorldMapFrame).m_GetCanvasScale = function() return 1 end
WorldMapFrame.shown = true
MOCK.level = 12
local groups = QP:Groups(1432, 12)
ok(#groups > 0, "Loch Modan pin groups " .. #groups)
local daryl
for _, g in ipairs(groups) do if g.npc == 1187 then daryl = g end end
ok(daryl and daryl.best == "great", "Daryl's pin is purple")
QP:Refresh(); QP.Update()
ok((QP.shown or 0) > 0, "pins drawn " .. tostring(QP.shown))
local shownAll = QP.shown
PetSkillScoutDB.questPinsSkip = true; QP:Refresh(); QP.Update()
ok(QP.shown >= shownAll, "grey pins on request")
PetSkillScoutDB.questPins = false; QP:Refresh(); QP.Update()
ok(true, "pins off ok")
-- Minimap: quest givers nearby get the same coloured "!" (Settings > Quests > on the minimap).
PetSkillScoutDB.questPins = true
local Nav, MMp = PSS.Nav, PSS.Minimap
local oldPos, oldNear = Nav.PlayerPos, Nav.Nearest
Nav.PlayerPos = function() return 1432, 0.5, 0.5 end
Nav.Nearest = function() return 20, 0, 20 end
local function minimapQuests()
  MMp:Refresh(); MMp._driver:GetScript("OnUpdate")(MMp._driver, 1)
  local n, purple = 0, false
  for _, p in ipairs(MMp._pins) do
    if p.shown and p.group then n = n + 1; if p.group.npc == 1187 then purple = p.group.best == "great" end end
  end
  return n, purple
end
local mn, mpurple = minimapQuests()
ok(mn > 0 and mpurple, "minimap quest givers " .. mn .. ", Daryl purple")
PetSkillScoutDB.questMinimap = false
ok(minimapQuests() == 0, "minimap quest givers can be switched off")
PetSkillScoutDB.questMinimap = nil
PetSkillScoutDB.questPins = false
ok(minimapQuests() == 0, "no minimap quest givers when quest markers are off")
Nav.PlayerPos, Nav.Nearest = oldPos, oldNear
-- Horde sees no Daryl.
PetSkillScoutDB.questPins = true
MOCK.faction = "Horde"
local hg = QP:Groups(1432, 12)
local hd
for _, g in ipairs(hg) do if g.npc == 1187 then hd = g end end
ok(not hd, "no alliance pins for horde")

-- Auto-accept ----------------------------------------------------------------------------
reset()
local selected, accepted = {}, 0
C_GossipInfo = {GetAvailableQuests = function() return MOCK.gossip end,
  SelectAvailableQuest = function(id) table.insert(selected, id) end}
function AcceptQuest() accepted = accepted + 1 end
function GetQuestID() return MOCK.detail end
function GetRewardXP() return MOCK.detailXP or 0 end
function QuestGetAutoAccept() return false end
MOCK.level = 40
MOCK.gossip = {{questID = found, isTrivial = true, title = "Low"}, {questID = 208, isTrivial = false, title = "Big Game Hunter"}}
MOCK.done[188], MOCK.done[193], MOCK.done[197] = true, true, true
ok(QA:OnGossip() == nil and #selected == 0, "auto off by default")
PetSkillScoutDB.questAuto = "worth"
ok(QA:OnGossip() == 208 and selected[1] == 208, "worth: picks the good quest, skips the grey one")
ok(QA:OnGossip() == nil, "no repeat within 20 s")
MOCK.detail = 208
ok(QA:OnDetail() == true and accepted == 1, "accepts in the quest window")
MOCK.detail = found
ok(not QA:OnDetail() and accepted == 1, "does not accept a not-worth quest")
PetSkillScoutDB.questAuto = "all"
ok(QA:OnDetail() == true and accepted == 2, "all: accepts everything")
IsShiftKeyDown = function() return true end
ok(not QA:OnDetail() and accepted == 2, "Shift skips")
IsShiftKeyDown = function() return false end
-- Greeting NPCs.
PetSkillScoutDB.questAuto = "worth"
local gsel
function GetNumAvailableQuests() return 2 end
-- A trivial (grey) quest the database does not know: skipped by the trivial flag,
-- independent of which low quest pairs() happened to pick above.
local greyNew = 999999
assert(PSS.QuestDB[greyNew] == nil)
function GetAvailableQuestInfo(i) if i == 1 then return true, 0, false, false, greyNew end return false, 0, false, false, 257 end
function SelectAvailableQuest(i) gsel = i end
MOCK.level = 12
QA:OnGreeting()
ok(gsel == 2, "greeting picks the worth quest")

-- Marks in the gossip list (modern ScrollBox).
reset()
MOCK.level = 40
local btns = {}
local function btn(id, title, trivial)
  local b = MOCK.newObj("Button"); b.fs = MOCK.newObj("FontString"); b.Icon = MOCK.newObj("Texture")
  b.GetElementData = function() return {buttonType = 4, info = {questID = id, title = title, isTrivial = trivial}} end
  getmetatable(b.Icon).m_SetVertexColor = function(self, r, g, bb) self.col = {r, g, bb} end
  btns[#btns + 1] = b
  return b
end
btn(found, "Low quest", true); btn(208, "Big Game Hunter", false)
GossipFrame = CreateFrame("Frame", "GossipFrame")
GossipFrame.GreetingPanel = {ScrollBox = {ForEachFrame = function(_, fn) for _, b in ipairs(btns) do fn(b) end end}}
QA:MarkGossip()
ok(btns[1].fs.text:find("not worth"), "grey mark text: " .. btns[1].fs.text)
ok(btns[2].fs.text:find("Big Game Hunter") and btns[2].fs.text:find("|cffbd73ff"), "purple title")
ok(btns[2].Icon.col and btns[2].Icon.col[3] > btns[2].Icon.col[2], "purple icon")
PetSkillScoutDB.questWorth = false
btns[1].fs.text = "Low quest"
QA:MarkGossip()
ok(btns[1].fs.text == "Low quest", "marks off")

-- UI modes ---------------------------------------------------------------------------
reset()
MOCK.level = 12
PSS.Nav.PlayerPos = function() return 1432, 0.5, 0.5 end
local UI = PSS.UI
UI:Create()
UI:Open("quests")
for _, b in ipairs(UI.qModes) do b.scripts.OnClick(b) end
ok(UI.questState.mode == "log", "mode buttons")
UI.questState.mode = "nearby"; UI:UpdateQuests()
local rows = 0
for _, r in ipairs(UI.qRows) do if r.data then rows = rows + 1 end end
ok(rows > 0, "nearby rows " .. rows)
ok(UI.qSummary:GetText():find("this zone"), "nearby summary")
UI.qRows[1].scripts.OnEnter(UI.qRows[1])
ok(#GameTooltip.lines > 3, "nearby tooltip")
C_QuestLog.GetNumQuestLogEntries = function() return 2 end
C_QuestLog.GetInfo = function(i) if i == 1 then return {isHeader = true} end return {questID = 257, title = "A Hunter's Boast"} end
UI.questState.mode = "log"; UI:UpdateQuests()
ok(UI.qRows[1].data and UI.qRows[1].data.id == 257, "log row")
ok(UI.qSummary:GetText():find("log"), "log summary")
for _, lang in ipairs({"uk", "pl", "de", "fr", "it", "es", "pt", "ru"}) do
  for k, v in pairs(PSS.Locale.en) do
    if k:match("^qw") or k:match("^qMode") or k:match("^optQuest") or k:match("^qAuto") or k == "setQuests" or k == "setQuestsSub" or k == "qUnconfirmed" then
      local t = PSS.Locale[lang][k]
      ok(t ~= nil, lang .. " " .. k)
      if t then ok(select(2, v:gsub("%%[%a.%d]+", "")) == select(2, t:gsub("%%[%a.%d]+", "")), lang .. " format " .. k) end
    end
  end
end
print(string.format("passed %d, failed %d", pass, fail))
os.exit(fail == 0 and 0 or 1)
