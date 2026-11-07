-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Hunter network chat tab (Settings > Hunter network, off by default): a chat
-- window of its own where every network event appears live, the same lines
-- as in the Network tab. The window is made once (out of combat) with the
-- normal "new chat window" function and gets no other chat; you can drag,
-- close it like any chat tab; once closed it is not made again until the
-- option is switched off and on.
local PSS = PetSkillScout
PSS.NetChat = {}
local NC = PSS.NetChat

local function DB() return PetSkillScoutDB or {} end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
function NC:Enabled() return DB().netChatTab == true and DB().netEnabled ~= false end

local function TabName() return PSS:L("netChatTab") end

-- Our window: the one we made (saved by index) if it still has our name.
function NC:Frame()
  if not GetChatWindowInfo then return nil end
  local want = DB().netChatName or TabName()
  for i = 1, (tonumber(NUM_CHAT_WINDOWS) or 10) do
    local ok, name, _, _, _, _, _, shown, _, docked = pcall(GetChatWindowInfo, i)
    if ok and name == want and (shown or docked) then return _G["ChatFrame" .. i] end
  end
end

function NC:Ensure()
  if not self:Enabled() then return nil end
  local f = self:Frame()
  if f then return f end
  if DB().netChatMade then return nil end -- you closed it
  if InCombat() or self.tried or type(FCF_OpenNewWindow) ~= "function" then return nil end
  self.tried = true -- one attempt per session
  local ok, frame = pcall(FCF_OpenNewWindow, TabName())
  if not ok or not frame then return nil end
  DB().netChatName, DB().netChatMade = TabName(), true
  -- Only our lines in it.
  if ChatFrame_RemoveAllMessageGroups then pcall(ChatFrame_RemoveAllMessageGroups, frame) end
  if ChatFrame_RemoveAllChannels then pcall(ChatFrame_RemoveAllChannels, frame) end
  return frame
end

-- Option off: the window made earlier goes away too.
function NC:Sync()
  if self:Enabled() then return self:Ensure() end
  local f = self:Frame()
  if not f then return end
  if InCombat() then PSS:Soon("netchat", function() NC:Sync() end, 10) return end
  if type(FCF_Close) == "function" then pcall(FCF_Close, f) end
  -- The game's close can stop half way for a docked tab: finish it.
  if self:Frame() then
    if type(FCF_UnDockFrame) == "function" then pcall(FCF_UnDockFrame, f) end
    local id = f.GetID and f:GetID()
    if id and type(SetChatWindowShown) == "function" then pcall(SetChatWindowShown, id, false) end
    if type(SetChatWindowDocked) == "function" and id then pcall(SetChatWindowDocked, id, false) end
    pcall(f.Hide, f)
    local tab = _G[f:GetName() .. "Tab"]
    if tab then pcall(tab.Hide, tab) end
  end
end

function NC:Post(e)
  if not self:Enabled() or not e then return end
  local f = self:Ensure()
  if not (f and f.AddMessage and PSS.UI and PSS.UI.NetEventText) then return end
  local ok, text = pcall(PSS.UI.NetEventText, PSS.UI, e)
  if not ok or not text then return end
  local clock = date and date("%H:%M") or ""
  pcall(f.AddMessage, f, "|cff8a8f88" .. clock .. "|r  " .. text)
end

-- Make the tab soon after login, so it is there before the first event.
local w = CreateFrame("Frame")
w:RegisterEvent("PLAYER_ENTERING_WORLD")
w:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  PSS:Soon("netchat", function() NC:Sync() end, 8)
end)
