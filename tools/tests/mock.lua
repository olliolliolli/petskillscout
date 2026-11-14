-- Fake WoW client for lua5.1 tests: frames, fonts, quest log, items, timers.
MOCK = {level = 30, faction = "Alliance", class = "HUNTER", done = {}, inlog = {}, owned = {},
  titles = {}, items = {}, prints = {}, timers = {}, events = {}, combat = false, equipped = {}, warnings = {}}
MOCK.track = MOCK_TRACK_EARLY and {} or nil
local frames = {}
MOCK_VERBS = {"Set", "Get", "Is", "Has", "Create", "Enable", "Disable", "Register", "Unregister", "Show", "Hide",
  "Clear", "Add", "Hook", "Start", "Stop", "Play", "Raise", "Lower", "Click", "Lock", "Unlock", "Update", "Release",
  "Highlight", "Unhighlight", "Can", "Adjust", "Refresh", "Stretch", "Flash", "Apply", "Reset"}
local function newObj(kind)
  local o = {kind = kind, shown = true, text = "", scripts = {}, points = {}}
  if MOCK.track then MOCK.track[#MOCK.track + 1] = o end
  local mt = {}
  mt.__index = function(t, k)
    local f = rawget(mt, "m_" .. k)
    if f then return f end
    -- Methods are Capitalized; fields (pssX, bar, ...) and child keys stay nil.
    if type(k) == "string" then
      for _, v in ipairs(MOCK_VERBS) do
        if k:sub(1, #v) == v then return function() return nil end end
      end
    end
    return nil
  end
  mt.m_SetText = function(self, t) self.text = t == nil and "" or tostring(t); if self.fs then self.fs.text = self.text end end
  mt.m_GetText = function(self) return self.text end
  mt.m_SetAttribute = function(self, k, v) self.attr = self.attr or {}; self.attr[k] = v end
  mt.m_GetAttribute = function(self, k) return self.attr and self.attr[k] end
  mt.m_GetStringWidth = function(self) local n = select(2, (self.text or ""):gsub("[^\128-\191]", "")); return n * ((self.fontSize or 13) * 0.55) end
  mt.m_SetFont = function(self, f, s) self.fontSize = s end
  mt.m_Show = function(self) self.shown = true end
  mt.m_Hide = function(self) self.shown = false end
  mt.m_IsShown = function(self) return self.shown end
  mt.m_SetShown = function(self, v) self.shown = v and true or false end
  mt.m_IsVisible = function(self) return self.shown end
  mt.m_SetScript = function(self, n, f) self.scripts[n] = f end
  mt.m_GetScript = function(self, n) return self.scripts[n] end
  mt.m_HookScript = function(self, n, f) self.scripts[n] = f end
  mt.m_CreateTexture = function() return newObj("Texture") end
  mt.m_CreateFontString = function() return newObj("FontString") end
  mt.m_CreateAnimationGroup = function() return newObj("AnimGroup") end
  mt.m_CreateAnimation = function() return newObj("Anim") end
  mt.m_SetFontString = function(self, fs) self.fs = fs end
  mt.m_GetFontString = function(self) return self.fs end
  mt.m_RegisterEvent = function(self, e) MOCK.events[e] = MOCK.events[e] or {}; table.insert(MOCK.events[e], self) end
  mt.m_SetWidth = function(self, w) self.w = w end
  mt.m_GetWidth = function(self) return self.w or 100 end
  mt.m_SetSize = function(self, w, h) self.w, self.h = w, h end
  mt.m_GetHeight = function(self) return self.h or 20 end
  mt.m_SetHeight = function(self, h) self.h = h end
  mt.m_SetPoint = function(self, ...) self.points[#self.points + 1] = {...} end
  mt.m_ClearAllPoints = function(self) self.points = {} end
  mt.m_GetParent = function(self) return self.parent end
  mt.m_GetName = function(self) return self.name end
  mt.m_GetFrameLevel = function() return 1 end
  mt.m_GetCenter = function() return 100, 100 end
  mt.m_GetScale = function() return 1 end
  mt.m_GetEffectiveScale = function() return 1 end
  mt.m_GetAlpha = function() return 1 end
  mt.m_GetValue = function() return 0 end
  mt.m_GetChildren = function() return end
  mt.m_GetRegions = function() return end
  mt.m_GetNumPoints = function() return 0 end
  mt.m_GetVerticalScroll = function() return 0 end
  mt.m_IsMouseOver = function() return false end
  return setmetatable(o, mt)
end
MOCK.newObj = newObj
function CreateFrame(kind, name, parent)
  local f = newObj(kind)
  f.parent, f.name = parent, name
  if name then _G[name] = f; _G[name .. "ScrollBar"] = newObj("Slider") end
  table.insert(frames, f)
  return f
end
UIParent = CreateFrame("Frame", "UIParent")
WorldFrame = CreateFrame("Frame")
Minimap = CreateFrame("Frame", "Minimap")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
GameTooltip.lines = {}
getmetatable(GameTooltip).m_AddLine = function(self, t) table.insert(self.lines, t) end
getmetatable(GameTooltip).m_SetOwner = function(self) self.lines = {} end
getmetatable(GameTooltip).m_NumLines = function(self) return #self.lines end
DEFAULT_CHAT_FRAME = {AddMessage = function(_, m) table.insert(MOCK.prints, m) end}
RaidWarningFrame = {}
ChatTypeInfo = {RAID_WARNING = {r = 1, g = 0.3, b = 0.1}}
function RaidNotice_AddMessage(_, text) table.insert(MOCK.warnings, text) end
SlashCmdList = {}
unpack = unpack or table.unpack
function hooksecurefunc() end
function issecretvalue() return false end
function GetTime() return 1000 end
function time() return 1700000000 end
function UnitLevel(u) if u == "player" then return MOCK.level end return 1 end
function UnitClass() return "Hunter", MOCK.class end
function UnitFactionGroup() return MOCK.faction end
function UnitRace() return "Human" end
function UnitName() return "Tester" end
function UnitExists() return false end
function UnitGUID() return nil end
function GetRealmName() return "Realm" end
function GetRealZoneText() return "Elwynn Forest" end
function GetZoneText() return "Elwynn Forest" end
function GetMaxPlayerLevel() return 60 end
function InCombatLockdown() return MOCK.combat end
function IsShiftKeyDown() return false end
function GetLocale() return "enUS" end
function GetCVar() return "0" end
function GetCVarBool() return false end
function GetInventoryItemLink(_, slot) return MOCK.equipped[slot] end
function GetItemStats() return nil end
function GetItemIcon(id) return "icon" .. id end
function GetItemInfo(id)
  local it = MOCK.items[id]
  if not it then return nil end
  return it.name, "|cff0070dd|Hitem:" .. id .. "|h[" .. it.name .. "]|h|r", it.q or 2
end
function GetItemCount(id) return MOCK.owned[id] or 0 end
C_Item = {}
C_Map = {
  GetBestMapForUnit = function() return 1429 end,
  GetPlayerMapPosition = function() return nil end,
  GetMapInfo = function(id) return {name = "Map" .. id, mapType = 3} end,
}
C_QuestLog = {
  IsQuestFlaggedCompleted = function(id) return MOCK.done[id] == true end,
  GetLogIndexForQuestID = function(id) return MOCK.inlog[id] end,
  GetTitleForQuestID = function(id) return MOCK.titles[id] end,
  RequestLoadQuestByID = function() end,
}
C_Timer = {After = function(s, fn) table.insert(MOCK.timers, fn) end, NewTicker = function() return newObj("Ticker") end, NewTimer = function() return newObj("Timer") end}
function MOCK.RunTimers()
  local n = 0
  while #MOCK.timers > 0 and n < 100 do
    local t = MOCK.timers; MOCK.timers = {}
    for _, fn in ipairs(t) do fn() end
    n = n + 1
  end
end
function MOCK.Fire(event, ...)
  for _, f in ipairs(MOCK.events[event] or {}) do
    local h = f.scripts.OnEvent
    if h then h(f, event, ...) end
  end
end
C_AddOns = {GetAddOnMetadata = function() return "2.5.0" end, IsAddOnLoaded = function() return false end}
FauxScrollFrame_Update = function() end
FauxScrollFrame_GetOffset = function() return 0 end
FauxScrollFrame_SetOffset = function() end
FauxScrollFrame_OnVerticalScroll = function() end
UISpecialFrames = {}
-- Blizzard helper functions (Name_Name) that the tests do not care about.
setmetatable(_G, {__index = function(_, k)
  if type(k) == "string" and k:match("^%u%w*_%u") and not k:match("^C_") then return function() return nil end end
end})
-- WoW string helper: strsplit(sep, text) -> parts (plain separator).
if not strsplit then
  function strsplit(sep, text)
    local out, start = {}, 1
    text = tostring(text or "")
    while true do
      local i = text:find(sep, start, true)
      if not i then out[#out + 1] = text:sub(start); break end
      out[#out + 1] = text:sub(start, i - 1)
      start = i + #sep
    end
    return unpack(out)
  end
end
