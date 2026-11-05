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
for _, lang in ipairs({"en", "uk", "pl", "de", "fr", "it", "es", "pt", "ru"}) do
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
  for _, lang in ipairs({"en", "uk", "pl", "de", "fr", "it", "es", "pt", "ru"}) do
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

-- 2.9.0: pet bar follows new ranks / new skills.
do
  local PB = PSS.PetBar
  local book = {{"Bite", "Rank 1"}, {"Bite", "Rank 2"}, {"Growl", "Rank 1"}, {"Dash", "Rank 1"}}
  local bar = {[1] = {"Attack", nil, true}, [4] = {"Bite", "Rank 1"}, [5] = {"Growl", "Rank 1"}}
  local cursor
  local saved = {UnitExists, GetSpellBookItemName, GetPetActionInfo, PickupSpellBookItem, PickupPetAction, ClearCursor, GetCursorInfo, IsPassiveSpell, C_SpellBook}
  C_SpellBook = nil
  UnitExists = function(u) return u == "pet" end
  GetSpellBookItemName = function(i) local b = book[i]; if b then return b[1], b[2] end end
  GetSpellBookItemInfo = function() return "SPELL", nil end
  IsPassiveSpell = function() return false end
  GetPetActionInfo = function(s) local b = bar[s]; if b then return b[1], b[2], "tex", b[3] or false end end
  PickupSpellBookItem = function(i) cursor = book[i] end
  PickupPetAction = function(s) if cursor then bar[s] = {cursor[1], cursor[2]}; cursor = nil end end
  ClearCursor = function() cursor = nil end
  GetCursorInfo = function() return nil end
  PetSkillScoutDB.petBarKnown = nil
  PB:Update() -- first look at this pet: rank fix only
  if not (bar[4] and bar[4][2] == "Rank 2") then fails = fails + 1; print("FAIL pet bar rank 2 replaces rank 1") end
  if bar[6] then fails = fails + 1; print("FAIL pet bar: known skills not forced onto the bar") end
  book[5] = {"Claw", "Rank 1"}
  PB:Update()
  if not (bar[6] and bar[6][1] == "Claw") then fails = fails + 1; print("FAIL pet bar: new skill into free slot") end
  if bar[1][1] ~= "Attack" then fails = fails + 1; print("FAIL pet bar: command slot kept") end
  MOCK.combat = true
  local oldIC = InCombatLockdown; InCombatLockdown = function() return true end
  book[6] = {"Claw", "Rank 2"}
  PB:Update()
  if bar[6][2] ~= "Rank 1" or not PB.pending then fails = fails + 1; print("FAIL pet bar waits for combat end") end
  InCombatLockdown = oldIC; MOCK.combat = false
  PetSkillScoutDB.petBarAuto = false
  PB.pending = false
  PB:Update()
  if bar[6][2] ~= "Rank 1" then fails = fails + 1; print("FAIL pet bar option off") end
  PetSkillScoutDB.petBarAuto = nil
  UnitExists, GetSpellBookItemName, GetPetActionInfo, PickupSpellBookItem, PickupPetAction, ClearCursor, GetCursorInfo, IsPassiveSpell, C_SpellBook = unpack(saved)
end
-- 2.9.2: your own action bars follow new ranks / new spells.
do
  local SB = PSS.SpellBar
  local book = {{"Arcane Shot", "Rank 1", 1}, {"Arcane Shot", "Rank 2", 2}, {"Serpent Sting", "Rank 1", 3}}
  local bars = {[1] = 1, [2] = 3, [3] = 1, [5] = 99}
  local cursor
  local saved = {GetSpellBookItemName, GetSpellBookItemInfo, IsPassiveSpell, HasAction, GetActionInfo, GetSpellInfo, GetSpellSubtext, PickupSpellBookItem, PlaceAction, ClearCursor, GetCursorInfo, C_SpellBook, C_Spell}
  C_SpellBook, C_Spell = nil, nil
  GetSpellBookItemName = function(i) local b = book[i]; if b then return b[1], b[2] end end
  GetSpellBookItemInfo = function(i) if book[i] then return "SPELL", book[i][3] end end
  IsPassiveSpell = function() return false end
  local byId = {}
  local function Index() for _, b in ipairs(book) do byId[b[3]] = b end end
  Index(); byId[99] = {"Hearthstone", ""}
  HasAction = function(s) return bars[s] ~= nil end
  GetActionInfo = function(s) if bars[s] then return "spell", bars[s] end end
  GetSpellInfo = function(id) return byId[id] and byId[id][1] end
  GetSpellSubtext = function(id) return byId[id] and byId[id][2] end
  PickupSpellBookItem = function(i) cursor = book[i][3] end
  PlaceAction = function(s) if cursor then bars[s] = cursor; cursor = nil end end
  ClearCursor = function() cursor = nil end
  GetCursorInfo = function() return nil end
  PetSkillScoutDB.spellBarKnown = nil
  SB:Update()
  if bars[1] ~= 2 or bars[3] ~= 2 then fails = fails + 1; print("FAIL action bars: rank 2 replaces rank 1 everywhere") end
  if bars[2] ~= 3 or bars[5] ~= 99 then fails = fails + 1; print("FAIL action bars: other buttons untouched") end
  if bars[4] then fails = fails + 1; print("FAIL action bars: known spells not forced on") end
  book[4] = {"Hunter's Mark", "Rank 1", 4}; Index()
  SB:Update()
  if bars[4] ~= 4 then fails = fails + 1; print("FAIL action bars: new spell into first free slot") end
  local oldIC = InCombatLockdown; InCombatLockdown = function() return true end
  book[5] = {"Serpent Sting", "Rank 2", 5}; Index()
  SB:Update()
  if bars[2] ~= 3 or not SB.pending then fails = fails + 1; print("FAIL action bars wait for combat end") end
  InCombatLockdown = oldIC
  SB:Update()
  if bars[2] ~= 5 then fails = fails + 1; print("FAIL action bars after combat") end
  GetSpellBookItemName, GetSpellBookItemInfo, IsPassiveSpell, HasAction, GetActionInfo, GetSpellInfo, GetSpellSubtext, PickupSpellBookItem, PlaceAction, ClearCursor, GetCursorInfo, C_SpellBook, C_Spell = unpack(saved)
end
-- 2.9.3: map pin drivers sleep while the world map is closed.
do
  local oldWM = WorldMapFrame
  local wm = CreateFrame("Frame"); wm:Hide(); WorldMapFrame = wm
  MOCK.Fire("PLAYER_ENTERING_WORLD", false, false) -- hooks the map
  local d = CreateFrame("Frame")
  PSS:OnlyWithWorldMap(d)
  local onShow, onHide = wm and wm.scripts and wm.scripts.OnShow, wm and wm.scripts and wm.scripts.OnHide
  if not (onShow and onHide) then fails = fails + 1; print("FAIL world map hooks missing")
  else
    onHide()
    if d:IsShown() then fails = fails + 1; print("FAIL map driver sleeps with the map closed") end
    onShow()
    if not d:IsShown() then fails = fails + 1; print("FAIL map driver wakes with the map") end
  end
  if d:IsShown() == nil then end
  local d2 = CreateFrame("Frame"); wm:Hide(); PSS:OnlyWithWorldMap(d2)
  if d2:IsShown() then fails = fails + 1; print("FAIL late map driver sleeps too") end
  WorldMapFrame = oldWM
end
-- 2.9.4: Forever names are "First Last" - your own echo is still you.
do
  local S = PSS.Sync
  PetSkillScoutDB.peers = PetSkillScoutDB.peers or {}
  PetSkillScoutDB.peers["TesterSmith"] = {t = time()} -- left by an older version
  S:NoteSent("H|test|1")
  if not S:IsMe("Tester Smith", "H|test|1") then fails = fails + 1; print("FAIL own First Last echo is you") end
  if PetSkillScoutDB.peers["TesterSmith"] then fails = fails + 1; print("FAIL old duplicate of you removed") end
  if not S:IsMe("Tester Smith", "other") then fails = fails + 1; print("FAIL your full name is remembered") end
  if S:IsMe("Mira Stone", "H|test|1") then fails = fails + 1; print("FAIL another hunter is not you") end
  PSS.Sync:Receive("H", "CHANNEL", "Mira Stone-Grillz")
  if not PetSkillScoutDB.peers["Mira Stone"] then fails = fails + 1; print("FAIL First Last peer kept with space") end
end
-- 2.9.4: network events go to their own chat tab.
do
  local lines, made = {}, nil
  local oldOpen, oldInfo = FCF_OpenNewWindow, GetChatWindowInfo
  FCF_OpenNewWindow = function(name)
    made = CreateFrame("Frame"); made.AddMessage = function(_, t) lines[#lines + 1] = t end
    ChatFrame7 = made; return made
  end
  GetChatWindowInfo = function(i) if i == 7 and made then return PSS:L("netChatTab"), 12, 1, 1, 1, 1, true, 0 end end
  PetSkillScoutDB.netChatMade = nil; PSS.NetChat.tried = nil
  PSS.NetFeed:Add("rare", "Mira Stone", "Ghostfang", "Barrens")
  PSS.NetFeed:Add("join", "Ole Brand", "2.9.4")
  if not made or #lines ~= 2 or not lines[1]:find("Ghostfang", 1, true) then fails = fails + 1; print("FAIL network chat tab gets events: " .. #lines) end
  FCF_OpenNewWindow, GetChatWindowInfo = oldOpen, oldInfo
end
-- 2.9.5: /pss cpu times our own frames and restores them.
do
  local clock = 0
  local oldD, oldE = debugprofilestop, EnumerateFrames
  debugprofilestop = function() clock = clock + 1; return clock end
  local f1 = CreateFrame("Frame", "PetSkillScoutProbe")
  local ran = 0
  local orig = function() ran = ran + 1 end
  f1:SetScript("OnUpdate", orig)
  local other = CreateFrame("Frame", "SomeoneElse"); other:SetScript("OnUpdate", orig)
  local list = {f1, other}
  EnumerateFrames = function(prev) if not prev then return list[1] end for i, x in ipairs(list) do if x == prev then return list[i + 1] end end end
  local printed = {}
  local oldPrint = PSS.Print; PSS.Print = function(_, m) printed[#printed + 1] = m end
  PSS.Profiler:Start()
  if other:GetScript("OnUpdate") ~= orig then fails = fails + 1; print("FAIL profiler touched another addon's frame") end
  f1:GetScript("OnUpdate")(f1, 0.016)
  if ran ~= 1 then fails = fails + 1; print("FAIL profiled handler still runs") end
  PSS.Profiler:Stop()
  if f1:GetScript("OnUpdate") ~= orig then fails = fails + 1; print("FAIL profiler restores handlers") end
  local found = false
  for _, m in ipairs(printed) do if m:find("PetSkillScoutProbe", 1, true) then found = true end end
  if not found then fails = fails + 1; print("FAIL profiler report lists the frame") end
  PSS.Print = oldPrint; debugprofilestop, EnumerateFrames = oldD, oldE
end
-- 2.9.6: no PetSkillScout frame runs an OnUpdate every frame while idle.
do
  local busy = {}
  for _, o in ipairs({PSS.Minimap._driver, PSS.Net.frame, PSS.Sync.frame, PSS.Layout.unitEvents}) do
    if o and o:GetScript("OnUpdate") then busy[#busy + 1] = tostring(o.pssKey or o.name) end
  end
  if #busy > 0 then fails = fails + 1; print("FAIL per-frame handlers left: " .. table.concat(busy, ", ")) end
end
-- 2.9.7: the Auto Shot bar does not rewrite its text every frame.
do
  local ST = PSS.ShotTimer
  local f = ST:Build()
  local sets = 0
  local orig = f.text.SetText
  f.text.SetText = function(self, t) sets = sets + 1; return orig(self, t) end
  ST.shooting, ST.last, ST.speed = true, GetTime() - 0.1, 3
  f.pssState = nil
  for _ = 1, 30 do ST:OnUpdate() end
  if sets ~= 1 then fails = fails + 1; print("FAIL shot bar text set " .. sets .. " times for one state") end
  ST.shooting, ST.last, ST.speed = false, nil, nil
  f.text.SetText = orig
end
-- 2.9.9: tracker section updates are restyled once per burst.
do
  local src = io.open(dir .. "/Skin.lua"):read("*a")
  if not src:find('PSS:Soon("tracker"', 1, true) then fails = fails + 1; print("FAIL tracker restyle not coalesced") end
end
-- Secure buttons run on the client's click phase (both registered).
do
  local old = GetCVarBool
  GetCVarBool = function() return true end
  if not PSS:ClickRan(true) or PSS:ClickRan(false) then fails = fails + 1; print("FAIL ClickRan key down") end
  GetCVarBool = function() return false end
  if PSS:ClickRan(true) or not PSS:ClickRan(false) then fails = fails + 1; print("FAIL ClickRan key up") end
  GetCVarBool = old
  for _, f in ipairs({"Net.lua", "PetCare.lua"}) do
    local src = io.open(dir .. "/" .. f):read("*a")
    if src:find('RegisterForClicks("AnyUp")', 1, true) then fails = fails + 1; print("FAIL secure button up-only in " .. f) end
  end
end
-- 2.9.1: the minimap button joins the network while you are not in it.
do
  local N = PSS.Net
  local mm = PSS:CreateMinimapButton()
  local old = N.ChannelIDRaw
  N.ChannelIDRaw = function() return nil end
  N:UpdateJoinButtons()
  if not (mm and mm:GetAttribute("type1") == "macro" and mm:GetAttribute("macrotext1") == "/join PSSNet1") then
    fails = fails + 1; print("FAIL minimap button joins the network") end
  N.ChannelIDRaw = function() return 5 end
  N:UpdateJoinButtons()
  if mm:GetAttribute("type1") ~= nil then fails = fails + 1; print("FAIL join macro removed once connected") end
  N.ChannelIDRaw = old
  -- Own messages coming back as "Name-Realm" are not a second hunter.
  local before = 0; for _ in pairs(PetSkillScoutDB.peers or {}) do before = before + 1 end
  PSS.Sync:Receive("H", "GUILD", (UnitName("player") or "?") .. "-Grillz")
  local after = 0; for _ in pairs(PetSkillScoutDB.peers or {}) do after = after + 1 end
  if after ~= before then fails = fails + 1; print("FAIL own Name-Realm counted as a peer") end
end
-- Hook storms collapse into one pass.
do
  local n = 0
  for _ = 1, 50 do PSS:Soon("t", function() n = n + 1 end) end
  MOCK.RunTimers()
  if n ~= 1 then fails = fails + 1; print("FAIL Soon coalesces: " .. n) end
end
print("smoke: " .. (fails == 0 and "ok" or (fails .. " failures")))
os.exit(fails == 0 and 0 or 1)
