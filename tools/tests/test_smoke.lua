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
-- Settings rows stay inside a scroll frame: every row fits in its box, long sections scroll.
UI:ShowView("settings")
local scrolls = 0
for id, box in pairs(UI.sSections or {}) do
  local sf = box.sf
  if not sf then fails = fails + 1; print("FAIL no scroll frame", id) else
    local bottom = 0
    for _, row in ipairs(box.rows) do
      local pt = row.points[#row.points]
      bottom = math.max(bottom, -(pt[5] or 0) + row:GetHeight())
    end
    if box:GetHeight() < bottom then fails = fails + 1; print("FAIL rows overflow", id, bottom, box:GetHeight()) end
    if sf:Range() > 0 then scrolls = scrolls + 1 end
    local ok, err = pcall(sf:GetScript("OnMouseWheel"), sf, -1)
    if not ok then fails = fails + 1; print("FAIL wheel", id, err) end
  end
end
if scrolls == 0 then fails = fails + 1; print("FAIL no settings section needs scrolling (interface should)") end
print("smoke: " .. (fails == 0 and "ok" or (fails .. " failures")))
os.exit(fails == 0 and 0 or 1)
