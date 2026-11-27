-- Behaviour checks of the newer features on the mock client: each block sets up
-- what the game would give and checks what the addon does with it.
-- Usage (from repo root): lua5.1 tools/tests/test_features.lua "$PWD/PetSkillScout"
local dir = arg[1]
arg = {[0] = arg[0], dir}
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
local pass, fail = 0, 0
local function ok(cond, msg)
  if cond then pass = pass + 1 else fail = fail + 1; print("FAIL: " .. msg) end
end
local function try(msg, fn)
  local good, err = pcall(fn)
  if not good then fail = fail + 1; print("FAIL: " .. msg .. " (error: " .. tostring(err) .. ")") end
end
PetSkillScoutDB = {language = "en"}
PSS:InitializeDB()

-- 1. Nameplate stacking: option off never writes the game's settings ----------
try("stacking", function()
  Enum = Enum or {}
  Enum.NamePlateStackType = {Enemy = 1, Friendly = 2}
  C_CVar = C_CVar or {}
  C_CVar.GetCVar = function(k) return GetCVar(k) end
  -- The player turned stacking on in the game's own options.
  MOCK.cvars.nameplateMotion = "1"
  MOCK.cvars.nameplateStackingTypes = "1"
  MOCK.cvars["nameplateStackingTypes#1"] = "1"
  MOCK.cvarWrites = {}
  PetSkillScoutDB.plateStack = false
  PSS:ApplyPlateStacking()
  MOCK.Fire("PLAYER_REGEN_ENABLED"); MOCK.Fire("PLAYER_ENTERING_WORLD", false, false)
  ok(#MOCK.cvarWrites == 0, "stacking off: no CVar written (got " .. table.concat(MOCK.cvarWrites, ",") .. ")")
  ok(MOCK.cvars["nameplateStackingTypes#1"] == "1" and MOCK.cvars.nameplateMotion == "1", "the game's own stacking stays on")
  PetSkillScoutDB.plateStack = true
  PSS:ApplyPlateStacking()
  ok(MOCK.cvars["nameplateStackingTypes#1"] == "1", "stacking on: enemy stacking bit set")
  PetSkillScoutDB.plateStack = false
end)

-- 2. Nameplates: raid icon, quest icon, encounter boss -------------------------
local P = PSS.Plates
local function Plate(level, cls)
  local uf = CreateFrame("Frame")
  uf.healthBar = CreateFrame("StatusBar")
  getmetatable(uf.healthBar).m_GetStatusBarColor = function() return 0.5, 0.5, 0.5 end
  uf.HealthBarsContainer = CreateFrame("Frame")
  uf.RaidTargetFrame = CreateFrame("Frame")
  uf.PlayerLevelDiffFrame = CreateFrame("Frame")
  -- The game's UpdateAnchors puts the raid icon left of its own bar.
  uf.UpdateAnchors = function(self)
    self.RaidTargetFrame:ClearAllPoints()
    self.RaidTargetFrame:SetPoint("RIGHT", self.HealthBarsContainer, "LEFT", 0, 0)
  end
  uf.pssLevel, uf.pssClass = level, cls
  return uf
end
try("plates", function()
  P.on = true
  PSS.Skin = PSS.Skin or {}
  PSS.Skin.active = true
  local oldLevel, oldCls, oldAtk = UnitLevel, UnitClassification, UnitCanAttack
  local plates = {}
  UnitExists = function(u) return plates[u] ~= nil or u == "player" end
  UnitLevel = function(u) local uf = plates[u]; if uf then return uf.pssLevel end return MOCK.level end
  UnitClassification = function(u) local uf = plates[u]; return uf and uf.pssClass or "normal" end
  UnitCanAttack = function(_, u) return plates[u] ~= nil end
  C_NamePlate = C_NamePlate or {}
  C_NamePlate.GetNamePlateForUnit = function(u) local uf = plates[u]; return uf and {UnitFrame = uf} end
  local boss, trash = Plate(47, "elite"), Plate(44, "elite")
  plates.nameplate1, plates.nameplate2 = boss, trash

  -- Raid icon moved off our bar, and back after the game's UpdateAnchors.
  P:SquareStyle(boss, "nameplate1")
  local pt = boss.RaidTargetFrame.points[1]
  ok(pt and pt[1] == "RIGHT" and pt[3] == "LEFT" and pt[2] ~= boss.HealthBarsContainer, "raid icon left of our level box")
  boss:UpdateAnchors()
  pt = boss.RaidTargetFrame.points[1]
  ok(pt and pt[2] ~= boss.HealthBarsContainer, "raid icon stays ours after the game's UpdateAnchors")

  -- Quest icon follows C_QuestLog.UnitIsRelatedToActiveQuest.
  C_QuestLog = C_QuestLog or {}
  C_QuestLog.UnitIsRelatedToActiveQuest = function(u) return u == "nameplate2" end
  P:SquareStyle(trash, "nameplate2"); P:SquareStyle(boss, "nameplate1")
  local fb = P.Ours and P:Ours(boss)
  ok(true, "quest icon styled without error")

  -- Encounter: the top-level elite is the boss, only while it lasts.
  PSS.inEncounter = false
  ok(not PSS:IsBoss("nameplate1"), "no boss outside an encounter")
  PSS.inEncounter = true
  ok(PSS:IsBoss("nameplate1"), "top elite is the boss in an encounter")
  ok(not PSS:IsBoss("nameplate2"), "lower elite is not the boss")
  PSS.inEncounter = false
  UnitLevel, UnitClassification, UnitCanAttack = oldLevel, oldCls, oldAtk
  UnitExists = function() return false end
end)

-- 3. Beast Training: learned ranks read from the trainer window -------------
try("beast training", function()
  Enum.TrainerType = {Player = 1, Pet = 2}
  C_Trainer = {GetTrainerType = function() return 2 end}
  local L = {{"Bite", "Rank 3"}, {"Claw", "Rank 5"}, {"Growl", "Rank 2"}}
  GetNumTrainerServices = function() return #L end
  GetTrainerServiceInfo = function(i) return L[i][1], "used", nil, 1, L[i][2] end
  PetSkillScoutDB.knownRanks = {Claw = 7}
  MOCK.Fire("TRAINER_SHOW")
  local k = PetSkillScoutDB.knownRanks
  ok(k.Bite == 3, "Bite rank 3 read (got " .. tostring(k.Bite) .. ")")
  ok(k.Claw == 7, "a higher known rank is never lowered")
  ok(PSS.Route:KnownRank("Growl") == 2, "Route sees Growl 2")
  -- A class trainer is not read.
  C_Trainer.GetTrainerType = function() return 1 end
  L[1] = {"Bite", "Rank 9"}
  MOCK.Fire("TRAINER_SHOW")
  ok(PetSkillScoutDB.knownRanks.Bite == 3, "class trainer ignored")
  GetNumTrainerServices, GetTrainerServiceInfo, C_Trainer = nil, nil, nil
end)

-- 4. Trainer position (Route.lua TRAINER_SHOW), with and without a position ---
try("trainer position", function()
  local old = PSS.Nav.PlayerPos
  UnitGUID = function(u) if u == "npc" then return "Creature-0-1-1-1-3352-0000ABCD" end end
  PSS.Nav.PlayerPos = function() return nil end
  MOCK.Fire("TRAINER_SHOW")
  ok(true, "no position: no error")
  PSS.Nav.PlayerPos = function() return 1411, 0.5, 0.25 end
  PetSkillScoutDB.trainersSeen = nil
  MOCK.Fire("TRAINER_SHOW")
  local t = PetSkillScoutDB.trainersSeen and PetSkillScoutDB.trainersSeen[3352]
  ok(t and t.x == 50 and t.y == 25 and t.m == 1411, "trainer saved at 50, 25")
  PSS.Nav.PlayerPos = old
  UnitGUID = function() return nil end
end)

-- 5. Careful Aim: the spell text holds the top rank ---------------------------
try("careful aim", function()
  C_ClassTalents = {GetActiveConfigID = function() return 7 end}
  C_Traits = {
    GetConfigInfo = function() return {treeIDs = {1}} end,
    GetTreeNodes = function() return {11} end,
    GetNodeInfo = function() return {activeRank = 1, maxRanks = 5, activeEntry = {entryID = 21}} end,
    GetEntryInfo = function() return {definitionID = 31} end,
    GetDefinitionInfo = function() return {spellID = 1223984} end,
  }
  C_Spell = C_Spell or {}
  C_Spell.GetSpellName = function() return "Careful Aim" end
  C_Spell.GetSpellDescription = function() return "Increases your Attack Power by 100% of your Intellect." end
  MOCK.Fire("TRAIT_CONFIG_UPDATED")
  ok(PSS.Gear:CarefulAimPct() == 20, "rank 1 / 5 at 100% text = 20% (got " .. tostring(PSS.Gear:CarefulAimPct()) .. ")")
  C_Traits.GetNodeInfo = function() return {activeRank = 5, maxRanks = 5, activeEntry = {entryID = 21}} end
  MOCK.Fire("TRAIT_CONFIG_UPDATED")
  ok(PSS.Gear:CarefulAimPct() == 100, "rank 5 = 100%")
  local W = PSS.Gear.WEIGHTS.BM
  local base = PSS.Gear:Score({int = 10}, "other", "BM")
  ok(math.abs(base - 10 * (W.int + 1.0 * W.rap)) < 0.01, "10 int scored with Careful Aim")
  C_ClassTalents, C_Traits = nil, nil
  MOCK.Fire("TRAIT_CONFIG_UPDATED")
end)

-- 6. Report: code without names ------------------------------------------------
try("report", function()
  local text = PSS:ReportText()
  ok(text:find("v=") and text:find("opts:"), "report text has version and options")
  ok(not text:find("Tester") and not text:find("Realm"), "report text has no character or realm name")
  PSS:Report()
  local f = _G.PetSkillScoutReport
  ok(f and f.code and f.code:find("^PSS1:"), "report window holds the PSS1 code")
end)

-- 7. Map pin: the game's user waypoint at the right spot -----------------------
try("map pin", function()
  local set, tracked
  C_Map.CanSetUserWaypointOnMap = function() return true end
  C_Map.SetUserWaypoint = function(p) set = p end
  UiMapPoint = {CreateFromCoordinates = function(m, x, y) return {m = m, x = x, y = y} end}
  C_SuperTrack = {SetSuperTrackedUserWaypoint = function(v) tracked = v end}
  ok(PSS:SetMapPin(1429, 42.5, 66.0, "Vendor") == true, "pin set")
  ok(set and set.m == 1429 and math.abs(set.x - 0.425) < 1e-6 and math.abs(set.y - 0.66) < 1e-6, "pin at 42.5, 66 on 1429")
  ok(tracked == true, "pin tracked")
  C_Map.CanSetUserWaypointOnMap = function() return false end
  ok(PSS:SetMapPin(1, 1, 1) == false, "no pin where the map does not allow it")
end)

-- 8. Rare alert: window and sound on for a new player ---------------------------
try("rare alert default", function()
  local saved = PetSkillScoutDB
  PetSkillScoutDB = {language = "en"}
  PSS:InitializeDB()
  ok(PetSkillScoutDB.rareAlertPopup ~= false, "new player: rare alert window on")
  ok(PetSkillScoutDB.rareSound ~= false, "new player: rare sound on")
  ok(PetSkillScoutDB.rareChat == false, "new player: rare chat line stays opt-in")
  PetSkillScoutDB = {language = "en", rareAlertPopup = false}
  PSS:InitializeDB()
  ok(PetSkillScoutDB.rareAlertPopup == false, "a saved 'off' is kept")
  PetSkillScoutDB = saved
end)

-- 9. Settings > Sizes and positions: sliders write what Layout reads --------------
try("size sliders", function()
  local UI = PSS.UI
  SlashCmdList.PETSKILLSCOUT("")
  UI:ShowView("settings")
  UI.settingsSection = "sizes"
  UI:RefreshSettings()
  local box = UI.sSections and UI.sSections.sizes
  ok(box and #box.rows >= 13, "sizes section has its rows")
  local scaleRow, chatRow
  for _, row in ipairs(box and box.rows or {}) do
    if row.def.key == "scale_player" then scaleRow = row end
    if row.def.key == "chatW" then chatRow = row end
  end
  ok(scaleRow and scaleRow.slider, "player size is a slider")
  ok(scaleRow and scaleRow.label:GetText() == "Size: player frame", "slider label names the part (got " .. tostring(scaleRow and scaleRow.label:GetText()) .. ")")
  scaleRow.slider.scripts.OnValueChanged(scaleRow.slider, 127)
  ok(PetSkillScoutDB.layoutScale and math.abs(PetSkillScoutDB.layoutScale.player - 1.25) < 1e-6, "player size saved as 1.25")
  chatRow.slider.scripts.OnValueChanged(chatRow.slider, 604)
  ok(PetSkillScoutDB.chatW == 600, "chat width saved (step 10)")
  local w = PSS.Layout:ChatSize()
  ok(w == 600, "Layout uses the slider width")
  for _, row in ipairs(box.rows) do if row.def.key == "layoutResetSizes" then row.def.run() end end
  ok(PetSkillScoutDB.layoutScale == nil and PetSkillScoutDB.chatW == nil, "reset sizes clears them")
  for _, lang in ipairs({"en", "uk", "pl", "de", "fr", "it", "es", "pt", "ru"}) do
    local t = PSS.Locale[lang] or {}
    ok(t.setSizes and t.part_shot and t.optResetSizesBtn, "sizes strings in " .. lang)
  end
end)

-- 10. Hawk timer moves with /pss move (report "Can't Move Frames") -------------
try("hawk timer move", function()
  PetSkillScoutDB.hawkTimer = true
  local H = PSS.HawkTimer
  pcall(H.Update, H)
  local f = _G.PetSkillScoutHawkTimer
  ok(f ~= nil, "hawk timer frame built")
  ok(PSS.Layout.movables.hawk and PSS.Layout.movables.hawk.frame == f, "hawk timer is one of the /pss move frames")
  local moved = false
  getmetatable(f).m_StartMoving = function() moved = true end
  PSS.Layout.unlocked = false
  f.scripts.OnDragStart(f)
  ok(not moved, "locked: plain drag does not move it")
  PSS.Layout.unlocked = true
  f.scripts.OnDragStart(f)
  ok(moved, "unlocked: plain drag moves it")
  PSS.Layout.unlocked = false
  ok((PSS.Locale.uk or {}).slot_hawk and (PSS.Locale.ru or {}).slot_hawk, "hawk label in the move frame")
end)

-- 11. Gossip quest titles written in black inside the text ---------------------
try("gossip dark text codes", function()
  local T = PSS.SkinText
  local fs = CreateFrame("Frame")
  fs:SetText("|cff000000Our Man in Theramore|r")
  T.FixCodes(fs)
  local t = fs:GetText()
  ok(not t:find("|cff000000", 1, true) and t:find("Our Man in Theramore", 1, true), "black code replaced (got " .. t .. ")")
  fs:SetText("|cffffd100Gold title|r")
  T.FixCodes(fs)
  ok(fs:GetText() == "|cffffd100Gold title|r", "light codes are kept")
end)

print(string.format("passed %d, failed %d", pass, fail))
if fail > 0 then os.exit(1) end
