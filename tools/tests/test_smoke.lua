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
  for _, v in ipairs({"beasts", "rares", "pet", "route", "collection", "gear", "quests", "network", "settings"}) do
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
-- Chat text under the theme font is drawn a bit smaller than the size picked in the game.
do
  local LY = PSS.Layout
  local cf = CreateFrame("ScrollingMessageFrame", "ChatFrame1")
  local got
  getmetatable(cf).m_SetFont = function(_, file, size) got = size end
  getmetatable(cf).m_GetFont = function() return "x", 14, "" end
  local oldInfo = FCF_GetChatWindowInfo
  FCF_GetChatWindowInfo = function(i) return "General", 14 end
  LY.applied.fonts = true
  LY:ChatFonts()
  if got ~= LY:ChatFontSize(14) or got >= 14 then fails = fails + 1; print("FAIL chat font size", got) end
  got = nil
  LY.applied.fonts = false
  LY:ChatFonts()
  if got then fails = fails + 1; print("FAIL chat font changed without the theme font") end
  FCF_GetChatWindowInfo = oldInfo
end
-- Micro menu / bags strips must not add anything to the game's layout frames
-- (their Layout() runs in combat: ADDON_ACTION_BLOCKED on SetSize / SetPoint).
do
  local LY, S = PSS.Layout, PSS.Skin
  local made = {}
  for _, n in ipairs({"MicroMenuContainer", "BagsBar"}) do
    local f = CreateFrame("Frame", n)
    made[n] = 0
    getmetatable(f).m_CreateTexture = function() made[n] = made[n] + 1; return MOCK.newObj("Texture") end
  end
  local wasActive, wasChat = S.active, LY.applied.chat
  S.active, LY.applied.chat = true, true
  local ok, err = pcall(LY.SkinMenus, LY)
  if not ok then fails = fails + 1; print("FAIL SkinMenus", err) end
  for n, c in pairs(made) do
    if c > 0 then fails = fails + 1; print("FAIL textures created on " .. n, c) end
    if not LY.strips[n] then fails = fails + 1; print("FAIL no strip behind " .. n) end
  end
  S.active, LY.applied.chat = wasActive, wasChat
end
-- Fast loot: off by default, takes every slot with auto loot, steps aside for FasterLoot.
do
  local looted = {}
  local oldNum, oldSlot, oldAdd = GetNumLootItems, LootSlot, C_AddOns
  GetNumLootItems = function() return 3 end
  LootSlot = function(i) looted[#looted + 1] = i end
  local others = {}
  C_AddOns = {IsAddOnLoaded = function(n) return others[n] or false end}
  PSS.FastLoot.busy = false
  MOCK.Fire("LOOT_READY", true)
  if #looted ~= 0 then fails = fails + 1; print("FAIL fast loot on by default") end
  PetSkillScoutDB.fastLoot = true
  MOCK.Fire("LOOT_READY", true)
  if #looted ~= 3 then fails = fails + 1; print("FAIL fast loot took", #looted) end
  MOCK.Fire("LOOT_CLOSED")
  looted = {}
  MOCK.Fire("LOOT_READY", false)
  if #looted ~= 0 then fails = fails + 1; print("FAIL fast loot without auto loot") end
  others.FasterLoot = true
  MOCK.Fire("LOOT_CLOSED"); MOCK.Fire("LOOT_READY", true)
  if #looted ~= 0 or PSS.FastLoot:Other() ~= "FasterLoot" then fails = fails + 1; print("FAIL fast loot with FasterLoot") end
  PetSkillScoutDB.fastLoot = nil
  GetNumLootItems, LootSlot, C_AddOns = oldNum, oldSlot, oldAdd
end
-- Gear tab: quest rewards point to the quest giver (QuestDB matched by quest name).
do
  local G = PSS.Gear
  PSS.player = PSS.player or {}
  PSS.player.faction = "Alliance"
  local tried, found = 0, 0
  for _, rec in ipairs(PSS.GearData) do
    for _, src in ipairs(rec.src or {}) do
      if src.t == "q" and (not src.f or src.f == "A") then
        tried = tried + 1
        local id, r = G:QuestFor(rec)
        if id then
          found = found + 1
          if r.n:gsub("%s*%(%d+/%d+%)$", ""):lower() ~= src.n:lower() then fails = fails + 1; print("FAIL quest name mismatch", src.n, r.n) end
          if r.s == "H" then fails = fails + 1; print("FAIL horde quest for alliance", r.n) end
        end
        break
      end
    end
  end
  print("gear quest sources", tried, "matched", found)
  if found < tried * 0.5 then fails = fails + 1; print("FAIL too few gear quests matched") end
  UI:ShowView("gear")
end
-- Square minimap: the round quest-area rings are switched off.
do
  local LY = PSS.Layout
  local set = {}
  local mt = getmetatable(Minimap)
  for _, m in ipairs({"SetQuestBlobRingScalar", "SetArchBlobRingScalar", "SetQuestBlobRingAlpha"}) do
    mt["m_" .. m] = function(_, v) set[m] = v end
  end
  local oldWant = LY.Want
  LY.Want = function(_, part) return part == "minimap" end
  LY.applied.minimap = nil
  local ok, err = pcall(LY.Apply, LY)
  if not ok then fails = fails + 1; print("FAIL minimap apply", err) end
  if set.SetQuestBlobRingScalar ~= 0 or set.SetArchBlobRingScalar ~= 0 or set.SetQuestBlobRingAlpha ~= 0 then
    fails = fails + 1; print("FAIL quest blob ring still on", tostring(set.SetQuestBlobRingScalar))
  end
  LY.Want = oldWant
end
-- Header network chip: "Connect" when offline, online count when connected.
do
  local N = PSS.Net
  local oldID, oldCount, oldShow = N.ChannelID, N.OnlineCount, N.ShowConnect
  local shownAt
  N.ShowConnect = function(_, force, anchor) shownAt = anchor; return true end
  N.ChannelID = function() return nil end
  UI:RefreshHeader()
  if UI.netChip.text:GetText() ~= PSS:L("netChipConnect") then fails = fails + 1; print("FAIL net chip offline text", UI.netChip.text:GetText()) end
  UI.netChip:GetScript("OnClick")(UI.netChip)
  if shownAt ~= UI.netChip then fails = fails + 1; print("FAIL connect prompt not opened at the chip") end
  N.ChannelID = function() return 5 end
  N.OnlineCount = function() return 12 end
  UI:RefreshHeader()
  if not tostring(UI.netChip.text:GetText()):find("12") then fails = fails + 1; print("FAIL net chip online count", UI.netChip.text:GetText()) end
  N.ChannelID, N.OnlineCount, N.ShowConnect = oldID, oldCount, oldShow
end
-- Header: tabs, network chip and character chip never overlap (every language,
-- offline "Connect" is the widest chip).
do
  local N = PSS.Net
  local oldID = N.ChannelID
  N.ChannelID = function() return nil end
  for _, lang in ipairs({"en", "uk", "pl", "de", "fr", "it", "es"}) do
    PetSkillScoutDB.language = lang
    UI:RefreshHeader()
    local last = UI.tabs[#UI.tabs]
    local pt = last.points[#last.points]
    local tabRight = pt[4] + last:GetWidth()
    local chipsLeft = 1000 - UI.chip:GetWidth() - 6 - UI.netChip:GetWidth()
    if tabRight > chipsLeft then fails = fails + 1; print("FAIL header overlap", lang, tabRight, chipsLeft) end
  end
  PetSkillScoutDB.language = "en"
  N.ChannelID = oldID
end
print("smoke: " .. (fails == 0 and "ok" or (fails .. " failures")))
os.exit(fails == 0 and 0 or 1)
