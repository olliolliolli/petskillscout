-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Fast loot (Settings > Hunter, off by default): when the game auto-loots
-- (auto loot on, or the auto-loot key held), every slot is taken at once and
-- the loot window stays invisible, so there is no opening animation. If
-- something cannot be taken (full bags, a roll, a bind confirmation) the
-- window is shown as usual. Only LootSlot is called - the same action as a
-- click on the item in the loot window; nothing protected is used.
local PSS = PetSkillScout
PSS.FastLoot = {}
local FL = PSS.FastLoot

local OTHERS = {"FasterLoot", "SpeedyAutoLoot", "AutoLooter", "LootSpeed"}

local function DB() return PetSkillScoutDB or {} end
local function Loaded(name)
  local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if not f then return false end
  local ok, v = pcall(f, name)
  return ok and v and true or false
end

-- Another fast-loot addon does the same: stay out of its way.
function FL:Other()
  for _, n in ipairs(OTHERS) do if Loaded(n) then return n end end
end

function FL:Enabled() return DB().fastLoot == true and not self:Other() end

local function AutoLooting(autoLoot)
  if autoLoot ~= nil then return autoLoot and true or false end
  local cvar = GetCVarBool and GetCVarBool("autoLootDefault")
  local key = IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE")
  return (cvar and not key) or (not cvar and key) or false
end

local function ShowFrame()
  local f = LootFrame
  if f and f.SetAlpha then pcall(f.SetAlpha, f, 1) end
  FL.hidden = false
end

function FL:Loot()
  local n = tonumber(GetNumLootItems and GetNumLootItems()) or 0
  for i = n, 1, -1 do
    pcall(LootSlot, i)
  end
  self.taken = n
end

local ev = CreateFrame("Frame")
FL._frame = ev
ev:RegisterEvent("LOOT_READY")
ev:RegisterEvent("LOOT_OPENED")
ev:RegisterEvent("LOOT_CLOSED")
pcall(ev.RegisterEvent, ev, "UI_ERROR_MESSAGE")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "LOOT_READY" then
    if not FL:Enabled() or not AutoLooting(arg1) then return end
    if FL.busy then return end
    FL.busy = true
    -- Hide the window before it fades in; it comes back if anything is left.
    if LootFrame and LootFrame.SetAlpha then pcall(LootFrame.SetAlpha, LootFrame, 0); FL.hidden = true end
    FL:Loot()
    if C_Timer and C_Timer.After then
      C_Timer.After(0.3, function()
        if (tonumber(GetNumLootItems and GetNumLootItems()) or 0) > 0 then ShowFrame() end
      end)
    end
  elseif event == "LOOT_CLOSED" then
    FL.busy = false
    ShowFrame()
  elseif event == "UI_ERROR_MESSAGE" then
    -- e.g. "Inventory is full": let the player see what is left.
    if FL.hidden then ShowFrame() end
  end
end)
