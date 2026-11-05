-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Rare Beast Radar + Rare Pet Collection. Nameplate detection plus target/mouseover fallback.
local PSS = PetSkillScout
PSS.RarePets = { entries = {}, byName = {}, byNpcID = {}, lastAlert = {} }
local R = PSS.RarePets
-- Classic tameable rare catalogue (66 entries), sourced from Petopia Classic rare pets.
-- The catalogue is independent of the skill-teaching beast database.
-- NPC IDs are cross-checked against the AzerothCore world database (name + level).
-- Display IDs live in DisplayIDs.lua. Coordinates are attached only when an
-- existing verified-coordinate PSS.Beasts record matches the same creature.
local catalogue = {
  {name="Ressan the Needler",family="Bat",minLevel=11,maxLevel=11,zone="Tirisfal Glades",npcID=10357},
  {name="Blind Hunter",family="Bat",minLevel=32,maxLevel=32,zone="Razorfen Kraul",npcID=4425},
  {name="Big Samras",family="Bear",minLevel=27,maxLevel=27,zone="Hillsbrad Foothills",npcID=14280},
  {name="Ursol'lok",family="Bear",minLevel=31,maxLevel=31,zone="Ashenvale",npcID=12037},
  {name="Old Grizzlegut",family="Bear",minLevel=43,maxLevel=43,zone="Feralas",npcID=5352},
  {name="Old Vicejaw",family="Bear",minLevel=14,maxLevel=14,zone="Silverpine Forest",npcID=12432},
  {name="Mongress",family="Bear",minLevel=50,maxLevel=50,zone="Felwood",npcID=14344},
  {name="Bjarn",family="Bear",minLevel=12,maxLevel=12,zone="Dun Morogh",npcID=1130},
  {name="Grunter",family="Boar",minLevel=50,maxLevel=50,zone="Blasted Lands",npcID=8303},
  {name="Vultros",family="Carrion Bird",minLevel=26,maxLevel=26,zone="Westfall",npcID=462},
  {name="Lord Condar",family="Carrion Bird",minLevel=15,maxLevel=16,zone="Loch Modan",npcID=14268},
  {name="Greater Firebird",family="Carrion Bird",minLevel=46,maxLevel=46,zone="Tanaris",npcID=8207},
  {name="Zaricotl",family="Carrion Bird",minLevel=55,maxLevel=55,zone="Badlands",npcID=2931},
  {name="Spiteflayer",family="Carrion Bird",minLevel=52,maxLevel=52,zone="Blasted Lands",npcID=8299},
  {name="Shadowclaw",family="Cat",minLevel=13,maxLevel=13,zone="Darkshore",npcID=2175},
  {name="Araga",family="Cat",minLevel=35,maxLevel=35,zone="Alterac Mountains",npcID=14222},
  {name="Broken Tooth",family="Cat",minLevel=37,maxLevel=37,zone="Badlands",npcID=2850},
  {name="Duskstalker",family="Cat",minLevel=9,maxLevel=9,zone="Teldrassil",npcID=14430},
  {name="Dishu",family="Cat",minLevel=13,maxLevel=13,zone="The Barrens",npcID=5865},
  {name="Rak'Shiri",family="Cat",minLevel=57,maxLevel=57,zone="Winterspring",npcID=10200},
  {name="Humar the Pridelord",family="Cat",minLevel=23,maxLevel=23,zone="The Barrens",npcID=5828},
  {name="The Rake",family="Cat",minLevel=10,maxLevel=10,zone="Mulgore",npcID=5807},
  {name="Ripscale",family="Crocolisk",minLevel=39,maxLevel=39,zone="Dustwallow Marsh",npcID=14233},
  {name="Sewer Beast",family="Crocolisk",minLevel=50,maxLevel=50,zone="Stormwind City",npcID=3581},
  {name="Large Loch Crocolisk",family="Crocolisk",minLevel=22,maxLevel=22,zone="Loch Modan",npcID=2476},
  {name="Kurmokk",family="Gorilla",minLevel=42,maxLevel=42,zone="Stranglethorn Vale",npcID=14491},
  {name="Uhk'loc",family="Gorilla",minLevel=52,maxLevel=52,zone="Un'Goro Crater",npcID=6585},
  {name="Giggler",family="Hyena",minLevel=34,maxLevel=34,zone="Desolace",npcID=14228},
  {name="Murderous Blisterpaw",family="Hyena",minLevel=43,maxLevel=43,zone="Tanaris",npcID=8208},
  {name="Snort the Heckler",family="Hyena",minLevel=17,maxLevel=17,zone="The Barrens",npcID=5829},
  {name="Ravage",family="Hyena",minLevel=51,maxLevel=51,zone="Blasted Lands",npcID=8300},
  {name="Olm the Wise",family="Bird of Prey",minLevel=52,maxLevel=52,zone="Felwood",npcID=14343},
  {name="Takk the Leaper",family="Raptor",minLevel=19,maxLevel=19,zone="The Barrens",npcID=5842},
  {name="Dart",family="Raptor",minLevel=38,maxLevel=38,zone="Dustwallow Marsh",npcID=14232},
  {name="Razormaw Matriarch",family="Raptor",minLevel=31,maxLevel=31,zone="Wetlands",npcID=1140},
  {name="Death Flayer",family="Scorpid",minLevel=11,maxLevel=11,zone="Durotar",npcID=5823},
  {name="Krellack",family="Scorpid",minLevel=56,maxLevel=56,zone="Silithus",npcID=14476},
  {name="Vile Sting",family="Scorpid",minLevel=35,maxLevel=35,zone="Thousand Needles",npcID=5937},
  {name="Clack the Reaver",family="Scorpid",minLevel=53,maxLevel=53,zone="Blasted Lands",npcID=8301},
  {name="Shanda the Spinner",family="Spider",minLevel=19,maxLevel=19,zone="Loch Modan",npcID=14266},
  {name="Creepthess",family="Spider",minLevel=24,maxLevel=24,zone="Hillsbrad Foothills",npcID=14279},
  {name="Gretheer",family="Spider",minLevel=57,maxLevel=57,zone="Silithus",npcID=14472},
  {name="Rekk'tilac",family="Spider",minLevel=48,maxLevel=48,zone="Searing Gorge",npcID=8277},
  {name="Chatter",family="Spider",minLevel=23,maxLevel=23,zone="Redridge Mountains",npcID=616},
  {name="Sri'skulk",family="Spider",minLevel=13,maxLevel=13,zone="Tirisfal Glades",npcID=10359},
  {name="Krethis Shadowspinner",family="Spider",minLevel=15,maxLevel=15,zone="Silverpine Forest",npcID=12433},
  {name="Mother Fang",family="Spider",minLevel=10,maxLevel=10,zone="Elwynn Forest",npcID=471},
  {name="Leech Widow",family="Spider",minLevel=24,maxLevel=24,zone="Wetlands",npcID=1112},
  {name="Darkmist Widow",family="Spider",minLevel=40,maxLevel=40,zone="Dustwallow Marsh",npcID=4380},
  {name="Naraxis",family="Spider",minLevel=27,maxLevel=27,zone="Duskwood",npcID=574},
  {name="Mazzranache",family="Tallstrider",minLevel=9,maxLevel=9,zone="Mulgore",npcID=3068},
  {name="Strider Clutchmother",family="Tallstrider",minLevel=20,maxLevel=20,zone="Darkshore",npcID=2172},
  {name="Ironback",family="Turtle",minLevel=51,maxLevel=51,zone="The Hinterlands",npcID=8213},
  {name="Cranky Benj",family="Turtle",minLevel=32,maxLevel=32,zone="Alterac Mountains",npcID=14223},
  {name="Azzere the Skyblade",family="Wind Serpent",minLevel=25,maxLevel=25,zone="The Barrens",npcID=5834},
  {name="Hayoc",family="Wind Serpent",minLevel=41,maxLevel=41,zone="Dustwallow Marsh",npcID=14234},
  {name="Arash-ethis",family="Wind Serpent",minLevel=49,maxLevel=49,zone="Feralas",npcID=5349},
  {name="Snarler",family="Wolf",minLevel=42,maxLevel=42,zone="Feralas",npcID=5356},
  {name="Mist Howler",family="Wolf",minLevel=22,maxLevel=22,zone="Ashenvale",npcID=10644},
  {name="Deathmaw",family="Wolf",minLevel=53,maxLevel=53,zone="Burning Steppes",npcID=10077},
  {name="Old Cliff Jumper",family="Wolf",minLevel=42,maxLevel=42,zone="The Hinterlands",npcID=8211},
  {name="Gorefang",family="Wolf",minLevel=13,maxLevel=13,zone="Silverpine Forest",npcID=12431},
  {name="Barnabus",family="Wolf",minLevel=38,maxLevel=38,zone="Badlands",npcID=2753},
  {name="Timber",family="Wolf",minLevel=10,maxLevel=10,zone="Dun Morogh",npcID=1132},
  {name="Lupos",family="Wolf",minLevel=23,maxLevel=23,zone="Duskwood",npcID=521},
  {name="Death Howl",family="Wolf",minLevel=49,maxLevel=49,zone="Felwood",npcID=14339},
  -- Rares added in Season of Discovery data and new in WoW Forever
  -- (mmonster Forever rare-pet list, 2026-10-03; NPC IDs from the same source).
  {name="Mokwa",family="Cat",minLevel=7,maxLevel=7,zone="Mulgore",npcID=205382},
  {name="Raluk",family="Cat",minLevel=7,maxLevel=7,zone="Durotar",npcID=208124},
  {name="Jorul",family="Bear",minLevel=8,maxLevel=8,zone="Dun Morogh",npcID=208812},
  {name="Mowgh",family="Bear",minLevel=8,maxLevel=8,zone="Teldrassil",npcID=209928},
  {name="Kackle",family="Crocolisk",minLevel=15,maxLevel=16,zone="Loch Modan",npcID=210107},
  {name="Koartul",family="Turtle",minLevel=25,maxLevel=25,zone="Hillsbrad Foothills",npcID=211951,elite=true},
  {name="Carrodin",family="Bird of Prey",minLevel=25,maxLevel=25,zone="Wetlands",npcID=211965},
  {name="Zopilote",family="Carrion Bird",minLevel=43,maxLevel=43,zone="Tanaris",npcID=222243,elite=true},
  {name="Shal'ma",family="Cat",minLevel=9,maxLevel=9,zone="Durotar",npcID=276198,new=true},
  {name="Fernfeather",family="Tallstrider",minLevel=10,maxLevel=10,zone="Zephras Isle",npcID=256492,new=true},
  {name="Nightscreech",family="Bird of Prey",minLevel=10,maxLevel=10,zone="Teldrassil",npcID=276101,new=true},
  {name="Ghostfang",family="Cat",minLevel=10,maxLevel=10,zone="Dun Morogh",npcID=276111,new=true},
  {name="Matriarch Bristlefur",family="Bear",minLevel=10,maxLevel=10,zone="Elwynn Forest",npcID=276189,new=true},
  {name="Coldrasp",family="Wolf",minLevel=12,maxLevel=12,zone="Tirisfal Glades",npcID=274300,new=true},
  {name="Mystmane",family="Bear",minLevel=13,maxLevel=13,zone="Zephras Isle",npcID=259388,new=true},
  {name="Slydris",family="Fox",zone="Zephras Isle",npcID=255887,new=true,elite=true},
}
-- Creature GUID: Creature-0-<server>-<instance>-<zoneUID>-<npcID>-<spawnUID>.
-- The NPC ID is the 6th dash-separated field (Vehicle/Pet GUIDs use the same layout).
local function NpcIDFromGUID(guid)
  if type(guid) ~= "string" then return nil end
  local unitType, _, _, _, _, npcID = strsplit("-", guid)
  if unitType ~= "Creature" and unitType ~= "Vehicle" then return nil end
  return tonumber(npcID)
end
R.NpcIDFromGUID = NpcIDFromGUID
local function NameKey(name)
  return string.lower((name or ""):gsub("[%s%p]",""))
end
function R:Build()
  self.entries, self.byName, self.byNpcID = {}, {}, {}
  local observed = PetSkillScoutDB and PetSkillScoutDB.observedCreatureIDs or {}
  -- Database.lua records carry the complete spawn list; match them by NPC ID.
  local beastsByNpc={}
  for _,beast in ipairs(PSS.Beasts or {}) do
    if beast.npcID and beast.verifiedCoords and beast.spawnPoints and not beastsByNpc[beast.npcID] then
      beastsByNpc[beast.npcID]=beast
    end
  end
  for _,data in ipairs(catalogue) do
    local resolvedNPC = tonumber(data.npcID)
    local match = resolvedNPC and beastsByNpc[resolvedNPC]
    local spawn = resolvedNPC and PSS.RareSpawns and PSS.RareSpawns[resolvedNPC]
    local mapID, points
    if match then
      mapID, points = match.mapID, match.spawnPoints
    elseif spawn then
      mapID, points = spawn.mapID or (spawn.zone and PSS:ZoneMapID(spawn.zone)), spawn.points
    end
    -- Anchor icon on the spawn point closest to the centre of the area.
    local ax, ay
    if points and #points>0 then
      local sx, sy = 0, 0
      for _,p in ipairs(points) do sx, sy = sx+p[1], sy+p[2] end
      sx, sy = sx/#points, sy/#points
      local best
      for _,p in ipairs(points) do
        local d=(p[1]-sx)^2+(p[2]-sy)^2
        if not best or d<best then best, ax, ay = d, p[1], p[2] end
      end
    end
    local id = data.name
    local hasCoords = mapID and ax and true or false
    local beast={
      id="rare-"..id,npcID=resolvedNPC,displayID=PSS.DisplayIDs and resolvedNPC and PSS.DisplayIDs[resolvedNPC] or nil,
      name=data.name,family=data.family,minLevel=data.minLevel,maxLevel=data.maxLevel,
      zone=data.zone,x=ax,y=ay,mapID=mapID,spawnPoints=points,verifiedCoords=hasCoords,
      rare=true,new=data.new,elite=data.elite,
      source=match and "PetSkillScout database" or (spawn and "mmonster Forever map") or nil,
    }
    local entry={id=id,name=data.name,zone=data.zone,family=data.family,
      minLevel=data.minLevel,maxLevel=data.maxLevel,beast=beast,skills={},new=data.new,elite=data.elite}
    self.byName[string.lower(data.name)]=entry
    -- NPC IDs work on every client language; names only match English clients.
    local npc = resolvedNPC or tonumber(observed[data.name])
    if npc then self.byNpcID[npc]=entry end
    table.insert(self.entries,entry)
  end
  table.sort(self.entries,function(a,b) return a.name<b.name end)
end
function R:IsCollected(entry)
  return PetSkillScoutDB and PetSkillScoutDB.rareCollected and PetSkillScoutDB.rareCollected[entry.id] == true
end
function R:SetCollected(entry, value)
  if not PetSkillScoutDB then return end
  PetSkillScoutDB.rareCollected = PetSkillScoutDB.rareCollected or {}
  PetSkillScoutDB.rareCollected[entry.id] = value and true or nil
end
function R:IsWanted(entry)
  return PetSkillScoutDB and PetSkillScoutDB.rareWanted and PetSkillScoutDB.rareWanted[entry.id] == true
end
function R:SetWanted(entry, value)
  if not PetSkillScoutDB then return end
  PetSkillScoutDB.rareWanted = PetSkillScoutDB.rareWanted or {}
  PetSkillScoutDB.rareWanted[entry.id] = value and true or nil
end
function R:Inspect(unit)
  if not UnitExists or not UnitExists(unit) then return end
  local dead = UnitIsDead and UnitIsDead(unit)
  local npc = NpcIDFromGUID(UnitGUID and UnitGUID(unit))
  -- Prefer the language-independent NPC ID match.
  local entry = npc and self.byNpcID[npc]
  if not entry then
    local name = UnitName and UnitName(unit)
    if not name then return end
    entry = self.byName[string.lower(name)]
    if not entry then return end
    -- Same name but a different known NPC: a name collision, not the rare.
    if npc and entry.beast.npcID and npc ~= tonumber(entry.beast.npcID) then return end
  end
  -- A corpse: start the respawn timer, no alert.
  if dead then
    if PSS.RareTimer then PSS.RareTimer:MarkGone(entry, "corpse") end
    return
  end
  -- A live creature GUID is the strongest source for custom Forever NPC IDs.
  -- Save it for subsequent 3D previews, but never overwrite the curated catalogue.
  if npc and PetSkillScoutDB then
    PetSkillScoutDB.observedCreatureIDs = PetSkillScoutDB.observedCreatureIDs or {}
    PetSkillScoutDB.observedCreatureIDs[entry.name] = npc
    if not entry.beast.npcID then self.byNpcID[npc] = entry end
  end
  self:AlertName(entry.name, unit)
end
-- Nameplate scanning: modern unit tokens where supported, plus legacy WorldFrame plates.
-- The legacy path reads visible UI nameplates; it cannot enumerate unseen creatures.
local function IsShown(frame)
  if not frame then return false end
  if frame.IsShown then return frame:IsShown() end
  return frame.IsVisible and frame:IsVisible()
end
local function TextFromRegion(region)
  if region and region.GetObjectType and region:GetObjectType() == 'FontString' and region.GetText then
    local value=region:GetText()
    if type(value)=='string' and value~='' then return value end
  end
end
local function FindRareName(frame, depth)
  if not frame or depth>2 then return nil end
  if frame.GetRegions then
    local regions={frame:GetRegions()}
    for _,r in ipairs(regions) do
      local value=TextFromRegion(r)
      if value and R.byName[string.lower(value)] then return value end
    end
  end
  if frame.GetChildren then
    local children={frame:GetChildren()}
    for _,child in ipairs(children) do
      local value=FindRareName(child,depth+1)
      if value then return value end
    end
  end
end
local function LooksLikeNameplate(frame)
  if not frame or not IsShown(frame) or not frame.GetChildren then return false end
  -- Do not scan arbitrary world widgets: a nameplate has a visible health status bar.
  local children={frame:GetChildren()}
  for _,child in ipairs(children) do
    if child.GetObjectType and child:GetObjectType()=='StatusBar' and IsShown(child) then return true end
    if child.GetChildren then
      local nested={child:GetChildren()}
      for _,bar in ipairs(nested) do
        if bar.GetObjectType and bar:GetObjectType()=='StatusBar' and IsShown(bar) then return true end
      end
    end
  end
  return false
end
-- Sighting log: when and where each rare was last seen (player position).
function R:RecordSeen(entry)
  if not (entry and PetSkillScoutDB) then return end
  PetSkillScoutDB.rareSeen = PetSkillScoutDB.rareSeen or {}
  local rec = PetSkillScoutDB.rareSeen[entry.id] or {n=0}
  local now = time and time() or 0
  -- Count separate sightings, not every nameplate refresh.
  if not rec.t or now - rec.t > 300 then rec.n = (rec.n or 0) + 1 end
  rec.t = now
  if PSS.Nav then
    local mapID, x, y = PSS.Nav:PlayerPos()
    if mapID then rec.mapID, rec.x, rec.y = mapID, math.floor(x*1000)/10, math.floor(y*1000)/10 end
  end
  PetSkillScoutDB.rareSeen[entry.id] = rec
  if PSS.RareTimer then PSS.RareTimer:SeenAlive(entry, now) end
  if PSS.Sync then PSS.Sync:Broadcast(entry, rec) end
end

function R:LastSeen(entry)
  return entry and PetSkillScoutDB and PetSkillScoutDB.rareSeen and PetSkillScoutDB.rareSeen[entry.id]
end

-- "Last seen 2 h ago (Dun Morogh 34.5, 41.8) · 3x" or nil when never seen.
function R:SeenText(entry)
  local rec = self:LastSeen(entry)
  if not (rec and rec.t) then return nil end
  local age = math.max(0, (time and time() or rec.t) - rec.t)
  local when
  if age < 60 then when = PSS:L("seenJustNow")
  elseif age < 3600 then when = string.format(PSS:L("seenAgo"), string.format(PSS:L("unitMin"), math.floor(age/60)))
  elseif age < 86400 then when = string.format(PSS:L("seenAgo"), string.format(PSS:L("unitHour"), math.floor(age/3600)))
  else when = string.format(PSS:L("seenAgo"), string.format(PSS:L("unitDay"), math.floor(age/86400))) end
  local where = ""
  if rec.x and rec.y then where = string.format(" (%.1f, %.1f)", rec.x, rec.y) end
  local count = (rec.n and rec.n > 1) and ("  ·  " .. rec.n .. "x") or ""
  return when .. where .. count
end

-- Wolf howl from the game files (classic wolf, then Draenor wolf), raid
-- warning sound if neither plays. Master channel: heard with effects muted.
local HOWLS = {564211, 929455}
function R:Howl()
  if PlaySoundFile then
    for _, id in ipairs(HOWLS) do
      local ok, willPlay = pcall(PlaySoundFile, id, "Master")
      if ok and willPlay then return end
    end
  end
  if PlaySound then pcall(PlaySound, 8959, "Master") end
end

-- unit (optional): the unit token the rare was seen on, used for the portrait.
function R:AlertName(name, unit)
  if not name then return end
  local entry=self.byName[string.lower(name)]
  if not entry then return end
  self:RecordSeen(entry)
  if PSS.RareMap then PSS.RareMap:Refresh() end
  local now=GetTime and GetTime() or 0
  if self.lastAlert[entry.name] and now-self.lastAlert[entry.name]<90 then return end
  self.lastAlert[entry.name]=now
  local chat = not PetSkillScoutDB or PetSkillScoutDB.rareChat ~= false
  if chat then PSS:Print(PSS:L('rareSpotted')..entry.name..' ('..(entry.zone or '?')..')') end
  if chat and RaidNotice_AddMessage and RaidWarningFrame then
    local message=PSS:L('rareWarning')..entry.name
    pcall(RaidNotice_AddMessage,RaidWarningFrame,PSS:Safe(message),ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
  end
  if not PetSkillScoutDB or PetSkillScoutDB.rareSound ~= false then R:Howl() end
  if PSS.RareAlert and (not PetSkillScoutDB or PetSkillScoutDB.rareAlertPopup ~= false) then
    PSS.RareAlert:Show(entry, unit)
  end
  if PSS.Queue then pcall(PSS.Queue.OnSpotted, PSS.Queue, entry) end
end
-- Legacy polling is only needed on clients without NAME_PLATE_UNIT_ADDED.
-- Modern clients get one event per plate, so nothing is scanned every frame.
function R:ScanNameplates()
  if not PetSkillScoutDB or PetSkillScoutDB.rareRadarEnabled==false then return end
  if not next(self.byName) then return end
  if WorldFrame and WorldFrame.GetChildren then
    local plates={WorldFrame:GetChildren()}
    for _,plate in ipairs(plates) do
      if LooksLikeNameplate(plate) then self:AlertName(FindRareName(plate,0)) end
    end
  end
end
R.frame=CreateFrame('Frame')
R.frame:RegisterEvent('PLAYER_TARGET_CHANGED')
R.frame:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
R.frame:RegisterEvent('PLAYER_ENTERING_WORLD')
-- Unsupported events cannot be registered on some older Forever builds.
local hasPlateEvents = pcall(R.frame.RegisterEvent,R.frame,'NAME_PLATE_UNIT_ADDED')
  and C_NamePlate ~= nil
R.frame:SetScript('OnEvent',function(_,event,unit)
  if event=='PLAYER_ENTERING_WORLD' then
    R:Build()
    -- Plates that were already visible before the zone-in fire no added event.
    if hasPlateEvents and C_NamePlate.GetNamePlates then
      local ok,plates=pcall(C_NamePlate.GetNamePlates)
      if ok and type(plates)=='table' then
        for _,plate in ipairs(plates) do
          local token=plate.namePlateUnitToken
          if token then R:Inspect(token) end
        end
      end
    end
    return
  end
  if not PetSkillScoutDB or PetSkillScoutDB.rareRadarEnabled==false then return end
  if event=='NAME_PLATE_UNIT_ADDED' then
    if unit then R:Inspect(unit) end
  else
    R:Inspect(event=='PLAYER_TARGET_CHANGED' and 'target' or 'mouseover')
  end
end)
if not hasPlateEvents then
  local elapsed=0
  R.frame:SetScript('OnUpdate',function(_,dt)
    elapsed=elapsed+(dt or 0)
    if elapsed<1.0 then return end
    elapsed=0
    R:ScanNameplates()
  end)
end
