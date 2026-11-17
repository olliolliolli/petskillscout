-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- One-button rotations (beta, off by default, theme only). Two buttons above
-- the cooldown manager: single target and several targets. Each is a plain
-- /castsequence macro (the game's own macro command): every press casts the
-- next spell of the list, the player decides when and which button - the
-- addon never casts anything by itself. The icon shows the spell the next
-- press will cast (QueryCastSequence, Blizzard_ChatFrameBase/Shared/
-- CastSequenceManager.lua). Lists from WoW Forever hunter guides (wowtbc.gg
-- Forever BM / MM, Warcraft Tavern Forever leveling); long cooldowns (Rapid
-- Fire, Bestial Wrath) and Summon Hawk stay on their own buttons, because a
-- sequence waits on a spell that is on cooldown.
local PSS = PetSkillScout
PSS.Rotation = {}
local R = PSS.Rotation

local FLAT = "Interface\\Buttons\\WHITE8X8"
local RESET = "reset=target/combat/8"
-- English spell names (the client accepts them in macros only in English
-- clients): each one is turned into the local name through its spell ID.
local SPELL = {
  ["Hunter's Mark"] = 1130, ["Serpent Sting"] = 1978, ["Arcane Shot"] = 3044, ["Aimed Shot"] = 19434,
  ["Multi-Shot"] = 2643, ["Raptor Strike"] = 2973, ["Mongoose Bite"] = 1495,
}
R.LISTS = {
  BM = {single = {"Hunter's Mark", "Serpent Sting", "Arcane Shot", "Aimed Shot", "Arcane Shot"},
        aoe = {"Multi-Shot", "Serpent Sting", "Multi-Shot", "Arcane Shot"}},
  MM = {single = {"Hunter's Mark", "Serpent Sting", "Sniper Shot", "Arcane Shot", "Aimed Shot", "Arcane Shot"},
        aoe = {"Multi-Shot", "Serpent Sting", "Multi-Shot", "Arcane Shot"}},
  SV = {single = {"Hunter's Mark", "Serpent Sting", "Arcane Shot", "Aimed Shot", "Arcane Shot"},
        aoe = {"Multi-Shot", "Serpent Sting", "Multi-Shot", "Arcane Shot"}},
}

local function DB() return PetSkillScoutDB or {} end
local function L(k) return PSS:L(k) end
local function Plain(v) if PSS.IsSecret and PSS.IsSecret(v) then return nil end return v end
local function InCombat() return InCombatLockdown and InCombatLockdown() end

function R:Enabled()
  local _, class = UnitClass("player")
  return class == "HUNTER" and DB().rotationBeta == true and PSS.Skin and PSS.Skin.active
end

-- Local name of a spell the player knows (by our ID, else by the English name).
local function Known(name)
  local id = SPELL[name]
  local info = id and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
  local loc = info and Plain(info.name) or name
  local fn = C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell
  if fn then
    local ok, slot = pcall(fn, loc)
    if ok and slot then return loc end
    return nil
  end
  if GetSpellInfo and GetSpellInfo(loc) then return loc end
end

function R:Sequence(kind)
  local spec = PSS.Gear and PSS.Gear.Spec and PSS.Gear:Spec() or "BM"
  local list = (self.LISTS[spec] or self.LISTS.BM)[kind]
  local out = {}
  for _, n in ipairs(list) do
    local loc = Known(n)
    if loc then out[#out + 1] = loc end
  end
  if #out == 0 then return nil end
  return RESET .. " " .. table.concat(out, ", ")
end

local buttons = {}
local function Make(kind)
  local name = kind == "single" and "PetSkillScoutRotSingle" or "PetSkillScoutRotAoE"
  local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
  b:SetSize(40, 40)
  b:RegisterForClicks("AnyDown")
  b:SetAttribute("type", "macro")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.edge = {}
  for i = 1, 4 do b.edge[i] = b:CreateTexture(nil, "OVERLAY"); b.edge[i]:SetTexture(FLAT) end
  b.edge[1]:SetPoint("TOPLEFT"); b.edge[1]:SetPoint("TOPRIGHT")
  b.edge[2]:SetPoint("BOTTOMLEFT"); b.edge[2]:SetPoint("BOTTOMRIGHT")
  b.edge[3]:SetPoint("TOPLEFT"); b.edge[3]:SetPoint("BOTTOMLEFT")
  b.edge[4]:SetPoint("TOPRIGHT"); b.edge[4]:SetPoint("BOTTOMRIGHT")
  b.label = b:CreateFontString(nil, "OVERLAY")
  b.label:SetFont("Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf", 10, "OUTLINE")
  b.label:SetPoint("BOTTOM", b, "TOP", 0, 2)
  b.kind = kind
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L(kind == "single" and "rotSingle" or "rotAoE"))
    GameTooltip:AddLine(L("rotTip"), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  b:Hide()
  buttons[kind] = b
  _G["BINDING_NAME_CLICK " .. name .. ":LeftButton"] = L(kind == "single" and "rotSingle" or "rotAoE")
  return b
end

local function Edge(b, w, c)
  for i = 1, 4 do
    b.edge[i]:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    if i <= 2 then b.edge[i]:SetHeight(w) else b.edge[i]:SetWidth(w) end
  end
end

-- Macro text and place: out of combat only (secure buttons).
function R:Apply()
  if InCombat() then self.pending = true; return end
  self.pending = nil
  local on = self:Enabled()
  for _, kind in ipairs({"single", "aoe"}) do
    local b = buttons[kind] or Make(kind)
    local seq = on and self:Sequence(kind)
    b.seq = seq
    if seq then
      b:SetAttribute("macrotext", "/castsequence " .. seq)
      b.label:SetText(L(kind == "single" and "rotSingleShort" or "rotAoEShort"))
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
      if holder then
        b:SetPoint("BOTTOM", holder, "BOTTOM", (i == 1 and -24 or 24), y)
      else
        b:SetPoint("BOTTOM", UIParent, "BOTTOM", (i == 1 and -24 or 24), 260)
      end
      b:SetFrameStrata("MEDIUM")
    end
  end
end

-- Hostile nameplates on screen (for the several-targets hint).
local function Enemies()
  local n = 0
  local list = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
  for _, p in ipairs(list) do
    local u = p.namePlateUnitToken or (p.UnitFrame and p.UnitFrame.unit)
    if u and Plain(UnitCanAttack("player", u)) and not Plain(UnitIsDead(u)) then n = n + 1 end
  end
  return n
end

function R:Paint()
  local col = PSS.Skin and PSS.Skin.colours or {}
  local edge = col.edge or {0.55, 0.45, 0.3, 1}
  local acc = col.accent or {0.86, 0.7, 0.35, 1}
  local many = Enemies() >= 3
  for kind, b in pairs(buttons) do
    if b:IsShown() and b.seq then
      local _, _, spell = QueryCastSequence(b.seq)
      local tex
      if spell and spell ~= "" then
        tex = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spell)
          or (GetSpellTexture and GetSpellTexture(spell))
      end
      b.icon:SetTexture(Plain(tex) or "Interface\\Icons\\INV_Misc_QuestionMark")
      local glow = kind == "aoe" and many and UnitAffectingCombat("player")
      Edge(b, glow and 2 or 1, glow and acc or edge)
    end
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_REGEN_ENABLED" and not R.pending then R:Place(); return end
  PSS:Soon("rotation-apply", function() pcall(R.Apply, R) end, 0.5)
end)
local tick = CreateFrame("Frame")
tick:SetScript("OnUpdate", function()
  if buttons.single and (buttons.single:IsShown() or (buttons.aoe and buttons.aoe:IsShown())) then pcall(R.Paint, R) end
end)
tick.pssKey = "Rotation"
PSS:Every(tick, 0.2)
