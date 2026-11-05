-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Active hunter pet inspection. Uses the pet spellbook; never guesses missing ranks.
local PSS = PetSkillScout
PSS.MyPet = { spells = {} }
local M = PSS.MyPet
local function safe(fn, ...)
  if type(fn) ~= 'function' then return nil end
  local ok,a,b,c,d = pcall(fn,...)
  if ok then return a,b,c,d end
end
local function trim(s)
  return (s or ''):gsub('^%s+',''):gsub('%s+$','')
end
local function normalized(s)
  return trim((s or ''):lower():gsub('[%s%p]+',' '))
end
local function lookup(name)
  local n=normalized(name)
  for key, info in pairs(PSS.Abilities or {}) do
    if normalized(key)==n or normalized(info.label)==n then return key end
  end
  return nil
end
-- Rank information varies between client builds. Inspect multiple sources,
-- including the actual spellbook tooltip, rather than treating icon IDs as ranks.
local function parseRank(value)
  if type(value)~='string' then return nil end
  local n=value:match('[Rr]ank%s*:?%s*(%d+)') or value:match('Ранг%s*:?%s*(%d+)')
  return n and tonumber(n) or nil
end
-- Classic pet action-spell IDs checked against CMaNGOS PlayerbotFactory.cpp;
-- Forever-specific spell checked against ForeverDB. This table maps the
-- actual pet spell, not the trainer's separate Learn Spell wrapper.
-- Other abilities are resolved from the client's own spellbook/API by name,
-- subtext and tooltip; unknown IDs are never assigned a guessed rank.
local PET_SPELL_RANKS = {}
local function registerRanks(name, ids)
  for rank,spellID in ipairs(ids) do
    PET_SPELL_RANKS[spellID]={name=name,rank=rank}
  end
end
registerRanks('Bite', {17253,17255,17256,17257,17258,17259,17260,17261})
registerRanks('Claw', {16827,16828,16829,16830,16831,16832,3010,3009})
registerRanks('Growl', {2649,14916,14917,14918,14919,14920,14921})
registerRanks('Cower', {1742,1753,1754,1755,1756,16697})
registerRanks('Dash', {23099,23109,23110})
registerRanks('Dive', {23145,23146,23147})
registerRanks('Prowl', {24450,24452,24453})
registerRanks('Thunderstomp', {26090,26187,26188})
registerRanks('Demoralizing Screech', {24423,24577,24578,27051})
registerRanks("Trickster's Dance", {1310612})
local tooltip
local function tooltipRank(index, bookType)
  if type(GameTooltip)~='table' and type(GameTooltip)~='userdata' then return nil end
  if not tooltip then
    tooltip=CreateFrame('GameTooltip','PSSPetRankTooltip',UIParent,'GameTooltipTemplate')
    tooltip:SetOwner(UIParent,'ANCHOR_NONE')
  end
  if not tooltip.SetSpellBookItem then return nil end
  tooltip:ClearLines()
  local ok=pcall(tooltip.SetSpellBookItem,tooltip,index,bookType)
  if not ok then return nil end
  for line=1,tooltip:NumLines() do
    local region=_G['PSSPetRankTooltipTextLeft'..line]
    local txt=region and region:GetText()
    local rank=parseRank(txt)
    if rank then return rank end
  end
end
function M:Scan()
  self.spells={}
  self.active = safe(UnitExists,'pet') and not safe(UnitIsDead,'pet')
  self.name = self.active and safe(UnitName,'pet') or nil
  self.level = self.active and safe(UnitLevel,'pet') or nil
  -- Canonical English key, also when the client returns a translated name.
  self.family = self.active and PSS:CanonicalFamily(safe(UnitCreatureFamily,'pet')) or nil
  -- Pet GUID: Pet-0-<server>-<instance>-<zone>-<creatureID>-<petUID>. Accept the
  -- creature ID only when it is a known beast, so a generic pet template ID
  -- can never pick a wrong 3D model.
  self.npcID, self.displayID = nil, nil
  if self.active then
    local guid = safe(UnitGUID,'pet')
    if type(guid)=='string' and strsplit then
      local _,_,_,_,_,id = strsplit('-',guid)
      id = tonumber(id)
      if id and PSS.DisplayIDs and PSS.DisplayIDs[id] then
        self.npcID, self.displayID = id, PSS.DisplayIDs[id]
      end
    end
  end
  if not self.active then return end
  -- Clients differ: HasPetSpells may return a boolean rather than a count.
  -- Probe the pet spellbook directly and fall back to pet action bar slots.
  local bookType = BOOKTYPE_PET or 'pet'
  local seen={}
  local function addSpell(name,subtext,extraRank)
    if type(name)~='string' or name=='' then return end
    local rank = parseRank(subtext) or parseRank(name) or extraRank
    local cleanName = trim(name:gsub('%s*%([Rr]ank%s*%d+%)',''))
    local id=normalized(cleanName)
    if id=='' then return end
    local previous=seen[id]
    if previous then
      if rank and (not previous.rank or rank>previous.rank) then previous.rank=rank end
      return
    end
    local spell={name=cleanName,rank=rank,key=lookup(cleanName)}
    seen[id]=spell
    table.insert(self.spells,spell)
  end
  local count=safe(HasPetSpells)
  local maxIndex=(type(count)=='number' and count>0) and math.min(count,200) or 100
  local misses=0
  for index=1,maxIndex do
    local name,subtext=safe(GetSpellName,index,bookType)
    if not name then name,subtext=safe(GetSpellBookItemName,index,bookType) end
    if name then
      local bookName,bookRank=safe(GetSpellBookItemName,index,bookType)
      local infoName,infoRank=safe(GetSpellInfo,index,bookType)
      local rank=parseRank(bookRank) or parseRank(infoRank) or tooltipRank(index,bookType)
      addSpell(name,subtext,rank)
      misses=0
    else
      misses=misses+1
      if misses>=12 then break end
    end
  end
  -- Forever exposes the actual spell ID as the 7th GetPetActionInfo return.
  -- Scan action slots even when the spellbook yielded partial results.
  for slot=1,10 do
    if type(GetPetActionInfo)=='function' then
      local ok,name,icon,token,active,autoAllowed,autoEnabled,spellID=pcall(GetPetActionInfo,slot)
      if ok and type(name)=='string' and name~='' and not name:find('^PET_') then
        local mapped=type(spellID)=='number' and PET_SPELL_RANKS[spellID] or nil
        local resolvedName=mapped and mapped.name or name
        local rank=mapped and mapped.rank or nil
        if not rank and type(spellID)=='number' then
          local _,sub=safe(GetSpellInfo,spellID)
          rank=parseRank(sub)
        end
        if mapped or lookup(resolvedName) then addSpell(resolvedName,nil,rank) end
      end
    end
  end
  table.sort(self.spells,function(a,b) return a.name < b.name end)
end
function M:AvailableSkills()
  if not self.active then return {},nil end
  local candidates=PSS.FamilySkills and PSS.FamilySkills[self.family]
  if not candidates then return {},nil end
  local learned,count={},0
  for _,spell in ipairs(self.spells or {}) do
    if spell.key and not learned[spell.key] and PSS.Abilities[spell.key] then
      learned[spell.key]=true; count=count+1
    end
  end
  -- Slot count is an estimate; the Forever client must be checked in-game.
  local estimatedFree=math.max(0,4-count)
  local available={}
  if estimatedFree>0 then
    for _,key in ipairs(candidates) do
      if PSS.Abilities[key] and not learned[key] then table.insert(available,key) end
    end
  end
  return available,estimatedFree
end
function M:NextRank(spell)
  if not spell.key or not spell.rank then return nil end
  local available={}
  for rank in pairs((PSS.Ranks and PSS.Ranks[spell.key]) or {}) do available[tonumber(rank)]=true end
  for _,b in ipairs(PSS.Beasts or {}) do
    if b.ability==spell.key and tonumber(b.rank) then available[tonumber(b.rank)]=true end
  end
  local nextRank
  for rank in pairs(available) do
    if rank>spell.rank and (not nextRank or rank<nextRank) then nextRank=rank end
  end
  return nextRank
end
M.events=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_ENTERING_WORLD','UNIT_PET','PET_BAR_UPDATE','PET_UI_UPDATE','SPELLS_CHANGED','UNIT_LEVEL'}) do
  -- Some events differ between WoW client versions; skip unsupported ones.
  pcall(M.events.RegisterEvent, M.events, event)
end
-- Pet events often arrive in bursts (summon fires several at once). Coalesce
-- them into a single scan shortly after the last one.
local scanDelay=0
M.events:Hide()
M.events:SetScript('OnUpdate',function(self,elapsed)
  scanDelay=scanDelay-(elapsed or 0)
  if scanDelay>0 then return end
  self:Hide()
  M:Scan()
  if PSS.Stable and PSS.Stable.SnapshotActive then PSS.Stable:SnapshotActive() end
  -- Already scanned above; let the UI reuse that result.
  if PSS.UI and PSS.UI.RefreshPet then PSS.UI:RefreshPet(true) end
end)
M.events:SetScript('OnEvent',function(_,event,unit)
  if (event=='UNIT_PET' or event=='UNIT_LEVEL') and unit~='player' and unit~='pet' then return end
  scanDelay=0.2
  M.events:Show()
end)

-- Client-specific diagnostic: run /pss petdebug with an active pet.
-- Prints raw API returns without guessing rank or changing saved data.
local function DebugSpellbook()
  local function show(v)
    if v==nil then return 'nil' end
    return tostring(v)..' ('..type(v)..')'
  end
  local function report(label,fn,...)
    if type(fn)~='function' then PSS:Print(label..': unavailable'); return end
    local ok,a,b,c,d=pcall(fn,...)
    if not ok then PSS:Print(label..': ERROR '..tostring(a)); return end
    PSS:Print(label..': '..show(a)..' | '..show(b)..' | '..show(c)..' | '..show(d))
  end
  PSS:Print('PET DEBUG | pet='..tostring(UnitName('pet'))..' | HasPetSpells='..show(safe(HasPetSpells)))
  local book=BOOKTYPE_PET or 'pet'
  for i=1,12 do
    local name=safe(GetSpellName,i,book) or safe(GetSpellBookItemName,i,book)
    if name then
      report('['..i..'] GetSpellName',GetSpellName,i,book)
      report('['..i..'] GetSpellBookItemName',GetSpellBookItemName,i,book)
      report('['..i..'] GetSpellBookItemInfo',GetSpellBookItemInfo,i,book)
      report('['..i..'] GetSpellInfo(index,book)',GetSpellInfo,i,book)
      if tooltip and tooltip.SetSpellBookItem then
        tooltip:ClearLines()
        if pcall(tooltip.SetSpellBookItem,tooltip,i,book) then
          for j=1,math.min(tooltip:NumLines(),3) do
            local region=_G['PSSPetRankTooltipTextLeft'..j]
            if region and region:GetText() then PSS:Print('  tooltip '..j..': '..tostring(region:GetText())) end
          end
        end
      end
    end
  end
end

-- Diagnostics for the Forever pet action bar. Do not infer a rank from these values.
function M:Debug()
  -- Pet stat APIs (happiness, loyalty, training points, experience).
  local function raw(label, fn, ...)
    if type(fn) ~= 'function' then PSS:Print(label .. ': unavailable') return end
    local r = {pcall(fn, ...)}
    local parts = {}
    for i = 2, math.min(#r, 5) do
      local v = r[i]
      if PSS.IsSecret(v) then parts[#parts + 1] = '<secret>'
      elseif type(v) == 'table' then
        local items = {}
        for _, x in ipairs(v) do items[#items + 1] = PSS.IsSecret(x) and '<secret>' or tostring(x) end
        parts[#parts + 1] = '{' .. table.concat(items, ', ') .. '}'
      else parts[#parts + 1] = tostring(v) end
    end
    PSS:Print(label .. ': ' .. (r[1] and table.concat(parts, ' | ') or ('ERROR ' .. tostring(r[2]))))
  end
  local P = C_PetInfo or {}
  raw('C_PetInfo.GetPetHappiness', P.GetPetHappiness)
  raw('C_PetInfo.GetPetLoyalty', P.GetPetLoyalty)
  raw('C_PetInfo.GetPetTrainingPoints', P.GetPetTrainingPoints)
  raw('C_PetInfo.GetPetFoodTypes', P.GetPetFoodTypes)
  raw('GetPetHappiness', GetPetHappiness)
  raw('GetPetLoyalty', GetPetLoyalty)
  raw('GetPetTrainingPoints', GetPetTrainingPoints)
  raw('UnitHealth(pet) / max', function() return UnitHealth('pet'), UnitHealthMax('pet') end)
  raw('GetPetExperience', GetPetExperience)
  for p = 0, 6 do raw('UnitPower(pet,' .. p .. ') / max', function() return UnitPower('pet', p), UnitPowerMax('pet', p) end) end
  raw('UnitPowerType(pet)', UnitPowerType, 'pet')
  DebugSpellbook()
  local function val(x)
    if x==nil then return 'nil' end
    return tostring(x)..' ('..type(x)..')'
  end
  PSS:Print('PET DEBUG ACTION BAR | raw returns 1-8 for abilities')
  if type(GetPetActionInfo)~='function' then
    PSS:Print('GetPetActionInfo unavailable')
    return
  end
  for slot=1,10 do
    local result={pcall(GetPetActionInfo,slot)}
    if not result[1] then
      PSS:Print('slot '..slot..' ERROR '..tostring(result[2]))
    else
      local name=result[2]
      if type(name)=='string' and name~='' and not string.find(name,'^PET_') then
        PSS:Print('slot '..slot..' | '..name)
        -- Explicit indices preserve nil fields; table unpacking would lose them.
        PSS:Print('  1=name '..val(result[2])..' | 2=icon '..val(result[3]))
        PSS:Print('  3=token '..val(result[4])..' | 4=active '..val(result[5]))
        PSS:Print('  5=autoAllowed '..val(result[6])..' | 6=autoEnabled '..val(result[7]))
        PSS:Print('  7=spellID? '..val(result[8])..' | 8=extra '..val(result[9]))
        if type(result[8])=='number' and type(GetSpellInfo)=='function' then
          local ok,n,rank=pcall(GetSpellInfo,result[8])
          if ok then PSS:Print('  GetSpellInfo(ID): '..val(n)..' | rank '..val(rank)) end
        end
      end
    end
  end
end
