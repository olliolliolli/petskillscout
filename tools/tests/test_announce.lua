-- Chat notes to group and guild (3.7.0).
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
PetSkillScoutDB = {language = "en"}; PSS:InitializeDB()
local fails, passes = 0, 0
local function check(name, ok) if ok then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end end
local sent = {}
C_ChatInfo = nil
SendChatMessage = function(text, chan) sent[#sent + 1] = {text, chan} end
IsInGroup, IsInGuild = function() return true end, function() return true end
IsInRaid, IsInInstance, InCombatLockdown = function() return false end, function() return false end, function() return false end
local A = PSS.Announce
check("rare sent", A:Rare({id = 1, name = "Nightscreech"}) and #sent == 2)
check("signed", sent[1][1] == "{PetSkillScout} Tamed the rare Nightscreech!" and sent[1][2] == "PARTY" and sent[2][2] == "GUILD")
check("not repeated", not A:Rare({id = 1, name = "Nightscreech"}))
check("rate limit", not A:Rare({id = 2, name = "X"}) and #sent == 2)
check("not a milestone", not A:Achievement("share5"))
PetSkillScoutDB.announceOn = false
check("switched off", not A:Rare({id = 3, name = "Y"}))
PetSkillScoutDB.announceOn = nil
sent = {}
A:ShareRare({name = "Duskstalker", zone = "Darkshore", beast = {spawnPoints = {{45.2, 60.1}}}})
check("spot", sent[1] and sent[1][1] == "{PetSkillScout} Rare Duskstalker: Darkshore 45.2, 60.1" and #sent == 1)
IsInGroup = function() return false end
sent = {}
check("no group", not A:ShareRare({name = "D", beast = {}}) and #sent == 0)
print(string.format("passed %d, failed %d", passes, fails))
