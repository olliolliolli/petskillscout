-- Ammo: arrows / bullets left, warnings when running low or entering a dungeon
-- with too few, and the nearest place to buy more. Ammo vendors are learned when
-- the player opens a merchant that sells ammo (and shared with guild / group
-- through Sync); until then the nearest friendly town is suggested.
local PSS = PetSkillScout
PSS.Ammo = {}
local A = PSS.Ammo

-- Towns and cities with a general goods / ammo vendor. Positions: mmonster WoW
-- Forever world map (town markers), converted to zone coordinates with the
-- AtlasData.lua zone fits. faction: A Alliance, H Horde, N neutral.
A.TOWNS = {
  {name="Anvilmar",               zone="Dun Morogh",           mapID=1426, x=29.6, y=68.6, faction="A"},
  {name="Brill",                  zone="Tirisfal Glades",      mapID=1420, x=61.3, y=52.5, faction="H"},
  {name="Darkshire",              zone="Duskwood",             mapID=1431, x=74.3, y=46.5, faction="A"},
  {name="Deathknell",             zone="Tirisfal Glades",      mapID=1420, x=32.0, y=64.9, faction="H"},
  {name="Goldshire",              zone="Elwynn Forest",        mapID=1429, x=43.0, y=66.7, faction="A"},
  {name="Ironforge",              zone="Dun Morogh",           mapID=1426, x=53.9, y=35.4, faction="A"},
  {name="Kharanos",               zone="Dun Morogh",           mapID=1426, x=46.8, y=52.2, faction="A"},
  {name="Lakeshire",              zone="Redridge Mountains",   mapID=1433, x=28.0, y=45.5, faction="A"},
  {name="Menethil Harbor",        zone="Wetlands",             mapID=1437, x=11.0, y=55.4, faction="A"},
  {name="Northshire Abbey",       zone="Elwynn Forest",        mapID=1429, x=49.9, y=41.8, faction="A"},
  {name="Sentinel Hill",          zone="Westfall",             mapID=1436, x=58.7, y=46.8, faction="A"},
  {name="Stormwind",              zone="Elwynn Forest",        mapID=1429, x=34.4, y=52.7, faction="A"},
  {name="The Sepulcher",          zone="Silverpine Forest",    mapID=1421, x=43.8, y=40.3, faction="H"},
  {name="Undercity",              zone="Tirisfal Glades",      mapID=1420, x=62.2, y=65.9, faction="H"},
  {name="Thelsamar",              zone="Loch Modan",           mapID=1432, x=35.3, y=48.2, faction="A"},
  {name="Southshore",             zone="Hillsbrad Foothills",  mapID=1424, x=50.3, y=56.5, faction="A"},
  {name="Tarren Mill",            zone="Hillsbrad Foothills",  mapID=1424, x=62.4, y=18.3, faction="H"},
  {name="Refuge Pointe",          zone="Arathi Highlands",     mapID=1417, x=46.8, y=46.6, faction="A"},
  {name="Hammerfall",             zone="Arathi Highlands",     mapID=1417, x=72.5, y=36.6, faction="H"},
  {name="Kargath",                zone="Badlands",             mapID=1418, x=6.8,  y=47.7, faction="H"},
  {name="Bloodhoof Village",      zone="Mulgore",              mapID=1412, x=47.6, y=59.5, faction="H"},
  {name="Thunder Bluff",          zone="Mulgore",              mapID=1412, x=39.4, y=26.9, faction="H"},
  {name="Camp Narache",           zone="Mulgore",              mapID=1412, x=44.8, y=76.3, faction="H"},
  {name="Razor Hill",             zone="Durotar",              mapID=1411, x=53.0, y=42.5, faction="H"},
  {name="Valley of Trials",       zone="Durotar",              mapID=1411, x=42.8, y=68.4, faction="H"},
  {name="Orgrimmar",              zone="Durotar",              mapID=1411, x=46.0, y=12.3, faction="H"},
  {name="Sen'jin Village",        zone="Durotar",              mapID=1411, x=56.3, y=74.5, faction="H"},
  {name="The Crossroads",         zone="The Barrens",          mapID=1413, x=52.4, y=28.9, faction="H"},
  {name="Aldrassil",              zone="Teldrassil",           mapID=1438, x=59.4, y=40.5, faction="A"},
  {name="Dolanaar",               zone="Teldrassil",           mapID=1438, x=56.6, y=60.2, faction="A"},
  {name="Darnassus",              zone="Teldrassil",           mapID=1438, x=31.1, y=55.5, faction="A"},
  {name="Ratchet",                zone="The Barrens",          mapID=1413, x=62.9, y=36.6, faction="N"},
  {name="Booty Bay",              zone="Stranglethorn Vale",   mapID=1434, x=27.3, y=75.8, faction="N"},
  {name="Grom'gol Base Camp",     zone="Stranglethorn Vale",   mapID=1434, x=32.1, y=28.6, faction="H"},
  {name="Astranaar",              zone="Ashenvale",            mapID=1440, x=36.7, y=51.0, faction="A"},
  {name="Stonetalon Peak",        zone="Stonetalon Mountains", mapID=1442, x=37.1, y=7.8,  faction="A"},
  {name="Thalanaar",              zone="Feralas",              mapID=1444, x=91.0, y=46.6, faction="A"},
  {name="Freewind Post",          zone="Thousand Needles",     mapID=1441, x=46.3, y=51.4, faction="H"},
  {name="Sun Rock Retreat",       zone="Stonetalon Mountains", mapID=1442, x=48.1, y=60.3, faction="H"},
  {name="Stonard",                zone="Swamp of Sorrows",     mapID=1435, x=46.9, y=51.7, faction="H"},
  {name="Gadgetzan",              zone="Tanaris",              mapID=1446, x=51.5, y=27.7, faction="N"},
  {name="Camp Mojache",           zone="Feralas",              mapID=1444, x=76.4, y=44.0, faction="H"},
  {name="Theramore Isle",         zone="Dustwallow Marsh",     mapID=1445, x=65.7, y=47.2, faction="A"},
  {name="Aerie Peak",             zone="The Hinterlands",      mapID=1425, x=14.5, y=47.8, faction="A"},
  {name="Everlook",               zone="Winterspring",         mapID=1452, x=61.5, y=39.0, faction="N"},
  {name="Shadowprey Village",     zone="Desolace",             mapID=1443, x=27.1, y=69.5, faction="H"},
  {name="Feathermoon Stronghold", zone="Feralas",              mapID=1444, x=31.3, y=44.9, faction="A"},
  {name="Auberdine",              zone="Darkshore",            mapID=1439, x=38.8, y=42.3, faction="A"},
  {name="Nijel's Point",          zone="Desolace",             mapID=1443, x=65.4, y=9.8,  faction="A"},
  {name="Camp Taurajo",           zone="The Barrens",          mapID=1413, x=45.0, y=58.0, faction="H"},
  {name="Splintertree Post",      zone="Ashenvale",            mapID=1440, x=74.1, y=62.1, faction="H"},
  {name="Revantusk Village",      zone="The Hinterlands",      mapID=1425, x=78.5, y=79.1, faction="H"},
  {name="Brackenwall Village",    zone="Dustwallow Marsh",     mapID=1445, x=37.0, y=31.6, faction="H"},
  {name="Cenarion Hold",          zone="Silithus",             mapID=1451, x=52.8, y=40.3, faction="N"},
}

local AMMO_SLOT, RANGED_SLOT = 0, 18
local CLASS_WEAPON, CLASS_PROJECTILE = 2, 6
local SUB_BOW, SUB_GUN, SUB_CROSSBOW = 2, 3, 18
local SUB_ARROW, SUB_BULLET = 2, 3

local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g = pcall(fn, ...)
  if ok then return a, b, c, d, e, f, g end
end

local function ItemClass(itemID)
  if not itemID then return nil end
  local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local _, _, _, _, _, classID, subclassID = safe(info, itemID)
  return classID, subclassID
end

local function Setting(key, default)
  local v = PetSkillScoutDB and PetSkillScoutDB[key]
  if v == nil then return default end
  return v
end

-- "arrow" / "bullet" for the equipped ranged weapon, nil when it uses no ammo.
function A:Kind()
  local classID, sub = ItemClass(safe(GetInventoryItemID, "player", RANGED_SLOT))
  if classID ~= CLASS_WEAPON then return nil end
  if sub == SUB_GUN then return "bullet" end
  if sub == SUB_BOW or sub == SUB_CROSSBOW then return "arrow" end
  return nil
end

local function BagAmmo(kind)
  local want = kind == "bullet" and SUB_BULLET or SUB_ARROW
  local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
  local itemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
  local total = 0
  for bag = 0, 4 do
    for slot = 1, (safe(numSlots, bag) or 0) do
      local id = safe(itemID, bag, slot)
      if id then
        local classID, sub = ItemClass(id)
        if classID == CLASS_PROJECTILE and sub == want then
          local count
          if C_Container and C_Container.GetContainerItemInfo then
            local info = safe(C_Container.GetContainerItemInfo, bag, slot)
            count = info and info.stackCount
          else
            local _, c = safe(GetContainerItemInfo, bag, slot)
            count = c
          end
          total = total + (tonumber(count) or 0)
        end
      end
    end
  end
  return total
end

-- count (nil when the weapon needs no ammo), kind, equipped item ID.
function A:Count()
  local kind = self:Kind()
  if not kind then return nil end
  local equipped = safe(GetInventoryItemID, "player", AMMO_SLOT)
  if equipped then
    local n = safe(GetInventoryItemCount, "player", AMMO_SLOT)
    if type(n) == "number" then return n, kind, equipped end
  end
  return BagAmmo(kind), kind, equipped
end

-- Nearest place to buy ammo --------------------------------------------------
local function PlayerFaction()
  local f = PSS.player and PSS.player.faction
  if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
end

function A:Vendors()
  return PetSkillScoutDB and PetSkillScoutDB.ammoVendors or {}
end

-- { name, sub, mapID, x, y, dist, vendor = true when an ammo vendor was seen there }
function A:Nearest(kind)
  if not PSS.Nav then return nil end
  local here = { PSS.Nav:PlayerPos() }
  if not here[1] then return nil end
  local best, bestScore
  local function consider(c, weight)
    local d = PSS.Nav:DistanceTo(c.mapID, c.x, c.y, here)
    if d then
      local score = d * weight
      if not bestScore or score < bestScore then best, bestScore, c.dist = c, score, d end
    end
  end
  local key = kind == "bullet" and "b" or "a"
  for npc, v in pairs(self:Vendors()) do
    if v.m and v.x and v.y and (not kind or not v.k or v.k:find(key, 1, true)) then
      -- Known vendors win unless a town is clearly closer.
      consider({name = v.n or "?", sub = v.z, mapID = v.m, x = v.x, y = v.y, vendor = true, npc = npc}, 0.7)
    end
  end
  local mine = PlayerFaction()
  for _, t in ipairs(self.TOWNS) do
    if t.faction == "N" or not mine or t.faction == mine then
      consider({name = t.name, sub = t.zone, mapID = t.mapID, x = t.x, y = t.y}, 1)
    end
  end
  return best
end

function A:Go()
  local count, kind = self:Count()
  local spot = self:Nearest(kind)
  if not spot then PSS:Print(PSS:L("ammoNoPlace")) return nil end
  PSS.Nav:SetTarget({name = spot.name, mapID = spot.mapID, points = {{spot.x, spot.y}}, zone = spot.sub})
  return spot
end

-- Capitalised label ("Arrows") or, with word = true, the word used in sentences.
function A:KindName(kind, word)
  if kind == "bullet" then return PSS:L(word and "ammoBulletsW" or "ammoBullets") end
  return PSS:L(word and "ammoArrowsW" or "ammoArrows")
end

-- "Arrows: 1 240" / "Bullets: 35 (low)"
function A:StatusText()
  local count, kind = self:Count()
  if not count then return nil end
  local text = string.format("%s: %d", self:KindName(kind), count)
  local warn = tonumber(Setting("ammoWarn", 200))
  if warn and count < warn then text = "|cffff7a5c" .. text .. "|r" end
  return text, count, kind
end

function A:PlaceText(spot)
  if not spot then return nil end
  local where = spot.name
  if spot.vendor and spot.sub then where = spot.name .. ", " .. spot.sub end
  local dist = PSS.Nav and PSS.Nav:DistanceText(spot.dist)
  if dist then where = where .. " · " .. dist end
  return where
end

-- Warnings --------------------------------------------------------------------
local state = 0 -- 0 fine, 1 low, 2 critical, 3 empty
local function Notify(text, loud)
  PSS:Print(text)
  if loud and RaidNotice_AddMessage and RaidWarningFrame then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, PSS:Safe(text), ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
  end
end

local function WarnText(key, count, kind)
  local text = string.format(PSS:L(key), count, A:KindName(kind, true))
  local place = A:PlaceText(A:Nearest(kind))
  if place then text = text .. "  " .. string.format(PSS:L("ammoNearest"), place) end
  return text
end

function A:Check()
  local warn = tonumber(Setting("ammoWarn", 200))
  local count, kind = self:Count()
  if not (warn and count) then state = 0 return end
  local level = 0
  if count == 0 then level = 3
  elseif count <= math.max(1, math.floor(warn / 4)) then level = 2
  elseif count < warn then level = 1 end
  if level > state then
    if level == 3 then Notify(WarnText("ammoEmpty", count, kind), true)
    elseif level == 2 then Notify(WarnText("ammoCritical", count, kind), true)
    else Notify(WarnText("ammoLow", count, kind), false) end
  end
  -- Reset after restocking, not on every small fluctuation.
  if count >= warn then state = 0 elseif level > state then state = level end
  if PSS.UI and PSS.UI.view == "pet" and PSS.UI.RefreshAmmo then PSS.UI:RefreshAmmo() end
end

function A:CheckDungeon()
  local need = tonumber(Setting("ammoDungeon", 1000))
  if not need then return end
  local inInstance, kind = safe(IsInInstance)
  if not inInstance or (kind ~= "party" and kind ~= "raid") then return end
  local count, ammoKind = self:Count()
  if count and count < need then
    Notify(string.format(PSS:L("ammoDungeon"), count, self:KindName(ammoKind, true), need), true)
  end
end

-- Merchants -------------------------------------------------------------------
local function MerchantItemID(i)
  local id = safe(GetMerchantItemID, i)
  if id then return id end
  local link = safe(GetMerchantItemLink, i)
  return link and tonumber(link:match("item:(%d+)"))
end

function A:ScanMerchant()
  local count = safe(GetMerchantNumItems)
  if type(count) ~= "number" or count == 0 then return end
  local arrows, bullets = false, false
  for i = 1, count do
    local classID, sub = ItemClass(MerchantItemID(i))
    if classID == CLASS_PROJECTILE then
      if sub == SUB_ARROW then arrows = true elseif sub == SUB_BULLET then bullets = true end
    end
  end
  if not (arrows or bullets) then return end
  local guid = safe(UnitGUID, "npc")
  local npc = type(guid) == "string" and PSS.RarePets and PSS.RarePets.NpcIDFromGUID and PSS.RarePets.NpcIDFromGUID(guid)
  if not npc then return end
  if not PSS.Nav then return end
  local mapID, x, y = PSS.Nav:PlayerPos()
  if not mapID then return end
  local name = safe(UnitName, "npc")
  self:Learn(npc, {n = name, m = mapID, x = math.floor(x * 1000) / 10, y = math.floor(y * 1000) / 10,
    k = (arrows and "a" or "") .. (bullets and "b" or ""), z = PSS.player and PSS.player.zone}, nil)
end

-- Stores a vendor; from = sender name for shared ones. Returns true when new.
function A:Learn(npc, rec, from)
  if not (PetSkillScoutDB and npc and rec and rec.m) then return false end
  PetSkillScoutDB.ammoVendors = PetSkillScoutDB.ammoVendors or {}
  local old = PetSkillScoutDB.ammoVendors[npc]
  if old and (from or (old.m == rec.m and math.abs((old.x or 0) - rec.x) < 1 and math.abs((old.y or 0) - rec.y) < 1)) then
    return false
  end
  rec.t, rec.from = time and time() or 0, from
  PetSkillScoutDB.ammoVendors[npc] = rec
  if not from and PSS.Sync and PSS.Sync.BroadcastVendor then PSS.Sync:BroadcastVendor(npc, rec) end
  return true
end

function A:VendorCount()
  local n = 0
  for _ in pairs(self:Vendors()) do n = n + 1 end
  return n
end

-- Slash: /pss ammo
function A:Report()
  local text, count, kind = self:StatusText()
  if not text then PSS:Print(PSS:L("ammoNotNeeded")) return end
  local spot = self:Nearest(kind)
  PSS:Print(text .. (spot and ("  " .. string.format(PSS:L("ammoNearest"), self:PlaceText(spot))) or ""))
  if spot then self:Go() end
end

A.frame = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "BAG_UPDATE", "UNIT_INVENTORY_CHANGED", "MERCHANT_SHOW", "PLAYER_EQUIPMENT_CHANGED"}) do
  pcall(A.frame.RegisterEvent, A.frame, e)
end
local delay = 0
A.frame:Hide()
A.frame:SetScript("OnUpdate", function(self, elapsed)
  delay = delay - (elapsed or 0)
  if delay > 0 then return end
  self:Hide()
  pcall(A.Check, A)
end)
A.frame:SetScript("OnEvent", function(self, event, unit)
  if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
  if event == "MERCHANT_SHOW" then pcall(A.ScanMerchant, A) return end
  if event == "PLAYER_ENTERING_WORLD" then
    -- Item data may still be loading right after the loading screen.
    delay = 4
    self:Show()
    pcall(A.CheckDungeon, A)
    return
  end
  -- Shooting fires BAG_UPDATE for every arrow: check at most once a second.
  if not self:IsShown() then delay = 1 end
  self:Show()
end)
A.frame.pssKey = "Ammo"
PSS:Every(A.frame, 0.2)
