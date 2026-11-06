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
print(string.format("passed %d, failed %d", passes, fails))
