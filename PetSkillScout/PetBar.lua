-- Pet action bar (Settings > Hunter, on by default): when the pet learns a
-- new rank, the button of the old rank is replaced by the new one; a newly
-- learned active skill goes into a free ability slot (4-7). Only done out of
-- combat, with the same actions as dragging a spell from the pet spellbook
-- onto the pet bar (pick up the book spell, drop it on the pet bar slot).
local PSS = PetSkillScout
PSS.PetBar = {}
local PB = PSS.PetBar

local SLOTS = 10
local ABILITY_SLOTS = {4, 5, 6, 7}

local function DB() return PetSkillScoutDB or {} end
function PB:Enabled() return DB().petBarAuto ~= false end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Call(f, ...)
  if type(f) ~= "function" then return nil end
  local r = {pcall(f, ...)}
  if not r[1] then return nil end
  return unpack(r, 2)
end

local PET_BANK = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet) or "pet"

-- One pet spellbook entry: name, rank number, spell id, passive?
local function BookItem(i)
  local name, sub, id
  if C_SpellBook and C_SpellBook.GetSpellBookItemName then
    name, sub = Call(C_SpellBook.GetSpellBookItemName, i, PET_BANK)
    local info = Call(C_SpellBook.GetSpellBookItemInfo, i, PET_BANK)
    if type(info) == "table" then
      id = info.spellID or info.actionID
      if info.itemType and Enum and Enum.SpellBookItemType and info.itemType ~= Enum.SpellBookItemType.Spell
         and info.itemType ~= Enum.SpellBookItemType.PetAction then return nil end
    end
  else
    name, sub = Call(GetSpellBookItemName, i, "pet")
    local _, sid = Call(GetSpellBookItemInfo, i, "pet")
    id = sid
  end
  if type(name) ~= "string" then return nil end
  local passive = false
  if C_SpellBook and C_SpellBook.IsSpellBookItemPassive then
    passive = Call(C_SpellBook.IsSpellBookItemPassive, i, PET_BANK) and true or false
  elseif IsPassiveSpell then
    passive = Call(IsPassiveSpell, i, "pet") and true or false
  end
  local rank = type(sub) == "string" and tonumber(sub:match("(%d+)")) or 0
  return {index = i, name = name, rank = rank, id = id, passive = passive}
end

-- Highest rank of every pet spell in the book, by name.
function PB:Book()
  local best, n = {}, 0
  for i = 1, 200 do
    local it = BookItem(i)
    if not it then
      n = n + 1
      if n > 3 then break end -- a few gaps in a row: end of the book
    else
      n = 0
      local cur = best[it.name]
      if not cur or it.rank > cur.rank then best[it.name] = it end
    end
  end
  return best
end

local function RankOf(id)
  if not id then return 0 end
  local sub
  if C_Spell and C_Spell.GetSpellSubtext then sub = Call(C_Spell.GetSpellSubtext, id)
  elseif GetSpellSubtext then sub = Call(GetSpellSubtext, id) end
  return type(sub) == "string" and tonumber(sub:match("(%d+)")) or 0
end

-- What sits on each pet bar slot: {name, rank, token} or false when empty.
function PB:Bar()
  local bar = {}
  for s = 1, SLOTS do
    local r = {Call(GetPetActionInfo, s)}
    local name = r[1]
    if type(name) ~= "string" then bar[s] = false else
      -- Classic: name, subtext, texture, isToken ...; modern: name, texture,
      -- isToken, isActive, autoCastAllowed, autoCastEnabled, spellID.
      local token, rank
      if type(r[3]) == "boolean" then
        token = r[3]
        rank = RankOf(r[7])
      else
        token = r[4]
        rank = type(r[2]) == "string" and tonumber(r[2]:match("(%d+)")) or RankOf(r[7])
      end
      bar[s] = {name = name, rank = rank or 0, token = token and true or false}
    end
  end
  return bar
end

local function Place(item, slot)
  ClearCursor()
  if C_SpellBook and C_SpellBook.PickupSpellBookItem then Call(C_SpellBook.PickupSpellBookItem, item.index, PET_BANK)
  else Call(PickupSpellBookItem, item.index, "pet") end
  Call(PickupPetAction, slot)
  ClearCursor()
end

-- Returns how many slots it changed.
function PB:Update()
  if not self:Enabled() or InCombat() then self.pending = true return 0 end
  self.pending = false
  if not (PickupPetAction and GetPetActionInfo) then return 0 end
  if not (Call(UnitExists, "pet")) then return 0 end
  if GetCursorInfo and GetCursorInfo() then return 0 end -- the player is dragging something
  local book, bar = self:Book(), self:Bar()
  local changed, onBar = 0, {}
  for s = 1, SLOTS do
    local b = bar[s]
    if b and not b.token then
      onBar[b.name] = true
      local top = book[b.name]
      if top and not top.passive and top.rank > b.rank then
        Place(top, s); changed = changed + 1
      end
    end
  end
  -- New active skills: first free ability slot. Only skills the pet did not
  -- know before - one the player took off the bar stays off.
  local db = DB()
  db.petBarKnown = db.petBarKnown or {}
  local petKey = Call(UnitName, "pet") or "?"
  local known = db.petBarKnown[petKey]
  local first = known == nil
  known = known or {}
  db.petBarKnown[petKey] = known
  local names = {}
  for name, it in pairs(book) do
    if not first and not known[name] and not it.passive and not onBar[name] then names[#names + 1] = name end
    known[name] = true
  end
  table.sort(names)
  for _, name in ipairs(names) do
    for _, s in ipairs(ABILITY_SLOTS) do
      if bar[s] == false then
        Place(book[name], s); bar[s] = {name = name, rank = book[name].rank}; changed = changed + 1
        break
      end
    end
  end
  return changed
end

PB.frame = CreateFrame("Frame")
for _, e in ipairs({"LEARNED_SPELL_IN_TAB", "PET_BAR_UPDATE", "UNIT_PET", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED"}) do
  pcall(PB.frame.RegisterEvent, PB.frame, e)
end
PB.frame:SetScript("OnEvent", function(_, event, unit)
  if event == "UNIT_PET" and unit ~= "player" then return end
  if event == "PLAYER_REGEN_ENABLED" and not PB.pending then return end
  -- The bar settles a moment after learning; one pass for a burst of events.
  PSS:Soon("petbar", function() PB:Update() end, 0.5)
end)
