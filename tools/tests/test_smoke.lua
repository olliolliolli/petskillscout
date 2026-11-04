local dir = arg[1]
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
PetSkillScoutDB = {language = "en"}; PSS:InitializeDB()
MOCK.Fire("ADDON_LOADED", "PetSkillScout")
MOCK.Fire("PLAYER_ENTERING_WORLD", true, false)
MOCK.RunTimers()
local UI = PSS.UI
UI:Create()
local fails = 0
for _, lang in ipairs({"en", "uk", "pl", "de", "fr", "it", "es"}) do
  PetSkillScoutDB.language = lang
  for _, v in ipairs({"beasts", "rares", "pet", "route", "collection", "gear", "quests", "settings"}) do
    local ok, err = pcall(UI.ShowView, UI, v)
    if not ok then fails = fails + 1; print("FAIL", lang, v, err) end
  end
end
-- Settings page has the new toggle.
local found = false
local src = io.open(dir .. "/UI.lua"):read("*a")
found = src:find('key="questAlert"', 1, true) ~= nil
if not found then fails = fails + 1; print("FAIL settings row") end
print("smoke: " .. (fails == 0 and "ok" or (fails .. " failures")))
os.exit(fails == 0 and 0 or 1)
