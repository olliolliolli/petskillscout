-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- One-button rotations (beta, off by default, theme only), close to the retail
-- Assisted Combat where the game allows it to addons:
--  * two buttons above the cooldown manager (single target / several
--    targets). Each is a macro of the game's own commands: /castsequence
--    ("in turn": every press casts the next spell) or a /cast list
--    ("priority": the first spell that is ready - the game skips spells on
--    cooldown). The player presses; the addon never casts by itself (choosing
--    a spell in combat is reserved to the game).
--  * an advisor, like retail's Assisted Highlight: it looks at cooldowns, your
--    debuffs on the target, live hawks, enemies around and range, picks the
--    best spell by the guides' priority and highlights it on your action bars
--    and on our buttons. Display only.
--  * the icon shows what the next press casts (QueryCastSequence,
--    Blizzard_ChatFrameBase/Shared/CastSequenceManager.lua), with the cooldown
--    swipe, red when out of range, and the bound key.
--  * /petattack on each press sends the pet at your target.
--  * an editor for the spell lists (/pss rotation).
-- Lists from WoW Forever hunter guides (wowtbc.gg Forever BM / MM / SV,
-- Warcraft Tavern Forever leveling). The guides have no multi-target
-- rotation: those lists are ours (Multi-Shot first).
local PSS = PetSkillScout
PSS.Rotation = {}
local R = PSS.Rotation

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
local RESET = "reset=target/combat/8"
local SPELL = {
  ["Hunter's Mark"] = 1130, ["Serpent Sting"] = 1978, ["Arcane Shot"] = 3044, ["Aimed Shot"] = 19434,
  ["Multi-Shot"] = 2643, ["Raptor Strike"] = 2973, ["Mongoose Bite"] = 1495,
}
-- Debuffs we keep up and how long they last when the game hides auras.
local DOT = {["Hunter's Mark"] = 120, ["Serpent Sting"] = 15}

R.LISTS = {
  BM = {single = {"Hunter's Mark", "Serpent Sting", "Summon Hawk", "Aimed Shot", "Summon Hawk", "Arcane Shot"},
        aoe = {"Multi-Shot", "Summon Hawk", "Multi-Shot", "Arcane Shot"}},
  MM = {single = {"Hunter's Mark", "Serpent Sting", "Arcane Shot", "Aimed Shot", "Sniper Shot", "Arcane Shot"},
        aoe = {"Multi-Shot", "Serpent Sting", "Multi-Shot", "Arcane Shot"}},
  SV = {single = {"Hunter's Mark", "Serpent Sting", "Arcane Shot", "Multi-Shot", "Arcane Shot"},
        aoe = {"Multi-Shot", "Serpent Sting", "Multi-Shot", "Arcane Shot"}},
}
-- Advisor priority (the guides' order; conditions checked live).
R.PRIO = {
  BM = {"Hunter's Mark", "Serpent Sting", "Summon Hawk", "Aimed Shot", "Arcane Shot"},
  MM = {"Hunter's Mark", "Serpent Sting", "Arcane Shot", "Aimed Shot", "Sniper Shot"},
  SV = {"Hunter's Mark", "Raptor Strike", "Mongoose Bite", "Serpent Sting", "Arcane Shot", "Multi-Shot"},
}

local function DB() return PetSkillScoutDB or {} end
local function L(k) return PSS:L(k) end
local function Plain(v) if PSS.IsSecret and PSS.IsSecret(v) then return nil end return v end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Now() return GetTime and GetTime() or 0 end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

function R:Enabled()
  local _, class = UnitClass("player")
  return class == "HUNTER" and DB().rotationBeta == true and PSS.Skin and PSS.Skin.active
end
function R:Spec()
  local spec = DB().rotationSpec
  if spec ~= "BM" and spec ~= "MM" and spec ~= "SV" then
    spec = PSS.Gear and PSS.Gear.Spec and PSS.Gear:Spec() or "BM"
  end
  return spec
end
function R:Mode() return DB().rotationMode == "prio" and "prio" or "seq" end

-- Local name of a spell the player has learned (nil when not learned).
local known = {}
local function Known(name)
  local id = SPELL[name] or (name == "Summon Hawk" and DB().hawkSpell)
  local info = id and C_Spell and C_Spell.GetSpellInfo and Call(C_Spell.GetSpellInfo, id)
  local loc = (type(info) == "table" and Plain(info.name)) or name
  local fn = C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell
  if fn then return Call(fn, loc) and loc or nil end
  if GetSpellInfo and Call(GetSpellInfo, loc) then return loc end
end
local function Learned(name)
  local v = known[name]
  if v == nil then v = Known(name) or false; known[name] = v end
  return v or nil
end

function R:List(kind)
  local spec = self:Spec()
  local custom = DB().rotationCustom and DB().rotationCustom[spec] and DB().rotationCustom[spec][kind]
  if type(custom) == "table" and #custom > 0 then return custom end
  return (self.LISTS[spec] or self.LISTS.BM)[kind]
end

-- Macro text for a button.
function R:Macro(kind)
  local out, seen = {}, {}
  for _, n in ipairs(self:List(kind)) do
    local loc = Learned(n)
    if loc then out[#out + 1] = loc end
  end
  if #out == 0 then return nil end
  local lines = {"/petattack"}
  if self:Mode() == "prio" then
    -- Debuffs and hawks have no cooldown: in a /cast list they would be cast
    -- on every press, so the priority list takes the shots only.
    for _, loc in ipairs(out) do
      if not seen[loc] and not DOT[loc] and loc ~= Learned("Summon Hawk") then
        seen[loc] = true
        lines[#lines + 1] = "/cast " .. loc
      end
    end
    if #lines == 1 then lines[#lines + 1] = "/cast " .. out[1] end
    self.seqs = self.seqs or {}
    self.seqs[kind] = nil
  else
    local seq = RESET .. " " .. table.concat(out, ", ")
    lines[#lines + 1] = "/castsequence " .. seq
    self.seqs = self.seqs or {}
    self.seqs[kind] = seq
  end
  return table.concat(lines, "\n"), out
end

-- Buttons -------------------------------------------------------------------
local buttons = {}
local function Edge(b, w, c)
  for i = 1, 4 do
    b.edge[i]:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    if i <= 2 then b.edge[i]:SetHeight(w) else b.edge[i]:SetWidth(w) end
  end
end
local function MakeEdge(owner, layer)
  local e = {}
  for i = 1, 4 do e[i] = owner:CreateTexture(nil, layer or "OVERLAY"); e[i]:SetTexture(FLAT) end
  e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT")
  e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT")
  e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT")
  e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT")
  return e
end
local NAMES = {single = "PetSkillScoutRotSingle", aoe = "PetSkillScoutRotAoE"}
local function Make(kind)
  local name = NAMES[kind]
  local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
  b:SetSize(40, 40)
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("type", "macro")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b.icon)
  pcall(b.cd.SetDrawEdge, b.cd, false)
  pcall(b.cd.SetHideCountdownNumbers, b.cd, false)
  pcall(b.cd.SetSwipeColor, b.cd, 0, 0, 0, 0.65)
  b.edge = MakeEdge(b)
  b.label = b:CreateFontString(nil, "OVERLAY")
  b.label:SetFont(FONT, 10, "OUTLINE")
  b.label:SetPoint("BOTTOM", b, "TOP", 0, 2)
  b.key = b:CreateFontString(nil, "OVERLAY")
  b.key:SetFont(FONT, 9, "OUTLINE")
  b.key:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -2)
  b.kind = kind
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L(kind == "single" and "rotSingle" or "rotAoE"))
    if self.spells then GameTooltip:AddLine(table.concat(self.spells, " > "), 1, 1, 1, true) end
    GameTooltip:AddLine(L(R:Mode() == "prio" and "rotTipPrio" or "rotTip"), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  buttons[kind] = b
  _G["BINDING_NAME_CLICK " .. name .. ":LeftButton"] = L(kind == "single" and "rotSingle" or "rotAoE")
  return b
end

local function KeyText(kind)
  local key = GetBindingKey and GetBindingKey("CLICK " .. NAMES[kind] .. ":LeftButton")
  if not key then return "" end
  local t = (GetBindingText and GetBindingText(key, true)) or key
  return (t:gsub("SHIFT%-", "s"):gsub("CTRL%-", "c"):gsub("ALT%-", "a"))
end

-- Macro text and place: out of combat only (secure buttons).
function R:Apply()
  if InCombat() then self.pending = true; return end
  self.pending = nil
  known = {}
  local on = self:Enabled()
  for _, kind in ipairs({"single", "aoe"}) do
    local b = buttons[kind] or Make(kind)
    local text, spells
    if on then text, spells = self:Macro(kind) end
    b.spells = spells
    if text then
      b:SetAttribute("macrotext", text)
      b.label:SetText(L(kind == "single" and "rotSingleShort" or "rotAoEShort"))
      b.key:SetText(KeyText(kind))
      b:Show()
    else
      b:SetAttribute("macrotext", nil)
      b:Hide()
    end
  end
  self:Place()
  self:Paint()
end

function R:Place()
  if InCombat() then return end
  local holder = PSS.Layout and PSS.Layout.barHolderFrame
  local y = (PSS.Layout and PSS.Layout.cdmTopY or 200) + 22
  for i, kind in ipairs({"single", "aoe"}) do
    local b = buttons[kind]
    if b then
      b:ClearAllPoints()
      if holder then b:SetPoint("BOTTOM", holder, "BOTTOM", (i == 1 and -24 or 24), y)
      else b:SetPoint("BOTTOM", UIParent, "BOTTOM", (i == 1 and -24 or 24), 260) end
      b:SetFrameStrata("MEDIUM")
    end
  end
end

-- Advisor -------------------------------------------------------------------
-- Hostile nameplates on screen.
local function Enemies()
  local n = 0
  local list = C_NamePlate and C_NamePlate.GetNamePlates and Call(C_NamePlate.GetNamePlates) or {}
  for _, p in ipairs(list) do
    local u = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
    if u and Plain(Call(UnitCanAttack, "player", u)) and not Plain(Call(UnitIsDead, u)) then n = n + 1 end
  end
  return n
end
R.Enemies = Enemies

-- Seconds of cooldown left (0 = ready; the global cooldown counts as ready).
local function CooldownLeft(loc)
  local fn = C_Spell and C_Spell.GetSpellCooldown
  local s, d
  if fn then
    local cd = Call(fn, loc)
    if type(cd) == "table" then s, d = Plain(cd.startTime), Plain(cd.duration) end
  elseif GetSpellCooldown then
    s, d = Call(GetSpellCooldown, loc)
    s, d = Plain(s), Plain(d)
  end
  if type(s) ~= "number" or type(d) ~= "number" or d <= 1.6 or s == 0 then return 0, s, d end
  return math.max(0, s + d - Now()), s, d
end
local function Usable(loc)
  local fn = C_Spell and C_Spell.IsSpellUsable or IsUsableSpell
  local ok, noMana = Call(fn, loc)
  ok, noMana = Plain(ok), Plain(noMana)
  if ok == nil then return true end
  return ok and not noMana
end
local function InRange(loc)
  local fn = C_Spell and C_Spell.IsSpellInRange or IsSpellInRange
  local r = Plain(Call(fn, loc, "target"))
  if r == nil then return nil end
  return r == true or r == 1
end

-- Our debuffs on the target: from the game when it shows them, else from
-- our own casts (target GUID + time).
local casts = {}
local function HasDebuff(loc, eng)
  local fn = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
  if fn then
    local ok, a = pcall(fn, "target", loc, "HARMFUL|PLAYER")
    if ok and not (PSS.IsSecret and PSS.IsSecret(a)) then
      if a ~= nil then return true end
      if R.aurasReadable then return false end
    end
  end
  local guid = Plain(UnitGUID and UnitGUID("target"))
  local c = guid and casts[guid .. loc]
  return c and Now() - c < (DOT[eng] or 15) or false
end

local function LiveHawks()
  local H, n = PSS.HawkTimer, 0
  for _, t in ipairs(H and H.hawks or {}) do if t > Now() then n = n + 1 end end
  return n
end

-- Best spell now (English name, local name), by the spec's priority.
function R:Advise()
  if not (UnitExists("target") and Plain(UnitCanAttack("player", "target"))) then return nil end
  local spec = self:Spec()
  local many = Enemies() >= 3
  local order = {}
  if many then order[1] = "Multi-Shot"; if spec == "BM" then order[2] = "Summon Hawk" end end
  for _, n in ipairs(self.PRIO[spec] or self.PRIO.BM) do order[#order + 1] = n end
  for _, eng in ipairs(order) do
    local loc = Learned(eng)
    if loc and Usable(loc) and CooldownLeft(loc) <= 0.3 then
      local range = InRange(loc)
      local good = true
      if DOT[eng] then good = not HasDebuff(loc, eng) end
      if eng == "Summon Hawk" then good = LiveHawks() < 2 end
      if (eng == "Raptor Strike" or eng == "Mongoose Bite") and range ~= true then good = false end
      if good and range ~= false then return eng, loc end
    end
  end
end

-- Highlight on the action bars (our own border on the button, like retail's
-- Assisted Highlight; nothing secure is touched).
local BAR_PREFIX = {"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
  "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button"}
local marks, lit = {}, {}
local function SpellOfButton(btn)
  local slot = btn.action or (btn.GetAttribute and btn:GetAttribute("action"))
  slot = Plain(slot)
  if type(slot) ~= "number" then return nil end
  local t, id = Call(GetActionInfo, slot)
  if Plain(t) == "spell" then return Plain(id) end
  if Plain(t) == "macro" and GetMacroSpell then return Plain(Call(GetMacroSpell, Plain(id))) end
end
local function Mark(btn, on, col)
  local m = marks[btn]
  if not m then
    if not on then return end
    m = CreateFrame("Frame", nil, btn)
    m:SetAllPoints(btn)
    m:SetFrameLevel((btn:GetFrameLevel() or 1) + 5)
    m.edge = MakeEdge(m)
    marks[btn] = m
  end
  if on then
    for i = 1, 4 do
      m.edge[i]:SetVertexColor(col[1], col[2], col[3], 1)
      if i <= 2 then m.edge[i]:SetHeight(3) else m.edge[i]:SetWidth(3) end
    end
    m:Show()
  else
    m:Hide()
  end
end
local function SpellID(loc)
  local info = C_Spell and C_Spell.GetSpellInfo and Call(C_Spell.GetSpellInfo, loc)
  return type(info) == "table" and Plain(info.spellID) or nil
end
function R:Highlight(loc, col)
  local want = loc and SpellID(loc)
  for btn in pairs(lit) do Mark(btn, false); lit[btn] = nil end
  if not want then return end
  for _, pre in ipairs(BAR_PREFIX) do
    for i = 1, 12 do
      local btn = _G[pre .. i]
      if btn and btn:IsVisible() and SpellOfButton(btn) == want then Mark(btn, true, col); lit[btn] = true end
    end
  end
end

function R:Paint()
  local col = PSS.Skin and PSS.Skin.colours or {}
  local edge = col.edge or {0.55, 0.45, 0.3, 1}
  local acc = col.accent or {0.86, 0.7, 0.35, 1}
  local fight = UnitAffectingCombat("player")
  local many = Enemies() >= 3
  local eng, rec
  if fight then eng, rec = self:Advise() end
  self.advice = rec
  for kind, b in pairs(buttons) do
    if b:IsShown() then
      local spell
      if self:Mode() == "seq" and self.seqs and self.seqs[kind] then
        local _, _, s = QueryCastSequence(self.seqs[kind])
        spell = s
      else
        -- Priority: the first spell of the list that is ready.
        for _, loc in ipairs(b.spells or {}) do
          if not DOT[loc] and CooldownLeft(loc) <= 0.3 and Usable(loc) then spell = loc; break end
        end
        spell = spell or (b.spells and b.spells[#b.spells])
      end
      local tex = spell and spell ~= "" and (C_Spell and C_Spell.GetSpellTexture and Call(C_Spell.GetSpellTexture, spell)
        or (GetSpellTexture and Call(GetSpellTexture, spell)))
      b.icon:SetTexture(Plain(tex) or "Interface\\Icons\\INV_Misc_QuestionMark")
      -- Cooldown swipe and range.
      -- Swipe for the global cooldown and for the spell's own cooldown
      -- (the game reports either one for the spell).
      local _, s, d
      if spell and spell ~= "" then _, s, d = CooldownLeft(spell) end
      if type(s) == "number" and type(d) == "number" and s > 0 and d > 0 and s + d > Now() then
        if b.cdS ~= s or b.cdD ~= d then b.cd:SetCooldown(s, d); b.cdS, b.cdD = s, d end
      elseif b.cdS then
        b.cd:Clear(); b.cdS, b.cdD = nil, nil
      end
      local range = spell and spell ~= "" and UnitExists("target") and InRange(spell)
      if range == false then b.icon:SetVertexColor(1, 0.3, 0.3) else b.icon:SetVertexColor(1, 1, 1) end
      -- Border: accent when this button holds the advised spell, or for AoE
      -- when 3+ enemies fight around you.
      local glow = fight and ((rec and spell and strlower(rec) == strlower(spell)) or (kind == "aoe" and many))
      Edge(b, glow and 2 or 1, glow and acc or edge)
    end
  end
  if DB().rotationHighlight ~= false and self:Enabled() then self:Highlight(fight and rec, acc) else self:Highlight(nil) end
end

-- Editor ------------------------------------------------------------------------
function R:Edit()
  local f = self.editor
  if not f then
    f = CreateFrame("Frame", "PetSkillScoutRotEditor", UIParent, "BackdropTemplate")
    f:SetSize(460, 210); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if PSS.Skin and PSS.Skin.Backdrop then PSS.Skin:Backdrop(f, "window") end
    f.title = f:CreateFontString(nil, "OVERLAY"); f.title:SetFont(FONT, 13, "OUTLINE"); f.title:SetPoint("TOP", 0, -10)
    f.boxes = {}
    for i, kind in ipairs({"single", "aoe"}) do
      local lab = f:CreateFontString(nil, "OVERLAY"); lab:SetFont(FONT, 11, ""); lab:SetPoint("TOPLEFT", 14, -24 - i * 44)
      lab:SetText(L(kind == "single" and "rotSingle" or "rotAoE"))
      local e = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
      e:SetSize(420, 22); e:SetPoint("TOPLEFT", 20, -40 - i * 44); e:SetAutoFocus(false); e:SetFontObject("ChatFontNormal")
      f.boxes[kind] = e
    end
    local function Btn(text, x, fn)
      local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
      b:SetSize(120, 24); b:SetPoint("BOTTOM", x, 12); b:SetText(text); b:SetScript("OnClick", fn)
    end
    Btn(L("rotSave"), -130, function()
      local spec = R:Spec()
      PetSkillScoutDB.rotationCustom = PetSkillScoutDB.rotationCustom or {}
      PetSkillScoutDB.rotationCustom[spec] = {}
      for kind, e in pairs(f.boxes) do
        local list = {}
        for part in (e:GetText() .. ","):gmatch("%s*(.-)%s*,") do if part ~= "" then list[#list + 1] = part end end
        PetSkillScoutDB.rotationCustom[spec][kind] = list
      end
      R:Apply(); f:Hide()
    end)
    Btn(L("rotDefault"), 0, function()
      if PetSkillScoutDB.rotationCustom then PetSkillScoutDB.rotationCustom[R:Spec()] = nil end
      R:Apply(); R:Edit()
    end)
    Btn(CLOSE or "Close", 130, function() f:Hide() end)
    self.editor = f
  end
  f.title:SetText(L("optRotation") .. " - " .. L("gearSpec" .. self:Spec()))
  for kind, e in pairs(f.boxes) do e:SetText(table.concat(self:List(kind), ", ")) end
  f:Show()
end

-- Events --------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
  "UPDATE_BINDINGS", "UNIT_SPELLCAST_SUCCEEDED"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, unit, _, spellID)
  if e == "UNIT_SPELLCAST_SUCCEEDED" then
    if unit ~= "player" then return end
    local id = Plain(spellID)
    local info = id and C_Spell and C_Spell.GetSpellInfo and Call(C_Spell.GetSpellInfo, id)
    local name = type(info) == "table" and Plain(info.name)
    local guid = Plain(UnitGUID and UnitGUID("target"))
    if name and guid then casts[guid .. name] = Now() end
    return
  end
  if e == "UPDATE_BINDINGS" then
    for kind, b in pairs(buttons) do b.key:SetText(KeyText(kind)) end
    return
  end
  if e == "PLAYER_REGEN_ENABLED" and not R.pending then R:Place(); return end
  PSS:Soon("rotation-apply", function() pcall(R.Apply, R) end, 0.5)
end)
local tick = CreateFrame("Frame")
tick:SetScript("OnUpdate", function()
  if (buttons.single and buttons.single:IsShown()) or (buttons.aoe and buttons.aoe:IsShown()) then pcall(R.Paint, R)
  elseif next(lit) then R:Highlight(nil) end
end)
tick.pssKey = "Rotation"
PSS:Every(tick, 0.15)
