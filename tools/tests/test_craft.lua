-- Crafted gear (CraftData): shown for your own professions, also when the skill is low.
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
PetSkillScoutDB = {language = "en"}; PSS:InitializeDB()
MOCK.Fire("ADDON_LOADED", "PetSkillScout")
local G = PSS.Gear
local fails, passes = 0, 0
local function check(name, ok) if ok then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end end
check("craft data loaded", PSS.CraftData and #PSS.CraftData > 100)
local boots = G:Get(2309)
check("crafted boots indexed", boots and boots.src[1].t == "c")
G.Professions = function() return {} end
check("no profession: no source", #G:Sources(boots) == 0)
G.Professions = function() return {Leatherworking = {rank = 20, max = 75}} end
check("own profession, low skill: listed", #G:Sources(boots) == 1)
local t, d = G:SourceShort(boots)
check("short source shows need", t and t:find("55") and d and d:find("20"))
G.Professions = function() return {Leatherworking = {rank = 60, max = 75}} end
local _, d2 = G:SourceShort(boots)
check("ready when skill is enough", d2 and d2:find("make"))
print(string.format("passed %d, failed %d", passes, fails))
