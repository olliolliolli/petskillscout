-- PetSkillScout - WoW: Forever Interface 16001
-- Data-first helper. Never invents spawn coordinates or claims route/pathfinding.
local ADDON, PSS = ...
PSS = PSS or {}
_G.PetSkillScout = PSS
PSS.name = ADDON or "PetSkillScout"
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
PSS.version = (GetMeta and GetMeta(PSS.name, "Version")) or "2.6.1"
PSS.events = CreateFrame("Frame")
PSS.player = { faction = "Unknown", race = "Unknown", level = 1, zone = "Unknown", mapID = nil, x = nil, y = nil }
PSS.filters = { ability = "Bite", rank = 3, family = "All", minLevel = 1, maxLevel = 60 }
PSS.selected = nil

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

-- WoW: Forever (12.x engine) returns some unit values as "secret": they can be
-- shown on widgets but comparing them, doing math on them or printing them throws.
function PSS.IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end

-- The game's own fonts (tooltips, chat, raid warnings) lack some glyphs that the
-- addon font has, e.g. the middle dot. Use plain equivalents there.
function PSS:Safe(text)
    if type(text) ~= "string" then return text end
    text = text:gsub("%s*\194\183%s*", ", ")      -- middle dot
    text = text:gsub("\226\128\147", "-")         -- en dash
    text = text:gsub("\226\128\166", "...")       -- ellipsis
    text = text:gsub("\194\171", '"'):gsub("\194\187", '"') -- guillemets
    text = text:gsub("\195\151", "x")              -- multiplication sign
    return text
end

function PSS:Print(msg)
    local prefix = "|cff70d6ffPetSkillScout|r: "
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(prefix .. PSS:Safe(tostring(msg)))
    elseif print then print("PetSkillScout: " .. tostring(msg)) end
end

function PSS:RefreshPlayer()
    local faction = SafeCall(UnitFactionGroup, "player")
    local raceName = SafeCall(UnitRace, "player")
    local level = SafeCall(UnitLevel, "player")
    local zone = SafeCall(GetRealZoneText) or SafeCall(GetZoneText) or "Unknown"
    local mapID = SafeCall(C_Map and C_Map.GetBestMapForUnit, "player")
    local pos
    if mapID and C_Map and C_Map.GetPlayerMapPosition then
        pos = SafeCall(C_Map.GetPlayerMapPosition, mapID, "player")
    end
    local x, y
    if pos and pos.GetXY then x, y = SafeCall(pos.GetXY, pos) end
    self.player.faction = faction or "Unknown"
    self.player.race = raceName or "Unknown"
    self.player.level = tonumber(level) or 1
    self.player.zone = zone or "Unknown"
    self.player.mapID = mapID
    self.player.x, self.player.y = x, y
    self:LearnZoneMap(mapID)
end

-- Zone name -> uiMapID. Classic zones come from the database; zones new in
-- Forever (e.g. Zephras Isle) are learned the first time the player is there.
function PSS:ZoneMapID(zone)
    if not zone then return nil end
    if not self.zoneMapIDs then
        self.zoneMapIDs = {}
        for _, b in ipairs(self.Beasts or {}) do
            if b.zone and b.mapID then self.zoneMapIDs[b.zone] = b.mapID end
        end
    end
    local learned = PetSkillScoutDB and PetSkillScoutDB.zoneMapIDs
    return self.zoneMapIDs[zone] or (learned and learned[zone])
end

function PSS:LearnZoneMap(mapID)
    if not (mapID and C_Map and C_Map.GetMapInfo and PetSkillScoutDB) then return end
    -- Walk up from sub-zones/caves to the zone map (UIMapType.Zone == 3).
    local id, guard = mapID, 0
    while id and guard < 6 do
        local info = SafeCall(C_Map.GetMapInfo, id)
        if not info then return end
        if info.mapType == 3 then
            PetSkillScoutDB.zoneMapIDs = PetSkillScoutDB.zoneMapIDs or {}
            if info.name and PetSkillScoutDB.zoneMapIDs[info.name] ~= id then
                PetSkillScoutDB.zoneMapIDs[info.name] = id
                self.zoneMapsChanged = true
            end
            return
        end
        if not info.mapType or info.mapType < 3 then return end
        id, guard = info.parentMapID, guard + 1
    end
end

function PSS:InitializeDB()
    if type(PetSkillScoutDB) ~= "table" then PetSkillScoutDB = {} end
    PetSkillScoutDB.language = PetSkillScoutDB.language or "en"
    PetSkillScoutDB.theme = (PetSkillScoutDB.theme == "classic" or PetSkillScoutDB.theme == "blizzard" or PetSkillScoutDB.theme == "moonglade") and PetSkillScoutDB.theme or "journal"
    PetSkillScoutDB.tracked = PetSkillScoutDB.tracked or {}
    -- Fields from older builds that are no longer used.
    PetSkillScoutDB.progress, PetSkillScoutDB.visited, PetSkillScoutDB.found = nil, nil, nil
    self.tracked = PetSkillScoutDB.tracked
    -- Builds before 1.1.0 saved the zone UID from creature GUIDs as the NPC ID.
    -- Drop those values once; correct IDs are re-learned when rares are seen.
    if not PetSkillScoutDB.observedIDsV2 then
        PetSkillScoutDB.observedCreatureIDs = nil
        PetSkillScoutDB.observedIDsV2 = true
    end
end

function PSS:IsTracked(beast)
    local key = type(beast) == "table" and beast.id or beast
    return key and PetSkillScoutDB and PetSkillScoutDB.tracked and PetSkillScoutDB.tracked[key] == true
end

function PSS:SetTracked(beast, value)
    local key = type(beast) == "table" and beast.id or beast
    if not key then return end
    PetSkillScoutDB.tracked = PetSkillScoutDB.tracked or {}
    PetSkillScoutDB.tracked[key] = value and true or nil
    self.tracked = PetSkillScoutDB.tracked
    if self.Map and self.Map.RefreshTrackedPins then self.Map:RefreshTrackedPins() end
end

function PSS:Open()
    if self.UI and self.UI.Toggle then self.UI:Toggle() end
end

SLASH_PETSKILLSCOUT1 = "/petskills"
SLASH_PETSKILLSCOUT2 = "/pss"
SlashCmdList.PETSKILLSCOUT = function(msg)
    msg = (msg or ""):lower()
    if msg == "stableslots" then
        if PSS.Stable then PSS.Stable:InspectSlots() end
    elseif msg == "stabledebug" then
        if PSS.Stable then PSS.Stable:Debug(); PSS.Stable:InspectUI() end
    elseif msg == "petdebug" then
        if PSS.MyPet and PSS.MyPet.Debug then PSS.MyPet:Debug() end
    elseif msg == "arrow" then
        if PSS.Nav then PSS.Nav:ClearTarget() end
    elseif msg == "tooltip" then
        PetSkillScoutDB.tooltip = PetSkillScoutDB.tooltip == false
        PSS:Print("Tooltip: " .. (PetSkillScoutDB.tooltip and "on" or "off"))
    elseif msg == "mapdebug" then
        if PSS.RareMap then PSS.RareMap:Debug() end
    elseif msg == "guardtest" or msg == "guardtest aggro" then
        if PSS.PetGuard then PSS.PetGuard:Test(msg == "guardtest aggro" and "aggro" or "fall") end
    elseif msg == "raretest" then
        if PSS.RareAlert then PSS.RareAlert:Test() end
    elseif msg == "settings" or msg == "config" or msg == "options" then
        if PSS.UI and PSS.UI.Open then PSS.UI:Open("settings") end
    elseif msg == "rares" then
        if PSS.UI and PSS.UI.Open then PSS.UI:Open("rares") end
    elseif msg == "pet" then
        if PSS.UI and PSS.UI.Open then PSS.UI:Open("pet") end
    elseif msg == "route" then
        if PSS.UI and PSS.UI.Open then PSS.UI:Open("route") end
    elseif msg == "route next" or msg == "next" then
        if PSS.Route and not PSS.Route:Go() then PSS:Print(PSS:L("routeNothing")) end
    elseif msg == "move" or msg == "unlock" then
        if PSS.Layout then PSS.Layout:Unlock(not PSS.Layout.unlocked) end
    elseif msg == "ammo" then
        if PSS.Ammo then PSS.Ammo:Report() end
    elseif msg == "passport" or msg == "card" then
        if PSS.UI and PSS.UI.ShowPassport then PSS.UI:Create(); PSS.UI:ShowPassport() end
    elseif msg == "share" then
        if PSS.PetLink then PSS.PetLink:Share() end
    elseif msg == "quests" or msg == "quest" then
        if PSS.UI and PSS.UI.Open then PSS.UI:Open("quests") end
    elseif msg == "collection" or msg == "looks" then
        if PSS.UI and PSS.UI.Open then PSS.UI:Open("collection") end
    elseif msg == "queue" then
        if PSS.Queue then
            if PSS.Queue.mine then PSS.Queue:Leave() elseif PSS.Queue.near then PSS.Queue:Join(PSS.Queue.near) end
        end
    elseif msg == "scan" then
        -- Refresh silently; the addon only posts its startup command hint to chat.
        PSS:RefreshPlayer()
    else
        PSS:Open()
    end
end

-- Diagnostics: name the function if the client ever blocks this addon.
local blockWatch = CreateFrame("Frame")
pcall(blockWatch.RegisterEvent, blockWatch, "ADDON_ACTION_FORBIDDEN")
pcall(blockWatch.RegisterEvent, blockWatch, "ADDON_ACTION_BLOCKED")
local blockSeen = {}
blockWatch:SetScript("OnEvent", function(_, event, addon, func)
  if addon ~= PSS.name or blockSeen[tostring(func)] then return end
  blockSeen[tostring(func)] = true
  PSS:Print("blocked: " .. tostring(func) .. " (" .. tostring(event) .. ") - please report this")
end)

PSS.events:RegisterEvent("ADDON_LOADED")
PSS.events:RegisterEvent("PLAYER_ENTERING_WORLD")
PSS.events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
PSS.events:RegisterEvent("PLAYER_LEVEL_UP")
PSS.events:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == PSS.name then
        PSS:InitializeDB()
        PSS:RefreshPlayer()
        if PSS.CreateLauncher then PSS:CreateLauncher() end
        PSS:Print(PSS:L("loaded"))
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_LEVEL_UP" then
        PSS:RefreshPlayer()
        if PSS.UI and PSS.UI.Refresh then PSS.UI:Refresh() end
    end
end)
