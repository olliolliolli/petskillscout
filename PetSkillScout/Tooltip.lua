-- Extra lines in the unit tooltip of tameable beasts (hunters only):
-- tameable / family / attack speed, taming level, rare, skills it teaches
-- (and whether the active pet already knows them), last rare sighting.
local PSS = PetSkillScout
PSS.Tooltip = {}
local TT = PSS.Tooltip

local function Enabled()
  if PetSkillScoutDB and PetSkillScoutDB.tooltip == false then return false end
  if not UnitClass then return false end
  -- Note: "UnitClass and UnitClass(...)" would keep only the first return value.
  local _, class = UnitClass("player")
  return class == "HUNTER"
end

local function NpcID(unit)
  local guid = UnitGUID and UnitGUID(unit)
  if type(guid) ~= "string" or not strsplit then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind ~= "Creature" then return nil end
  return tonumber(id)
end

-- Highest known rank of an ability on the active pet.
local function PetRank(ability)
  local pet = PSS.MyPet
  if not (pet and pet.active) then return nil end
  for _, spell in ipairs(pet.spells or {}) do
    if spell.key == ability then return spell.rank or 0 end
  end
end

function TT:Lines(npc)
  local showSkills = not PetSkillScoutDB or PetSkillScoutDB.tooltipSkills ~= false
  local showSeen = not PetSkillScoutDB or PetSkillScoutDB.tooltipSeen ~= false
  local lines = {}
  local rec = PSS.Atlas and PSS.Atlas:Get(npc)
  local teach = {}
  for _, b in ipairs(PSS.Beasts or {}) do
    if b.npcID == npc and b.ability then table.insert(teach, b) end
  end
  if not rec and #teach == 0 then return lines end
  if rec then
    local head = string.format(PSS:L("ttTameable"), rec.family and PSS:NameFamily(rec.family) or "?") ..
      "  ·  " .. string.format(PSS:L("ttSpeed"), rec.speed or 2)
    if rec.fast then head = head .. " (" .. PSS:L("ttFast") .. ")" end
    table.insert(lines, { head, rec.fast and 0.47 or 0.8, rec.fast and 0.88 or 0.8, rec.fast and 0.55 or 0.8 })
    local level = (UnitLevel and UnitLevel("player")) or (PSS.player and PSS.player.level) or 1
    if rec.minLevel and rec.minLevel > level then
      table.insert(lines, { string.format(PSS:L("tameTooLow"), rec.minLevel), 1, 0.45, 0.45 })
    elseif rec.minLevel then
      table.insert(lines, { PSS:L("tameLevelOK"), 0.7, 0.85, 0.7 })
    end
    if rec.isRare then
      table.insert(lines, { PSS:L("rareCreature") .. (rec.new and ("  ·  " .. PSS:L("rareNew")) or ""), 0.71, 0.57, 0.96 })
    end
  end
  -- Skills it teaches, compared with the active pet.
  local pet = PSS.MyPet
  local familySkills = pet and pet.active and pet.family and PSS.FamilySkills and PSS.FamilySkills[pet.family]
  local seen = {}
  for _, b in ipairs(showSkills and teach or {}) do
    local key = b.ability .. ":" .. tostring(b.rank)
    if not seen[key] then
      seen[key] = true
      local meta = PSS.Ranks[b.ability] and PSS.Ranks[b.ability][tonumber(b.rank)]
      local text = string.format(PSS:L("ttTeaches"), PSS:NameAbility(b.ability), tostring(b.rank))
      if meta and meta.petLevel then text = text .. " (" .. string.format(PSS:L("ttPetLevel"), meta.petLevel) .. ")" end
      local r, g, bl = 0.56, 0.78, 1
      if familySkills then
        local canLearn = false
        for _, k in ipairs(familySkills) do if k == b.ability then canLearn = true end end
        local known = PetRank(b.ability)
        if not canLearn then
          text, r, g, bl = text .. " — " .. PSS:L("ttFamilyCant"), 0.6, 0.6, 0.6
        elseif known and known >= (tonumber(b.rank) or 0) then
          text, r, g, bl = text .. " — " .. PSS:L("ttKnown"), 0.6, 0.6, 0.6
        else
          text, r, g, bl = text .. " — " .. PSS:L("ttNew"), 0.47, 0.88, 0.55
        end
      end
      table.insert(lines, { text, r, g, bl })
    end
  end
  -- Last time you saw this rare yourself.
  local R = PSS.RarePets
  local entry = R and R.byNpcID and R.byNpcID[npc]
  local seenText = showSeen and entry and R.SeenText and R:SeenText(entry)
  if seenText then table.insert(lines, { seenText, 0.8, 0.8, 0.8 }) end
  return lines
end

local function OnUnit(tooltip)
  if tooltip ~= GameTooltip or tooltip.pssDone or not Enabled() then return end
  local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
  if not ok or not unit or not UnitExists(unit) or (UnitIsPlayer and UnitIsPlayer(unit)) then return end
  local npc = NpcID(unit)
  if not npc then return end
  local lines = TT:Lines(npc)
  if #lines == 0 then return end
  tooltip.pssDone = true
  tooltip:AddLine(PSS:Safe("|cff70d6ffPetSkillScout|r"))
  for _, l in ipairs(lines) do tooltip:AddLine(PSS:Safe(l[1]), l[2], l[3], l[4], true) end
  tooltip:Show()
end
TT.OnUnit = OnUnit

-- Modern clients use TooltipDataProcessor; older ones fire OnTooltipSetUnit.
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnit)
elseif GameTooltip and GameTooltip.HookScript then
  pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", OnUnit)
end
if GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnTooltipCleared", function(self) self.pssDone = nil end)
  GameTooltip:HookScript("OnHide", function(self) self.pssDone = nil end)
end
