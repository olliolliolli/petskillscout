-- Nearest hunter / pet trainer lists.
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
PetSkillScoutDB = {language = "en"}; PSS:InitializeDB()
MOCK.Fire("ADDON_LOADED", "PetSkillScout")
local passes, fails = 0, 0
local function check(name, cond) if cond then passes = passes + 1 else fails = fails + 1; print("FAIL: " .. name) end end
local TR = PSS.Trainers
PSS.player.faction = "Alliance"
local a = TR:List("hunter")
check("alliance hunter trainers from ATT", #a >= 3)
for _, t in ipairs(a) do check("no faction tag in name " .. t.name, not t.name:find("<")) end
PSS.player.faction = "Horde"
local h = TR:List("hunter")
local ids = {}
for _, t in ipairs(a) do ids[t.npc] = true end
local overlap = 0
for _, t in ipairs(h) do if ids[t.npc] then overlap = overlap + 1 end end
check("horde list differs", #h >= 3 and overlap < #h)
check("no pet trainers without visits", #TR:List("pet") == 0)
PetSkillScoutDB.trainersSeen = {[123] = {name = "Pet Guy", kind = "pet", m = 1453, x = 50, y = 50}}
check("visited pet trainer listed", #TR:List("pet") == 1)
print(string.format("passed %d, failed %d", passes, fails))
