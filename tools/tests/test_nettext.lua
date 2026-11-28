-- Realm network on WoW Forever (3.1.3): channel members from the hidden channel
-- list / join notices; broadcasts go as addon whispers to each member.
local dir = arg[1]
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
PetSkillScoutDB = {language = "en"}; PSS:InitializeDB()
MOCK.Fire("ADDON_LOADED", "PetSkillScout")
local S, N = PSS.Sync, PSS.Net
local fails, passes = 0, 0
local function check(name, ok) if ok then passes = passes + 1 else fails = fails + 1; print("FAIL " .. name) end end
PetSkillScoutDB.peers = {}
local nf = N.frame:GetScript("OnEvent")
nf(N.frame, "CHAT_MSG_CHANNEL_LIST", "*Freya Laroux, @Sei Fy, Jack Crow", "", "", "7. PSSNet1", "", "", 0, 7, "PSSNet1")
check("members from channel list", N.members["Freya Laroux"] and N.members["Sei Fy"] and N.members["Jack Crow"])
check("listed members count as online", PetSkillScoutDB.peers["Jack Crow"] ~= nil)
nf(N.frame, "CHAT_MSG_CHANNEL_LIST", "Bob", "", "", "1. General", "", "", 0, 1, "General")
check("other channel lists ignored", N.members["Bob"] == nil)
nf(N.frame, "CHAT_MSG_CHANNEL_LEAVE", "", "Jack Crow", "", "7. PSSNet1", "", "", 0, 7, "PSSNet1")
check("leave removes member", N.members["Jack Crow"] == nil)
local sent = {}
C_ChatInfo = C_ChatInfo or {}
C_ChatInfo.RegisterAddonMessagePrefix = C_ChatInfo.RegisterAddonMessagePrefix or function() return true end
C_ChatInfo.SendAddonMessage = function(p, m, d, t) sent[#sent + 1] = {m, d, t} end
SendChatMessage = function() sent.chat = true end
if C_ChatInfo.SendChatMessage then C_ChatInfo.SendChatMessage = function() sent.chat = true end end
S:Send("H~x", "CHANNEL", 7)
local before = #sent
S:Send("X~1", "CHANNEL", 7)
check("non-hello not sent to unconfirmed", #sent == before)
local targets = {}
for _, x in ipairs(sent) do if x[2] == "WHISPER" and x[1] == "H~x" then targets[x[3]] = true end end
check("broadcast whispers each member", targets["Freya Laroux"] and targets["Sei Fy"])
check("no channel text sent", not sent.chat)
ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing."
check("not-found line hidden", N:OnNotFound("No player named 'Sei Fy' is currently playing.") == true)
check("unreachable dropped", N.members["Sei Fy"] == nil)
check("other system lines kept", N:OnNotFound("No player named 'Stranger' is currently playing.") == false)
sent = {}
N:Confirm("Freya Laroux")
S:Send("H~y", "CHANNEL", 7)
local again = {}
for _, x in ipairs(sent) do if x[2] == "WHISPER" then again[x[3]] = true end end
check("unreachable not whispered again", not again["Sei Fy"] and again["Freya Laroux"])
sent = {}
N:NoteWhisper("Wipe Nonmio")
N.members["Wipe Nonmio"] = {target = "Wipe Nonmio", t = 0}
check("odd wording still hidden", N:OnNotFound("Гравця на ім'я «Wipe Nonmio» зараз немає в грі.") == true)
GetNormalizedRealmName = function() return "CAMWOWEU5Realm6PvP" end
N:AddMember("Slu Gnu", "Slu Gnu-CAMWOWEU4Realm8PvP")
check("other realm not added", N.members["Slu Gnu"] == nil)
N:AddMember("Kim Bo", "Kim Bo-CAMWOWEU5Realm6PvP")
check("own realm kept, short target", N.members["Kim Bo"] and N.members["Kim Bo"].target == "Kim Bo")
-- Incoming data is checked (3.7.3).
do
  local N, S = PSS.Net, PSS.Sync
  check("stat limits", N.Stat("5", 10) == 5 and N.Stat("99999", 10) == nil and N.Stat("-1", 10) == nil)
  local old, got = S.handlers.ZZ, nil
  S.handlers.ZZ = function(parts) got = parts[2] end
  S:Receive("ZZ~a|cffff0000b", "PARTY", "Tester-Realm")
  S.handlers.ZZ = old
  check("escape codes stripped", got == nil or not got:find("|", 1, true))
end
-- Inside an instance nothing is sent.
sent = {}
IsInInstance = function() return true, "party" end
S:Send("H~z", "WHISPER", "Kim Bo")
check("no send inside an instance", #sent == 0)
check("SendAll refuses inside an instance", S:SendAll("H~z", true) == false)
IsInInstance = function() return false, "none" end
print(string.format("passed %d, failed %d", passes, fails))
