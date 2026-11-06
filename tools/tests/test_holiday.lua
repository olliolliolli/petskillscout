-- Holiday quests (hol = calendar event ID): map pins only while the holiday is on.
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
PetSkillScoutDB = {language = "en"}; PSS:InitializeDB()
MOCK.Fire("ADDON_LOADED", "PetSkillScout")
local W, H = PSS.QuestWorth, PSS.Holidays
local fails, passes = 0, 0
local function check(name, ok) if ok then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end end
local rec = PSS.QuestDB[8721]
check("Starweave is a Lunar Festival quest", rec and rec.hol == 18)
W.PlayerLevel = function() return 60 end
local function onMap(id)
  for _, x in ipairs(W:OnMap(rec.m, 60)) do if x.id == id then return true end end
  return false
end
H.active = {}
check("no pin outside the holiday", not onMap(8721))
H.active = {[18] = true}
check("pin while the holiday runs", onMap(8721))
H.active = {[1] = true}
check("other holiday does not count", not onMap(8721))
check("unknown holiday never active", not H:IsActive(-1))
-- Quests started from an object (wanted poster) get a pin.
local found = false
for _, x in ipairs(W:OnMap(1439, 15)) do if x.id == 4740 then found = true end end
check("wanted poster quest on the map", found)
-- Completed quests: server list at login, chains, survives without the game flag.
PetSkillScoutDB.questDone = nil
C_QuestLog = C_QuestLog or {}
local oldAll = C_QuestLog.GetAllCompletedQuestIDs
C_QuestLog.GetAllCompletedQuestIDs = function() return {4740} end
check("server list loaded", W:LoadCompleted() == 1 and W:Done(4740))
W:MarkDone(985)
check("chain: previous quest marked done", W:Done(984))
local found2 = false
for _, x in ipairs(W:OnMap(1439, 15)) do if x.id == 4740 then found2 = true end end
check("done quest has no pin", not found2)
C_QuestLog.GetAllCompletedQuestIDs = oldAll
-- Skills from the classic skill list (no GetProfessions): Cooking missing.
local oldGP = GetProfessions
GetProfessions = nil
GetNumSkillLines = function() return 2 end
GetSkillLineInfo = function(i) if i == 1 then return "Fishing", nil, nil, 40 end return "Swords", nil, nil, 30 end
GetTime = GetTime or function() return 0 end
W.SKILL_SPELLS = W.SKILL_SPELLS
local t0 = GetTime()
GetTime = function() return t0 + 100 end -- skip the skill cache
check("fishing seen from skill list", W:HasSkill(356))
check("no cooking: cooking quest hidden", not W:HasSkill(185))
-- Skills from the spell book when no skill list has them (WoW Forever).
GetNumSkillLines = function() return 0 end
local oldBook = PSS.SpellBar and PSS.SpellBar.Book
PSS.SpellBar = PSS.SpellBar or {}
PSS.SpellBar.Book = function() return {Fishing = {rank = 1}, Cooking = {rank = 1}} end
GetTime = function() return t0 + 300 end
check("fishing from the spell book", W:HasSkill(356))
check("no first aid in the book", not W:HasSkill(129))
PSS.SpellBar.Book = oldBook
-- Talking to the giver: quests the NPC did not offer lose their pin.
PetSkillScoutDB.questNotOffered = nil
local npc = PSS.QuestDB[963].g
W.byMap = nil
local okBefore = W:Available(963, 15)
W:NotOffered(npc, {})
check("not offered at the NPC: no pin", okBefore and not W:Available(963, 15))
W:NotOffered(npc, {[963] = true})
check("offered again: pin back", W:Available(963, 15))
GetProfessions = oldGP
print(string.format("passed %d, failed %d", passes, fails))
