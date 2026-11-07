-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Pet guard for dungeons: helps you stop the pet from running through the
-- whole instance after you jump down somewhere.
-- * Warning when you drop from a height in a dungeon with your pet following.
-- * Warning when your pet fights far away from you.
-- * Two buttons / key bindings: "Stay + passive" and "To me + passive".
-- Pet commands are protected: the game only allows them from YOUR click or key
-- press, so the addon never commands the pet by itself. It only shows the
-- warning and the buttons.
local PSS = PetSkillScout
PSS.PetGuard = {}
local G = PSS.PetGuard
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local STAY, FOLLOW, DEFENSIVE = "PetSkillScoutPetStay", "PetSkillScoutPetFollow", "PetSkillScoutPetDefensive"
local FALL_SECONDS = 1.8     -- longer than a jump or a small drop
local SHOW_SECONDS = 8
local STEP_SECONDS = 25      -- each step of the after-jump helper
local DISMISS_PET, CALL_PET = 2641, 883

-- Key binding labels (Bindings.xml).
BINDING_HEADER_PETSKILLSCOUT = "PetSkillScout"
_G["BINDING_NAME_CLICK " .. STAY .. ":LeftButton"] = "Pet: stay + passive"
_G["BINDING_NAME_CLICK " .. FOLLOW .. ":LeftButton"] = "Pet: to me + passive"

local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end
local function Plain(v) if PSS.IsSecret and PSS.IsSecret(v) then return nil end return v end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Opt(key) return not PetSkillScoutDB or PetSkillScoutDB[key] ~= false end
local function Quiet() return PetSkillScoutDB and PetSkillScoutDB.guardQuiet == true end

local function HasPet()
  return Plain(safe(UnitExists, "pet")) and not Plain(safe(UnitIsDead, "pet"))
end
local function InDungeon()
  local inside, kind = safe(IsInInstance)
  return inside and (kind == "party" or kind == "raid")
end
-- "stay" / "follow" / nil from the pet action bar.
local function PetMode()
  if type(GetPetActionInfo) ~= "function" then return nil end
  for slot = 1, 10 do
    -- name, texture, isToken, isActive: for commands the name is the token.
    local ok, name, _, _, active = pcall(GetPetActionInfo, slot)
    local id = ok and Plain(name)
    if ok and Plain(active) == true and type(id) == "string" then
      if id:find("WAIT") then return "stay" end
      if id:find("FOLLOW") then return "follow" end
    end
  end
end
-- "aggressive" / "defensive" / "passive" / nil
local function PetStance()
  if type(GetPetActionInfo) ~= "function" then return nil end
  for slot = 1, 10 do
    local ok, name, _, _, active = pcall(GetPetActionInfo, slot)
    local id = ok and Plain(name)
    if ok and Plain(active) == true and type(id) == "string" then
      if id:find("AGGRESSIVE") then return "aggressive" end
      if id:find("DEFENSIVE") then return "defensive" end
      if id:find("PASSIVE") then return "passive" end
    end
  end
end
G.PetStance = PetStance

local function SpellName(id, fallback)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = safe(C_Spell.GetSpellInfo, id)
    if type(info) == "table" and info.name then return info.name end
  end
  return safe(GetSpellInfo, id) or fallback
end

-- true = pet is far, false = near, nil = the client cannot tell.
-- Exact distance where the client gives it, otherwise the 40 yd party range;
-- the 28 yd interact range fired on any normal pull. See G.FAR_HOLD too.
G.FAR_YARDS, G.FAR_HOLD = 70, 4
local function PetFar()
  if UnitDistanceSquared then
    local ok0, sq, seen = pcall(UnitDistanceSquared, "pet")
    sq, seen = ok0 and Plain(sq), ok0 and Plain(seen)
    if seen and type(sq) == "number" then return sq > G.FAR_YARDS * G.FAR_YARDS end
  end
  -- The party range check alone can say "out of range" for a pet right next
  -- to you: the 28 yd interact check must agree, and without both no alert.
  local ok2, inRange, checked = pcall(UnitInRange, "pet")
  inRange, checked = ok2 and Plain(inRange), ok2 and Plain(checked)
  local ok3, near = pcall(CheckInteractDistance, "pet", 4)
  if ok3 then near = Plain(near) else near = nil end -- failed check: unknown, not far
  return G.BothFar(inRange, checked, near)
end
function G.BothFar(inRange, checked, near)
  if not checked or near == nil then return nil end
  return inRange == false and near == false
end

local function KeyText(button)
  local key = safe(GetBindingKey, "CLICK " .. button .. ":LeftButton")
  return key and ((GetBindingText and safe(GetBindingText, key)) or key) or nil
end

-- Secure buttons -------------------------------------------------------------
local buttons = {}
local function SetupAttributes(b)
  if InCombat() then G.pendingSetup = true return end
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", b.macro)
end

local function MakeButton(name, macro, icon, xOffset)
  local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
  b:SetSize(150, 44)
  b:SetFrameStrata("HIGH")
  b:SetClampedToScreen(true)
  b:SetMovable(true)
  -- Key bindings arrive as a down or an up click depending on the client
  -- setting; the commands are harmless when repeated.
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:RegisterForDrag("LeftButton")
  b.macro = macro
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture(WHITE)
  bg:SetVertexColor(0.05, 0.09, 0.07, 0.94)
  bg:SetAllPoints(b)
  b.edges = {}
  for _, def in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},{"TOPLEFT","BOTTOMLEFT"},{"TOPRIGHT","BOTTOMRIGHT"}}) do
    local t = b:CreateTexture(nil, "BORDER")
    t:SetTexture(WHITE)
    t:SetVertexColor(0.85, 0.70, 0.43, 1)
    t:SetPoint(def[1], b, def[1], 0, 0)
    t:SetPoint(def[2], b, def[2], 0, 0)
    if def[3] then t:SetHeight(2) else t:SetWidth(2) end
    table.insert(b.edges, t)
  end
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetTexture(WHITE)
  hl:SetVertexColor(1, 1, 1, 0.12)
  hl:SetAllPoints(b)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetTexture(icon)
  b.icon:SetSize(30, 30)
  b.icon:SetPoint("LEFT", b, "LEFT", 7, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.label = b:CreateFontString(nil, "OVERLAY")
  b.label:SetFont(FONT, 13, "")
  b.label:SetTextColor(0.96, 0.89, 0.78)
  b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 44, -6)
  b.key = b:CreateFontString(nil, "OVERLAY")
  b.key:SetFont(FONT, 10, "")
  b.key:SetTextColor(0.66, 0.74, 0.67)
  b.key:SetPoint("TOPLEFT", b, "TOPLEFT", 44, -25)
  b:SetPoint("CENTER", UIParent, "CENTER", xOffset, 170)
  b:SetScript("OnDragStart", function(self)
    if not InCombat() and IsShiftKeyDown and IsShiftKeyDown() then
      G.dragging = self
      buttons[1]:StartMoving()
    end
  end)
  b:SetScript("OnDragStop", function()
    buttons[1]:StopMovingOrSizing()
    G.dragging = nil
    local x, y = buttons[1]:GetCenter()
    if PetSkillScoutDB and x then PetSkillScoutDB.guardPos = {x = x, y = y} end
  end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("PetSkillScout")
    GameTooltip:AddLine(PSS:Safe(PSS:L("guardDragHint")), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  SetupAttributes(b)
  return b
end

local banner
local function CreateUI()
  if buttons[1] then return end
  buttons[1] = MakeButton(STAY, "/petstay\n/petpassive", "Interface\\Icons\\Ability_Hunter_Pet_Bear", -78)
  buttons[2] = MakeButton(FOLLOW, "/petfollow\n/petpassive", "Interface\\Icons\\Ability_Tracking", 78)
  -- The follow button hangs off the stay button so both move together.
  buttons[2]:ClearAllPoints()
  buttons[2]:SetPoint("LEFT", buttons[1], "RIGHT", 6, 0)
  buttons[3] = MakeButton(DEFENSIVE, "/petdefensive", "Interface\\Icons\\Ability_Defend", 0)
  buttons[3]:ClearAllPoints()
  buttons[3]:SetPoint("TOP", buttons[1], "BOTTOM", 78, -6)
  local pos = PetSkillScoutDB and PetSkillScoutDB.guardPos
  if pos and pos.x then
    buttons[1]:ClearAllPoints()
    buttons[1]:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
  end
  -- Warning text (not secure: it can be shown at any time, also in combat).
  banner = CreateFrame("Frame", nil, UIParent)
  banner:SetSize(520, 54)
  banner:SetFrameStrata("HIGH")
  banner:SetPoint("BOTTOM", buttons[1], "TOP", 78, 8)
  banner.text = banner:CreateFontString(nil, "OVERLAY")
  banner.text:SetFont(FONT, 18, "OUTLINE")
  banner.text:SetTextColor(1, 0.55, 0.30)
  banner.text:SetPoint("TOP", banner, "TOP", 0, 0)
  banner.text:SetWidth(520)
  banner.sub = banner:CreateFontString(nil, "OVERLAY")
  banner.sub:SetFont(FONT, 12, "OUTLINE")
  banner.sub:SetTextColor(0.9, 0.9, 0.9)
  banner.sub:SetPoint("TOP", banner.text, "BOTTOM", 0, -4)
  banner.sub:SetWidth(520)
  banner:Hide()
end

-- Step helper after a jump: the "Stay" button (and its key) changes to
-- Stay -> Dismiss Pet -> Call Pet, so you press the same key three times.
local STEPS = {
  stay = {macro = function() return "/petstay\n/petpassive" end, label = "guardStay",
    icon = "Interface\\Icons\\Ability_Hunter_Pet_Bear", text = "guardFallMsg"},
  dismiss = {macro = function() return "/cast " .. SpellName(DISMISS_PET, "Dismiss Pet") end, label = "guardDismiss",
    icon = "Interface\\Icons\\Spell_Nature_SpiritWolf", text = "guardStepDismiss"},
  call = {macro = function() return "/cast " .. SpellName(CALL_PET, "Call Pet") end, label = "guardCall",
    icon = "Interface\\Icons\\Ability_Hunter_BeastCall", text = "guardStepCall"},
}
G.step = "stay"

local function UpdateLabels()
  if not buttons[1] then return end
  local step = STEPS[G.step] or STEPS.stay
  buttons[1].label:SetText(PSS:L(step.label))
  buttons[1].icon:SetTexture(step.icon)
  buttons[2].label:SetText(PSS:L("guardFollow"))
  buttons[3].label:SetText(PSS:L("guardDefensive"))
  for _, b in ipairs(buttons) do
    local key = KeyText(b:GetName())
    b.key:SetText(key and string.format(PSS:L("guardKey"), key) or (b == buttons[3] and "" or PSS:L("guardNoKeyShort")))
  end
  _G["BINDING_NAME_CLICK " .. STAY .. ":LeftButton"] = PSS:L("bindStay")
  _G["BINDING_NAME_CLICK " .. FOLLOW .. ":LeftButton"] = PSS:L("bindFollow")
end

local hideAt = 0
local function Now() return GetTime and GetTime() or 0 end
local function Glow(hot)
  for _, b in ipairs(buttons) do
    for _, e in ipairs(b.edges) do
      if b == hot then e:SetVertexColor(1, 0.55, 0.30, 1) else e:SetVertexColor(0.85, 0.70, 0.43, 1) end
    end
  end
end
local function Banner(title, sub, seconds)
  banner.text:SetText(title)
  banner.sub:SetText(sub or "")
  banner:Show()
  hideAt = Now() + (seconds or SHOW_SECONDS)
end
local function ShowButtons(list)
  if InCombat() or Quiet() then return end
  for _, b in ipairs(buttons) do
    local on = false
    for _, x in ipairs(list) do if x == b then on = true end end
    if on then b:Show() else b:Hide() end
  end
end

-- Changes the Stay button to a step. Secure attributes cannot change in
-- combat; then the step is applied right after the fight.
function G:SetStep(step)
  step = STEPS[step] and step or "stay"
  if InCombat() then G.pendingStep = step return false end
  G.pendingStep = nil
  G.step = step
  buttons[1].macro = STEPS[step].macro()
  SetupAttributes(buttons[1])
  UpdateLabels()
  return true
end

local function StepBanner()
  local step = STEPS[G.step] or STEPS.stay
  local key = KeyText(STAY)
  local sub = key and string.format(PSS:L("guardStepKey"), key) or PSS:L("guardNoKey")
  Banner(PSS:L(step.text), sub, STEP_SECONDS)
  ShowButtons({buttons[1], buttons[2]})
  Glow(buttons[1])
end

function G:EndFlow(done)
  G.flow = false
  G:SetStep("stay")
  if done and banner then
    Banner(PSS:L("guardDone"), "", 3)
    ShowButtons({})
  else
    G:HideAlert()
  end
end

function G:Alert(kind)
  CreateUI()
  UpdateLabels()
  local stayKey, followKey = KeyText(STAY), KeyText(FOLLOW)
  if Opt("guardSound") and PlaySound then pcall(PlaySound, 8959) end
  if kind == "fall" then
    if not Quiet() and G:SetStep("stay") then
      G.flow, G.landedFor = true, 0
      StepBanner()
    else
      Banner(PSS:L("guardFallMsg"), stayKey and string.format(PSS:L("guardPressKey"), stayKey) or PSS:L("guardNoKey"))
    end
  elseif kind == "aggressive" then
    Banner(PSS:L("guardAggressiveMsg"), PSS:L("guardAggressiveSub"), 12)
    ShowButtons({buttons[3]})
    Glow(buttons[3])
  else
    Banner(PSS:L("guardAggroMsg"), (followKey or stayKey) and string.format(PSS:L("guardPressKey2"), followKey or "-", stayKey or "-")
      or PSS:L("guardNoKey"))
    ShowButtons({buttons[1], buttons[2]})
    Glow(buttons[2])
  end
end

function G:HideAlert()
  if banner then banner:Hide() end
  if InCombat() then G.pendingHide = true return end
  G.pendingHide = false
  for _, b in ipairs(buttons) do b:Hide() end
end

function G:Test(kind) self:Alert(kind or "fall") end

-- Aggressive stance reminder: once per dungeon visit (and again if the pet
-- is switched back to aggressive).
local remindedStance
local function CheckStance()
  if not (Opt("guardAggressive") and InDungeon() and HasPet()) then
    if not InDungeon() then remindedStance = nil end
    return
  end
  local stance = PetStance()
  if stance == "aggressive" and remindedStance ~= "aggressive" then
    remindedStance = "aggressive"
    G:Alert("aggressive")
  elseif stance and stance ~= "aggressive" then
    remindedStance = stance
    if banner and banner:IsShown() and buttons[3]:IsShown() then G:HideAlert() end
  end
end
G.CheckStance = CheckStance

-- Detection ------------------------------------------------------------------
local fallTime, fallAlerted = 0, false
local lastAggroAlert = -1e9
local tick = 0
local driver = CreateFrame("Frame")
local dungeonCheck, inDungeon = 0, false
-- Outside dungeons the per-frame watcher is switched off entirely.
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(1, function()
    local want = (InDungeon() and true or false) or G.flow or (banner and banner:IsShown())
    driver:SetShown(want and true or false)
  end)
end
local sinceCheck = 0
driver:SetScript("OnUpdate", function(_, elapsed)
  -- 10 checks a second are enough for a fall that takes over a second.
  sinceCheck = sinceCheck + (elapsed or 0)
  if sinceCheck < 0.1 then return end
  elapsed, sinceCheck = sinceCheck, 0
  -- Outside dungeons there is nothing to watch: check that once a second only.
  dungeonCheck = dungeonCheck - elapsed
  if dungeonCheck <= 0 then dungeonCheck = 1; inDungeon = InDungeon() and true or false end
  if not inDungeon and not G.flow and not (banner and banner:IsShown()) then return end
  local now = Now()
  if banner and banner:IsShown() and now > hideAt and not G.dragging then
    if G.flow then G:EndFlow(false) else G:HideAlert() end
  end
  -- Falling.
  local falling = Plain(safe(IsFalling)) and not Plain(safe(UnitOnTaxi, "player"))
  if Opt("guardFall") and falling then
    fallTime = fallTime + elapsed
    if not fallAlerted and fallTime >= FALL_SECONDS and InDungeon() and HasPet() and PetMode() ~= "stay" then
      fallAlerted = true
      G:Alert("fall")
    end
  else
    fallTime, fallAlerted = 0, false
  end
  -- After landing: Stay -> Dismiss Pet.
  if G.flow and G.step == "stay" and not falling then
    G.landedFor = (G.landedFor or 0) + elapsed
    if G.landedFor > 0.4 then
      if HasPet() then
        if G:SetStep("dismiss") then StepBanner() end
      else
        if G:SetStep("call") then StepBanner() end
      end
    end
  end
  -- Pet fighting far away: twice a second.
  tick = tick + elapsed
  if tick < 0.5 then return end
  tick = 0
  if Opt("guardAggro") and not G.flow and InDungeon() and HasPet() and Plain(safe(UnitAffectingCombat, "pet")) then
    local far = PetFar()
    -- Only a pet that stays away counts, not one running to a pull.
    if not far then G.farSince = nil elseif not G.farSince then G.farSince = now end
    if far and now - G.farSince >= G.FAR_HOLD and now - lastAggroAlert > 15 then
      lastAggroAlert = now
      G:Alert("aggro")
    end
  end
end)

-- Pet gone / back: advance the helper.
local function OnPetChanged()
  if G.flow then
    if G.step == "dismiss" and not HasPet() then
      if G:SetStep("call") then StepBanner() end
    elseif G.step == "call" and HasPet() then
      G:EndFlow(true)
    end
  end
  CheckStance()
end

local events = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_REGEN_ENABLED", "PLAYER_LOGIN", "UPDATE_BINDINGS", "UNIT_PET", "PET_BAR_UPDATE",
                    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA"}) do
  pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" then CreateUI(); UpdateLabels() return end
  if event == "UPDATE_BINDINGS" then UpdateLabels() return end
  if event == "UNIT_PET" then
    if unit == "player" then OnPetChanged() end
    return
  end
  if event == "PET_BAR_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    CheckStance()
    return
  end
  -- PLAYER_REGEN_ENABLED: apply what combat blocked.
  if G.pendingSetup then
    G.pendingSetup = false
    for _, b in ipairs(buttons) do SetupAttributes(b) end
  end
  if G.pendingStep then
    if G:SetStep(G.pendingStep) and G.flow then StepBanner() end
  end
  if G.pendingHide then G:HideAlert() end
  CheckStance()
end)
CreateUI()

-- Settings page helper: current key bindings as text.
function G:KeysText()
  local stay, follow = KeyText(STAY), KeyText(FOLLOW)
  return string.format(PSS:L("guardKeysNow"), stay or PSS:L("guardNoKeyShort"), follow or PSS:L("guardNoKeyShort"))
end
