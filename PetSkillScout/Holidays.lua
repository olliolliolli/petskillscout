-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Holidays active today, read from the game calendar. Holiday quests in the
-- quest database carry the event ID (hol, the same IDs as the calendar's
-- holiday events); their map pins show only while that holiday runs.
-- When the client calendar has no holidays at all, holiday quests stay hidden.
local PSS = PetSkillScout
PSS.Holidays = {active = {}, names = {}, scanned = false}
local H = PSS.Holidays

local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c = pcall(fn, ...)
  if ok then return a, b, c end
end
local function InCombat() return InCombatLockdown and InCombatLockdown() end

-- Is the holiday with this event ID on today? (-1 / unknown: no)
function H:IsActive(id)
  id = tonumber(id)
  return id ~= nil and id > 0 and self.active[id] == true
end

-- Reads today's events. The calendar's month is moved to the current one; if
-- the player has the calendar open, it is left alone.
function H:Scan()
  if self.inScan then return end
  self.inScan = true
  local ok, err = pcall(self.DoScan, self)
  self.inScan = false
  if not ok then self.lastError = tostring(err) end
end
function H:DoScan()
  local C = C_Calendar
  if not (C and C.GetNumDayEvents and C.GetDayEvent and C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime) then return end
  if InCombat() then self.pending = true return end
  if CalendarFrame and CalendarFrame.IsShown and CalendarFrame:IsShown() then return end
  local now = Call(C_DateAndTime.GetCurrentCalendarTime)
  if type(now) ~= "table" then return end
  local day, month, year = Plain(now.monthDay), Plain(now.month), Plain(now.year)
  if not (day and month and year) then return end
  if C.SetAbsMonth then Call(C.SetAbsMonth, month, year) end
  local active, names = {}, {}
  local n = tonumber(Plain(Call(C.GetNumDayEvents, 0, day))) or 0
  for i = 1, n do
    local e = Call(C.GetDayEvent, 0, day, i)
    if type(e) == "table" and Plain(e.calendarType) == "HOLIDAY" then
      local id = tonumber(Plain(e.eventID))
      if id then
        active[id] = true
        names[id] = Plain(e.title) or tostring(id)
      end
    end
  end
  local changed = false
  for id in pairs(active) do if not self.active[id] then changed = true end end
  for id in pairs(self.active) do if not active[id] then changed = true end end
  self.active, self.names, self.scanned = active, names, true
  if changed and PSS.QuestPins and PSS.QuestPins.Refresh then PSS.QuestPins:Refresh() end
end

function H:Request()
  if C_Calendar and C_Calendar.OpenCalendar then Call(C_Calendar.OpenCalendar) end
  self:Scan()
end

-- /pss holidays
function H:Print()
  self:Scan()
  local list = {}
  for id, name in pairs(self.names) do list[#list + 1] = name .. " (" .. id .. ")" end
  table.sort(list)
  PSS:Print("holidays today: " .. (#list > 0 and table.concat(list, ", ") or "none") ..
    (C_Calendar and "" or " (no calendar on this client)"))
end

local f = CreateFrame("Frame")
H.frame = f
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "CALENDAR_UPDATE_EVENT_LIST", "PLAYER_REGEN_ENABLED"}) do
  pcall(f.RegisterEvent, f, e)
end
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    if not H.started then
      H.started = true
      if C_Timer and C_Timer.After then C_Timer.After(5, function() pcall(H.Request, H) end) end
      -- Days change while playing: look again every 30 minutes.
      if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(1800, function() pcall(H.Scan, H) end) end
    end
  elseif event == "CALENDAR_UPDATE_EVENT_LIST" then
    pcall(H.Scan, H)
  elseif event == "PLAYER_REGEN_ENABLED" and H.pending then
    H.pending = false
    pcall(H.Scan, H)
  end
end)
