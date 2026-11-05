-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- WoW Forever stable inspection with diagnostics. Never invent pet records.
local PSS=PetSkillScout
PSS.Stable={selected=1,status='Not scanned',stableOpen=false}
local S=PSS.Stable
function S:Records()
 if type(PetSkillScoutDB)~='table' then return {} end
 PetSkillScoutDB.stablePets=PetSkillScoutDB.stablePets or {}
 return PetSkillScoutDB.stablePets
end
function S:SnapshotActive()
 if not PSS.MyPet or type(PetSkillScoutDB)~='table' then return end
 local p=PSS.MyPet
 if p.active and p.name then
  -- Do not overwrite a good learned-skill snapshot with a transient empty scan.
  local prior=PetSkillScoutDB.activePetCache
  if #p.spells>0 or not prior or prior.name~=p.name or prior.family~=p.family then
   local copy={}
   for i,spell in ipairs(p.spells) do
    copy[i]={name=spell.name,rank=spell.rank,key=spell.key}
   end
   PetSkillScoutDB.activePetCache={name=p.name,family=p.family,level=p.level,spells=copy}
  end
  -- Model IDs are kept even when the spell snapshot above is not replaced.
  local cache=PetSkillScoutDB.activePetCache
  if cache and cache.name==p.name and cache.family==p.family then
   cache.npcID=p.npcID or cache.npcID
   cache.displayID=p.displayID or cache.displayID
  end
 end
end
local function validName(v)
 return type(v)=='string' and v~='' and not v:match('^%d+$')
end
-- Confirmed on WoW Forever: index 1 is active pet, index 2+ are stable slots.
function S:Scan()
 local api=_G.C_StableInfo
 if not api or type(api.GetStablePetInfo)~='function' then
  self.status='C_StableInfo.GetStablePetInfo unavailable'
  return
 end
 local old=self:Records()
 local found={}
 local cache=PetSkillScoutDB and PetSkillScoutDB.activePetCache
 -- Query a bounded range; nil indicates no pet at this index.
 for slot=2,20 do
  local ok,pet=pcall(api.GetStablePetInfo,slot)
  if ok and type(pet)=='table' and validName(pet.name) then
   local entry={slot=slot,name=pet.name,level=pet.level,family=PSS:CanonicalFamily(pet.familyName),
    icon=pet.icon,displayID=tonumber(pet.displayID),
    npcID=tonumber(pet.creatureID),source='C_StableInfo'}
   for _,prev in ipairs(old) do
    if prev.name==entry.name and prev.family==entry.family then
     entry.spells=prev.spells
     if not entry.npcID then entry.npcID=prev.npcID end
     break
    end
   end
   if cache and cache.name==entry.name and cache.family==entry.family then
    if not entry.spells or #entry.spells==0 then entry.spells=cache.spells end
    entry.npcID=entry.npcID or cache.npcID
    entry.displayID=entry.displayID or cache.displayID
   end
   table.insert(found,entry)
  end
 end
 -- An authoritative successful scan replaces stale stable records, even when empty.
 PetSkillScoutDB.stablePets=found
 if self.selected>#found then self.selected=1 end
 self.status='Stable API: '..#found..' pet(s)'
end
function S:Debug()
 local num='unavailable'
 if type(GetNumStablePets)=='function' then
  local ok,a,b=pcall(GetNumStablePets)
  if ok then num=tostring(a)..' / '..tostring(b) end
 end
 PSS:Print('Stable: '..tostring(self.status)..'; window='..tostring(self.stableOpen)..'; GetNumStablePets='..num)
end
S.events=CreateFrame('Frame')
for _,event in ipairs({'PET_STABLE_SHOW','PET_STABLE_UPDATE','PET_STABLE_CLOSED','UNIT_PET'}) do
 S.events:RegisterEvent(event)
end
S.events:SetScript('OnEvent',function(_,event,unit)
 if type(PetSkillScoutDB)~='table' or (event=='UNIT_PET' and unit~='player') then return end
 if event=='PET_STABLE_SHOW' then
  S.stableOpen=true
  -- Tooltip capture is the fallback for clients without C_StableInfo.
  S:HookSlotTooltips()
 end
 if event=='PET_STABLE_CLOSED' then S.stableOpen=false end
 if event=='UNIT_PET' then S:SnapshotActive()
 elseif event~='PET_STABLE_CLOSED' then S:SnapshotActive();S:Scan() end
 if PSS.UI and PSS.UI.petVisible then PSS.UI:RefreshPet() end
end)

-- Read-only inspection of stable slot widgets and their regions.
-- No clicking, moving pets, tooltip spoofing or scanning private state.
local function describe(v)
 if v==nil then return '-' end
 local value=tostring(v)
 if string.len(value)>90 then value=string.sub(value,1,87)..'...' end
 return value
end
local function method(obj,name,...)
 if not obj or type(obj[name])~='function' then return nil end
 local ok,a=pcall(obj[name],obj,...)
 if ok then return a end
 return nil
end
function S:InspectUI()
 PSS:Print('Stable UI debug (read-only). Open Stable Master first.')
 local root=_G.PetStableFrame or _G.StableFrame
 if not root then PSS:Print('No stable frame found; open the stable window.');return end
 PSS:Print('Root shown='..describe(method(root,'IsShown')))
 local visited,listed=0,0
 local function walk(frame,depth)
  if not frame or visited>=120 or depth>5 then return end
  visited=visited+1
  local name=method(frame,'GetName')
  local kind=method(frame,'GetObjectType') or '?'
  local id=method(frame,'GetID')
  local shown=method(frame,'IsShown')
  local text=method(frame,'GetText')
  local icon=method(frame,'GetNormalTexture')
  local iconPath=method(icon,'GetTexture')
  local texture=method(frame,'GetTexture')
  local interesting=(kind=='Button' or kind=='CheckButton' or kind=='Texture' or kind=='FontString')
  if (interesting or name) and listed<85 then
   listed=listed+1
   PSS:Print('#'..visited..' '..describe(name or '<unnamed>')..' '..kind..' id='..describe(id)..
    ' shown='..describe(shown)..' text='..describe(text)..' tex='..describe(texture or iconPath))
  end
  if type(frame.GetRegions)=='function' then
   local regions={frame:GetRegions()}
   for i=1,math.min(#regions,12) do
    local region=regions[i]
    local rt=method(region,'GetObjectType')
    local value=method(region,'GetText') or method(region,'GetTexture')
    if value and listed<85 then
     listed=listed+1
     PSS:Print('  region '..describe(rt)..' '..describe(value))
    end
   end
  end
  if type(frame.GetChildren)=='function' then
   local children={frame:GetChildren()}
   for i=1,math.min(#children,35) do walk(children[i],depth+1) end
  end
 end
 walk(root,0)
 local patterns={'PetStableCurrentPet','PetStableStabledPet1','PetStableStabledPet2',
  'PetStableStabledPet3','PetStablePet1','PetStablePet2','PetStablePet3',
  'PetStableFramePet1','PetStableFramePet2','PetStableFramePet3'}
 for _,name in ipairs(patterns) do
  local widget=_G[name]
  if widget then
   PSS:Print('GLOBAL '..name..' id='..describe(method(widget,'GetID'))..
    ' shown='..describe(method(widget,'IsShown'))..' text='..describe(method(widget,'GetText')))
  end
 end
 PSS:Print('Inspected '..visited..' widgets; stable data unchanged.')
end


-- Focused, read-only inspection of the three stable slots.
-- Does not call OnEnter/OnClick or synthesize tooltips.
function S:InspectSlots()
 local root=_G.PetStableFrame
 if not root or not root:IsShown() then
  PSS:Print('Open Stable Master first, then run /pss stableslots.')
  return
 end
 local function val(v)
  if v==nil then return '-' end
  local str=tostring(v)
  return string.sub(str,1,75)
 end
 local function read(o,m,...)
  if not o or type(o[m])~='function' then return nil end
  local ok,a=pcall(o[m],o,...)
  if ok then return a end
 end
 local slots={'PetStableCurrentPet','PetStableStabledPet1','PetStableStabledPet2'}
 PSS:Print('Stable slots (read-only); hover each pet slot to inspect tooltip.')
 for _,name in ipairs(slots) do
  local button=_G[name]
  if not button then PSS:Print(name..': missing')
  else
   local tex=read(button,'GetNormalTexture')
   PSS:Print(name..' id='..val(read(button,'GetID'))..
    ' visible='..val(read(button,'IsVisible'))..
    ' enabled='..val(read(button,'IsEnabled'))..
    ' mouseover='..val(read(button,'IsMouseOver'))..
    ' normal='..val(read(tex,'GetTexture')))
   for _,key in ipairs({'name','petName','level','petLevel','family','petFamily','petID','creatureID','texture','icon','isLocked','isEmpty'}) do
    local value=button[key]
    if type(value)=='string' or type(value)=='number' or type(value)=='boolean' then
     PSS:Print('  field '..key..'='..val(value))
    end
   end
   if type(button.GetRegions)=='function' then
    local regions={button:GetRegions()}
    for i=1,math.min(#regions,15) do
     local r=regions[i]
     local kind=read(r,'GetObjectType')
     local v=read(r,'GetText') or read(r,'GetTexture')
     if v then PSS:Print('  region '..val(kind)..'='..val(v)) end
    end
   end
   if type(button.GetChildren)=='function' then
    local children={button:GetChildren()}
    PSS:Print('  child widgets='..#children)
    for i=1,math.min(#children,8) do
     local child=children[i]
     PSS:Print('  child '..i..' '..val(read(child,'GetName'))..' '..val(read(child,'GetObjectType'))..
      ' text='..val(read(child,'GetText')))
    end
   end
  end
 end
 local tooltip=_G.GameTooltip
 if tooltip and tooltip:IsShown() then
  PSS:Print('Current GameTooltip (only if already visible):')
  local base=tooltip:GetName()
  if base then
   for i=1,math.min(tooltip:NumLines() or 0,12) do
    local line=_G[base..'TextLeft'..i]
    local txt=read(line,'GetText')
    if txt and txt~='' then PSS:Print('  '..val(txt)) end
   end
  end
 else
  PSS:Print('No tooltip visible. Hover a stable slot and run command again.')
 end
 PSS:Print('No stable pets were moved or modified.')
end


-- Stable slots expose pet details in GameTooltip even when legacy stable APIs
-- are absent. Read the actual tooltip on hover; never create synthetic entries.
local function stableTooltipLines()
 local tip=_G.GameTooltip
 if not tip or not tip:IsShown() then return nil end
 local lines={}
 for i=1,tip:NumLines() do
  local fs=_G['GameTooltipTextLeft'..i]
  if fs and fs:GetText() then table.insert(lines,fs:GetText()) end
 end
 return lines
end
local function parseStableTooltip(lines)
 if not lines or #lines<2 then return nil end
 local level,family
 for _,line in ipairs(lines) do
  local lv,fam=line:match('^[Ll]evel%s+(%d+)%s+(.+)$')
  if lv and fam then level=tonumber(lv);family=fam;break end
 end
 if not level or not family then return nil end
 -- The tooltip's first line can be just the family, not a pet name.
 local first=lines[1]
 local name=(first and first~=family and first~=('Level '..level..' '..family)) and first or nil
 return {level=level,family=PSS:CanonicalFamily(family),name=name}
end
function S:CaptureSlot(slot,button)
 if _G.C_StableInfo and type(_G.C_StableInfo.GetStablePetInfo)=='function' then return end
 if not self.stableOpen and not (_G.PetStableFrame and _G.PetStableFrame:IsShown()) then return end
 if not button or not button.IsMouseOver or not button:IsMouseOver() then return end
 local data=parseStableTooltip(stableTooltipLines())
 if not data then return end
 local records=self:Records()
 local cache=PetSkillScoutDB and PetSkillScoutDB.activePetCache
 local previous
 for _,item in ipairs(records) do
  if item.slot==slot then previous=item;break end
 end
 local record={
  slot=slot,level=data.level,family=data.family,
  name=data.name or (previous and previous.level==data.level and previous.family==data.family and previous.name) or nil,
  spells=previous and previous.level==data.level and previous.family==data.family and previous.spells or nil,
  npcID=previous and previous.level==data.level and previous.family==data.family and previous.npcID or nil,
  displayID=previous and previous.level==data.level and previous.family==data.family and previous.displayID or nil,
  source='tooltip'
 }
 if cache and cache.name and cache.family==data.family and cache.level==data.level
    and (not record.name or record.name==cache.name) then
  record.name=cache.name
  if not record.spells or #record.spells==0 then record.spells=cache.spells end
  record.npcID=record.npcID or cache.npcID
  record.displayID=record.displayID or cache.displayID
 end
 local found=false
 for i,item in ipairs(records) do
  if item.slot==slot then records[i]=record;found=true;break end
 end
 if not found then table.insert(records,record) end
 table.sort(records,function(a,b) return (a.slot or 99)<(b.slot or 99) end)
 self.status='Captured stable slot '..slot..' from tooltip'
 if PSS.UI and PSS.UI.petVisible then PSS.UI:RefreshPet() end
end
function S:HookSlotTooltips()
 self.hookedSlots=self.hookedSlots or {}
 for i=1,2 do
  local slot=i+1
  local button=_G['PetStableStabledPet'..i]
  -- Hook each button once; retry on later opens if it did not exist yet.
  if button and not self.hookedSlots[i] and type(button.HookScript)=='function' then
   self.hookedSlots[i]=true
   PSS.HookScript(button, 'OnEnter',function(widget)
    -- Original OnEnter populates the tooltip before hooked scripts run.
    S:CaptureSlot(slot,widget)
   end)
  end
 end
end
