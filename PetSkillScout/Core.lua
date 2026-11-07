-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- PetSkillScout - WoW: Forever Interface 16001
-- Data-first helper. Never invents spawn coordinates or claims route/pathfinding.
local ADDON, PSS = ...
PSS = PSS or {}
_G.PetSkillScout = PSS
PSS.name = ADDON or "PetSkillScout"
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
PSS.version = (GetMeta and GetMeta(PSS.name, "Version")) or "3.7.19"
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
-- A secret value (unreadable to addons) becomes nil.
function PSS.Plain(v)
    if PSS.IsSecret and PSS.IsSecret(v) then return nil end
    return v
end

function PSS:Safe(text)
    if type(text) ~= "string" then return text end
    text = text:gsub("%s*\194\183%s*", ", ")      -- middle dot
    text = text:gsub("\226\128\147", "-")         -- en dash
    text = text:gsub("\226\128\166", "...")       -- ellipsis
    text = text:gsub("\194\171", '"'):gsub("\194\187", '"') -- guillemets
    text = text:gsub("\195\151", "x")              -- multiplication sign
    return text
end

-- Runs fn once, a moment later, however often it is asked in between.
-- Blizzard fires layout hooks in bursts (and our own changes can trigger
-- them again); this keeps each burst to one pass instead of one per call.
-- Secure buttons must listen to both mouse down and up: the client runs the
-- action on the phase set by the "ActionButtonUseKeyDown" option (down by
-- default). This tells whether a PostClick belongs to the phase that ran it.
function PSS:ClickRan(down)
  local keyDown = true
  if GetCVarBool then
    local ok, v = pcall(GetCVarBool, "ActionButtonUseKeyDown")
    if ok and v ~= nil then keyDown = v and true or false end
  end
  return (down and true or false) == keyDown
end

-- Map pin drivers only need to run while the world map is open: a hidden
-- frame gets no OnUpdate at all, so they cost nothing the rest of the time.
local mapBound, mapHooked = {}, false
local function HookWorldMap()
  if mapHooked or not (WorldMapFrame and WorldMapFrame.HookScript) then return false end
  mapHooked = true
  WorldMapFrame:HookScript("OnShow", function() for _, f in ipairs(mapBound) do f:Show() end end)
  WorldMapFrame:HookScript("OnHide", function() for _, f in ipairs(mapBound) do f:Hide() end end)
  return true
end
function PSS:OnlyWithWorldMap(f)
  mapBound[#mapBound + 1] = f
  if HookWorldMap() or mapHooked then
    if not WorldMapFrame:IsShown() then f:Hide() end
  end
end
do
  local w = CreateFrame("Frame")
  w:RegisterEvent("PLAYER_ENTERING_WORLD")
  w:SetScript("OnEvent", function(self)
    if HookWorldMap() then
      for _, f in ipairs(mapBound) do f:SetShown(WorldMapFrame:IsShown()) end
      self:UnregisterAllEvents()
    end
  end)
end

-- fn, timed by /pss cpu while a check runs (free otherwise).
function PSS:Timed(key, fn)
  return function(...)
    local P = PSS.Profiler
    if not (P and P.cost and debugprofilestop) then return fn(...) end
    local t = debugprofilestop()
    local r = {fn(...)} -- keep the results (chat filters return them)
    P:Add(key, debugprofilestop() - t)
    return unpack(r)
  end
end

-- Run a frame's OnUpdate on a timer instead of every frame. Most of our
-- OnUpdate handlers only count time until their next pass; called 60-144
-- times a second that counting alone was most of the addon's CPU. The
-- handler gets the timer step as "elapsed"; a hidden frame is skipped, so
-- Show/Hide still switch it on and off.
function PSS:Every(frame, interval)
  local fn = frame and frame:GetScript("OnUpdate")
  if type(fn) ~= "function" or not (C_Timer and C_Timer.NewTicker) then return end
  frame:SetScript("OnUpdate", nil)
  frame.pssTick = fn
  frame.pssTicker = C_Timer.NewTicker(interval, function()
    if frame:IsShown() then
      local P = PSS.Profiler
      if P and P.cost and debugprofilestop then
        local t = debugprofilestop(); pcall(fn, frame, interval)
        P:Add((frame.GetName and frame:GetName() or "timer") .. " " .. tostring(frame.pssKey or ""), debugprofilestop() - t)
      else
        pcall(fn, frame, interval)
      end
    end
  end)
end

-- Hooks on Blizzard functions and scripts, timed by /pss cpu while a check
-- runs (named after the hooked function). Same as hooksecurefunc / HookScript.
local function HookName(a, b)
  if type(a) == "string" then return a end
  local n = type(a) == "table" and a.GetName and a:GetName()
  return (n or "?") .. ":" .. tostring(b)
end
function PSS.HookSecure(a, b, c)
  if type(a) == "string" then return hooksecurefunc(a, PSS:Timed("hook " .. HookName(a), b)) end
  return hooksecurefunc(a, b, PSS:Timed("hook " .. HookName(a, b), c))
end
function PSS.HookScript(f, script, fn)
  return f:HookScript(script, PSS:Timed("hook " .. HookName(f, script), fn))
end

local soonQueued = {}
function PSS:Soon(key, fn, delay)
  if soonQueued[key] then return end
  soonQueued[key] = true
  local function run()
    soonQueued[key] = nil
    local P = PSS.Profiler
    if P and P.cost and debugprofilestop then
      local t = debugprofilestop(); pcall(fn)
      P:Add("pass " .. tostring(type(key) == "string" and key or "bag"), debugprofilestop() - t)
    else pcall(fn) end
  end
  if C_Timer and C_Timer.After then C_Timer.After(delay or 0.1, run) else run() end
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
    PetSkillScoutDB.language = PetSkillScoutDB.language or (({ukUA="uk",plPL="pl",deDE="de",frFR="fr",itIT="it",esES="es",esMX="es",ptBR="pt",ptPT="pt",ruRU="ru"})[GetLocale and GetLocale() or ""] or "en")
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
    -- 3.0.3: the rare alert sound (wolf howl) is on by default now.
    if not PetSkillScoutDB.howlV1 then
        PetSkillScoutDB.rareSound = nil
        PetSkillScoutDB.howlV1 = true
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
    if msg == "gamepad" then
        if PSS.Gamepad then PSS.Gamepad:Print() end
        return
    end
    if msg == "skills" then
        -- Skill lines the addon sees (quests needing Cooking, Fishing... and crafted gear).
        local W = PSS.QuestWorth
        local list = {}
        for line, rank in pairs(W and W:Skills() or {}) do
            if type(line) == "number" then list[#list + 1] = tostring((W.SKILL_EN or {})[line] or line) .. " " .. tostring(rank) end
        end
        table.sort(list)
        -- Raw sources, to see where each skill comes from.
        if type(GetProfessions) == "function" then
            local idx = {GetProfessions()}
            for i = 1, 6 do
                if idx[i] and GetProfessionInfo then
                    local n, _, rank, maxr, _, _, line = GetProfessionInfo(idx[i])
                    PSS:Print(string.format("  GetProfessions[%d]: %s %s/%s line %s", i, tostring(n), tostring(rank), tostring(maxr), tostring(line)))
                end
            end
        end
        if type(GetNumSkillLines) == "function" and GetSkillLineInfo then
            local parts = {}
            for i = 1, (GetNumSkillLines() or 0) do
                local n, header, _, rank = GetSkillLineInfo(i)
                if n and not header then parts[#parts + 1] = tostring(n) .. " " .. tostring(rank) end
            end
            PSS:Print("  skill list: " .. table.concat(parts, ", "))
        end
        PSS:Print("skills: " .. (#list > 0 and table.concat(list, ", ") or "none") ..
            " (GetProfessions " .. tostring(type(GetProfessions) == "function") .. ", skill list " ..
            tostring(type(GetSkillLineInfo) == "function") .. ")")
        return
    end
    if msg == "questdone" then
        local W = PSS.QuestWorth
        if not W then return end
        local got = W:LoadCompleted()
        local n = 0
        for _ in pairs(PetSkillScoutDB.questDone or {}) do n = n + 1 end
        PSS:Print(string.format("questdone: %d from the server now, %d completed quests known", got, n))
        return
    end
    if msg == "questwhy" then
        if PSS.QuestWorth then PSS.QuestWorth:Why(4) end
        return
    end
    if msg == "questsrc" then
        -- Where quest pins come from on the current map: the game's list or the database.
        local mapID = PSS.Nav and PSS.Nav:PlayerPos()
        local W = PSS.QuestWorth
        local game = W and mapID and W:GameAvailable(mapID)
        local n = 0
        for _ in pairs(game or {}) do n = n + 1 end
        PSS:Print(string.format("questsrc: map %s, C_QuestLine %s, game list %s quests", tostring(mapID),
            tostring(C_QuestLine and C_QuestLine.GetAvailableQuestLines ~= nil), game and n or "none"))
        return
    end
    if msg == "pinsreset" then
        if PSS.QuestPins then PSS.QuestPins:ResetHidden() end
        PSS:Print(PSS:L("qPinsReset"))
        return
    end
    if msg == "holidays" then
        if PSS.Holidays then PSS.Holidays:Print() end
        return
    end
    if msg == "turnin" then
        -- What the client says about quests on the map you stand in (Forever check).
        local api = C_QuestLog
        local mapID = C_Map and C_Map.GetBestMapForUnit and PSS.Plain(C_Map.GetBestMapForUnit("player"))
        if not (api and api.GetQuestsOnMap and mapID) then PSS:Print("turnin: no GetQuestsOnMap") return end
        local ok, list = pcall(api.GetQuestsOnMap, mapID)
        PSS:Print("turnin: map " .. tostring(mapID) .. " ok=" .. tostring(ok) .. " quests=" .. tostring(ok and type(list) == "table" and #list or list))
        for i, q in ipairs(ok and type(list) == "table" and list or {}) do
            if i > 12 then break end
            local done = api.IsComplete and select(2, pcall(api.IsComplete, q.questID))
            PSS:Print(string.format("  %s complete=%s x=%s y=%s indicator=%s", tostring(q.questID), tostring(done), tostring(q.x), tostring(q.y), tostring(q.isMapIndicatorQuest)))
        end
        return
    end
    if msg == "announce" then
        if PSS.Announce then PSS.Announce:SendLast() end
        return
    end
    if msg == "netlist" then
        -- Network members as whisper targets, and who the server said is not online.
        local N = PSS.Net
        if not N then return end
        PSS:Print("netlist: list API " .. tostring(type(ListChannelByName) == "function") .. ", my name " ..
            tostring(GetUnitName and GetUnitName("player", true)) .. ", realm " ..
            tostring(GetNormalizedRealmName and GetNormalizedRealmName()))
        local idx = N.DisplayIndex and N:DisplayIndex()
        PSS:Print("netlist: channel list index " .. tostring(idx) .. ", roster read " ..
            tostring(N.ReadRoster and N:ReadRoster(idx)))
        local n = 0
        for who, m in pairs(N.members or {}) do
            n = n + 1
            local bad = N.unreachable and N.unreachable[who]
            PSS:Print(string.format("  %s -> [%s]%s", who, tostring(m.target), bad and "  NOT FOUND" or ""))
        end
        for who in pairs(N.unreachable or {}) do
            if not (N.members and N.members[who]) then PSS:Print("  " .. who .. "  NOT FOUND (dropped)") end
        end
        PSS:Print("netlist: " .. n .. " members")
        return
    end
    if msg == "netdiag" then
        if PSS.Sync and PSS.Sync.Diag then PSS.Sync:Diag() end
        return
    end
    if msg == "chatdebug" then
        -- Chat windows: index, name, docked, shown, tab position (for bug reports).
        for i = 1, tonumber(NUM_CHAT_WINDOWS) or 10 do
            local cf, tab = _G["ChatFrame" .. i], _G["ChatFrame" .. i .. "Tab"]
            local ok, name, _, _, _, _, _, shown, _, docked = pcall(GetChatWindowInfo, i)
            if ok and name and name ~= "" then
                local p, rel, rp, x, y
                if tab and tab.GetPoint then p, rel, rp, x, y = tab:GetPoint(1) end
                PSS:Print(string.format("%d %s docked=%s(%s) shown=%s tab=%s %s %s %.0f %.0f", i, tostring(name),
                    tostring(docked), tostring(cf and cf.isDocked), tostring(shown), tostring(p),
                    tostring(rel and rel.GetName and rel:GetName()), tostring(rp), x or 0, y or 0))
            end
        end
        PSS:Print("PetSkillScout " .. tostring(PSS.version))
        return
    end
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
    elseif msg == "cpu" then
        if PSS.Profiler then PSS.Profiler:Start() end
    elseif msg == "net" or msg == "network" then
        if PSS.UI and PSS.UI.Open then PSS.UI:Open("network") end
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
  if addon ~= PSS.name then return end
  -- Counted per function for the next check of the saved data.
  if PetSkillScoutDB then
    local log = PetSkillScoutDB.blockedLog or {}
    local e = log[tostring(func)] or {n = 0}
    e.n = e.n + 1
    if not e.stack and debugstack then e.stack = debugstack(2, 8, 0) end
    log[tostring(func)] = e
    PetSkillScoutDB.blockedLog = log
  end
  if tostring(func):find("SendChatMessage") and PetSkillScoutDB then PetSkillScoutDB.announceBlocked = true end
  if blockSeen[tostring(func)] then return end
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
