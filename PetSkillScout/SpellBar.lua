-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Your action bars (Settings > Hunter, on by default): when you learn a new
-- rank of a spell, every button with an older rank gets the new one; a
-- newly learned active spell goes into the first free slot of the main bar
-- (then the bottom left / bottom right bars). Only out of combat, with the
-- same actions as dragging a spell from the spellbook onto a button.
local PSS = PetSkillScout
PSS.SpellBar = {}
local SB = PSS.SpellBar

local ACTION_SLOTS = 120
local FREE_ORDER = {}
for s = 1, 12 do FREE_ORDER[#FREE_ORDER + 1] = s end   -- main bar
for s = 61, 72 do FREE_ORDER[#FREE_ORDER + 1] = s end  -- bottom left
for s = 49, 60 do FREE_ORDER[#FREE_ORDER + 1] = s end  -- bottom right

local function DB() return PetSkillScoutDB or {} end
function SB:Enabled() return DB().spellBarAuto ~= false end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Call(f, ...)
  if type(f) ~= "function" then return nil end
  local r = {pcall(f, ...)}
  if not r[1] then return nil end
  return unpack(r, 2)
end
local function Plain(v) if PSS.IsSecret and PSS.IsSecret(v) then return nil end return v end

local BANK = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or "spell"
local ITEM_SPELL = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell

local function RankNum(sub) return type(sub) == "string" and tonumber(sub:match("(%d+)")) or 0 end

local function BookItem(i)
  local name, sub, id, isSpell = nil, nil, nil, true
  if C_SpellBook and C_SpellBook.GetSpellBookItemName then
    name, sub = Call(C_SpellBook.GetSpellBookItemName, i, BANK)
    local info = Call(C_SpellBook.GetSpellBookItemInfo, i, BANK)
    if type(info) == "table" then
      id = info.spellID or info.actionID
      if ITEM_SPELL and info.itemType and info.itemType ~= ITEM_SPELL then isSpell = false end
      if info.isPassive or info.isOffSpec then isSpell = false end
    end
  else
    name, sub = Call(GetSpellBookItemName, i, "spell")
    local kind, sid = Call(GetSpellBookItemInfo, i, "spell")
    id = sid
    if kind and kind ~= "SPELL" then isSpell = false end
  end
  name = Plain(name)
  if type(name) ~= "string" then return nil end
  local passive = not isSpell
  if not passive then
    if C_SpellBook and C_SpellBook.IsSpellBookItemPassive then
      passive = Call(C_SpellBook.IsSpellBookItemPassive, i, BANK) and true or false
    elseif IsPassiveSpell then
      passive = Call(IsPassiveSpell, i, "spell") and true or false
    end
  end
  return {index = i, name = name, rank = RankNum(Plain(sub)), id = id, passive = passive}
end

-- Highest rank of every active spell in your spellbook, by name.
function SB:Book()
  local best = {}
  for i = 1, 500 do
    local it = BookItem(i)
    if it and not it.passive then
      local cur = best[it.name]
      if not cur or it.rank > cur.rank then best[it.name] = it end
    end
  end
  return best
end

local function SpellNameRank(id)
  local name, sub
  if C_Spell and C_Spell.GetSpellName then name = Call(C_Spell.GetSpellName, id) else name = Call(GetSpellInfo, id) end
  if C_Spell and C_Spell.GetSpellSubtext then sub = Call(C_Spell.GetSpellSubtext, id)
  elseif GetSpellSubtext then sub = Call(GetSpellSubtext, id) end
  return Plain(name), RankNum(Plain(sub))
end

-- slot -> {name, rank} for spell buttons; false for empty slots.
function SB:Bars()
  local bars = {}
  for s = 1, ACTION_SLOTS do
    if not Call(HasAction, s) then bars[s] = false else
      local kind, id = Call(GetActionInfo, s)
      if kind == "spell" and id then
        local name, rank = SpellNameRank(id)
        if name then bars[s] = {name = name, rank = rank} end
      end
    end
  end
  return bars
end

local function Place(item, slot)
  ClearCursor()
  if C_SpellBook and C_SpellBook.PickupSpellBookItem then Call(C_SpellBook.PickupSpellBookItem, item.index, BANK)
  else Call(PickupSpellBookItem, item.index, "spell") end
  Call(PlaceAction, slot)
  ClearCursor()
end

function SB:Update()
  if not self:Enabled() or InCombat() then self.pending = self:Enabled(); return 0 end
  self.pending = false
  if not (PlaceAction and GetActionInfo) then return 0 end
  if GetCursorInfo and GetCursorInfo() then return 0 end -- you are dragging something
  local book, bars = self:Book(), self:Bars()
  local changed, onBar = 0, {}
  for s = 1, ACTION_SLOTS do
    local b = bars[s]
    if b then
      onBar[b.name] = true
      local top = book[b.name]
      if top and top.rank > b.rank then Place(top, s); changed = changed + 1 end
    end
  end
  -- New spells: only ones learned since the addon last looked (a spell you
  -- took off your bars stays off).
  local db = DB()
  db.spellBarKnown = db.spellBarKnown or {}
  local key = (Call(UnitName, "player") or "?") .. "-" .. (Call(GetRealmName) or "")
  local known = db.spellBarKnown[key]
  local first = known == nil
  known = known or {}
  db.spellBarKnown[key] = known
  local names = {}
  for name in pairs(book) do
    if not first and not known[name] and not onBar[name] then names[#names + 1] = name end
    known[name] = true
  end
  table.sort(names)
  for _, name in ipairs(names) do
    for _, s in ipairs(FREE_ORDER) do
      if bars[s] == false then
        Place(book[name], s); bars[s] = {name = name, rank = book[name].rank}; changed = changed + 1
        break
      end
    end
  end
  return changed
end

SB.frame = CreateFrame("Frame")
for _, e in ipairs({"LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"}) do
  pcall(SB.frame.RegisterEvent, SB.frame, e)
end
SB.frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_REGEN_ENABLED" and not SB.pending then return end
  PSS:Soon("spellbar", function() SB:Update() end, 1)
end)
