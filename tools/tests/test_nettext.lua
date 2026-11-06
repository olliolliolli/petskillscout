-- Realm network over channel text (3.1.0): receive "PSS~..." lines, send via SendChatMessage.
local dir = arg[1]
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
PetSkillScoutDB = {language = "en"}; PSS:InitializeDB()
MOCK.Fire("ADDON_LOADED", "PetSkillScout")
local S = PSS.Sync
local f = S.frame:GetScript("OnEvent")
local fails, passes = 0, 0
local function check(name, ok) if ok then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end end
PetSkillScoutDB.peers = {}
f(S.frame, "CHAT_MSG_CHANNEL", "PSS~H~3.1.0~5~1~2~3~", "Freya Laroux-Forever", "", "7. PSSNet1", "", "", 0, 7, "PSSNet1")
local p = PetSkillScoutDB.peers["Freya Laroux"]
check("hello from channel text", p and p.v == "3.1.0" and p.score == 5)
f(S.frame, "CHAT_MSG_CHANNEL", "PSS~H~9.9~5~1~2~3~", "Bob", "", "1. General", "", "", 0, 1, "General")
check("other channels ignored", PetSkillScoutDB.peers["Bob"] == nil)
f(S.frame, "CHAT_MSG_CHANNEL", "hello all", "Carl", "", "7. PSSNet1", "", "", 0, 7, "PSSNet1")
check("plain chat ignored", PetSkillScoutDB.peers["Carl"] == nil)
local sent = {}
C_ChatInfo = C_ChatInfo or {}
C_ChatInfo.SendChatMessage = function(m, t, l, id) sent[#sent + 1] = {m, t, id} end
S:Send("H~x", "CHANNEL", 7)
check("sent as channel text", sent[1] and sent[1][1] == "PSS~H~x" and sent[1][2] == "CHANNEL" and sent[1][3] == 7)
print(string.format("passed %d, failed %d", passes, fails))
