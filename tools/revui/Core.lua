-- Copyright (c) 2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- RevUI - flat dark theme for the WoW: Forever interface (Interface 16001).
-- The theme code is shared with PetSkillScout (the hunter addon by the same
-- author) and generated from it; this file is RevUI's own small core: the
-- helpers that code expects, the colour palettes, saved settings and the
-- bridge to PetSkillScout's hunter features when that addon is loaded too.
local ADDON = ...
local R = {}
_G.RevUI = R
R.name = ADDON or "RevUI"
R.AUTHOR = "DarthRev1"
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
R.version = (GetMeta and GetMeta(R.name, "Version")) or "1.0.0"

-- Hunter-only parts of the shared code (tameable badge, pet happiness, pet
-- food in bags, ammo, shot timer, hunter network chat tab) read these from
-- PetSkillScout when it is installed; without it they are nil and skipped.
local BRIDGE = {PetCare = true, Foods = true, Atlas = true, Ammo = true, ShotTimer = true, HawkTimer = true,
  NetChat = true, Beasts = true, NameFamily = true, NameAbility = true, PlaceMinimapButton = true}
setmetatable(R, {__index = function(_, k)
  if not BRIDGE[k] then return nil end
  local P = rawget(_G, "PetSkillScout")
  local v = type(P) == "table" and P[k] or nil
  if type(v) == "function" then return function(_, ...) return v(P, ...) end end
  return v
end})

-- RevUI itself is never "another full UI" for its own theme.
function R:RevUILoaded() return false end

-- WoW: Forever (12.x engine) returns some unit values as "secret": they can be
-- shown on widgets but comparing them, doing math on them or printing them throws.
function R.IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) == true end
function R.Plain(v) if R.IsSecret(v) then return nil end return v end
function R:Safe(text) return text end

-- No profiler in RevUI: timed wrappers are the plain functions.
function R:Timed(_, fn) return fn end
function R:Debug() end

-- Run a frame's OnUpdate on a timer instead of every frame (a hidden frame is
-- skipped, so Show/Hide still switch it on and off).
function R:Every(frame, interval)
  local fn = frame and frame:GetScript("OnUpdate")
  if type(fn) ~= "function" or not (C_Timer and C_Timer.NewTicker) then return end
  frame:SetScript("OnUpdate", nil)
  frame.pssTick = fn
  frame.pssTicker = C_Timer.NewTicker(interval, function()
    if frame:IsShown() then pcall(fn, frame, interval) end
  end)
end

function R.HookSecure(a, b, c)
  if type(a) == "string" then return hooksecurefunc(a, b) end
  return hooksecurefunc(a, b, c)
end
function R.HookScript(f, script, fn) return f:HookScript(script, fn) end

-- Runs fn once, a moment later, however often it is asked in between.
local soonQueued = {}
function R:Soon(key, fn, delay)
  if soonQueued[key] then return end
  soonQueued[key] = true
  local function run() soonQueued[key] = nil; pcall(fn) end
  if C_Timer and C_Timer.After then C_Timer.After(delay or 0.1, run) else run() end
end

function R:Print(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffd9b26dRevUI|r: " .. tostring(msg))
  end
end

-- Translations (Locale.lua fills R.Locale). Language: the game's own.
local LANG = {enUS = "en", enGB = "en", ukUA = "uk", plPL = "pl", deDE = "de", frFR = "fr", itIT = "it",
  esES = "es", esMX = "es", ptBR = "pt", ruRU = "ru"}
function R:Lang()
  local db = RevUIDB
  if db and db.language and self.Locale and self.Locale[db.language] then return db.language end
  return LANG[GetLocale and GetLocale() or "enUS"] or "en"
end
function R:L(key)
  local L = self.Locale or {}
  local d = L[self:Lang()] or L.en or {}
  return d[key] or (L.en and L.en[key]) or key
end

-- Colour palettes (the same three as PetSkillScout's window themes).
local PALETTES = {
  emerald = {
    background={0.050,0.092,0.074}, surface={0.075,0.133,0.106}, surfaceAlt={0.102,0.160,0.125},
    selected={0.122,0.200,0.157}, deep={0.039,0.075,0.059}, gold={0.851,0.698,0.427},
    cream={0.945,0.894,0.776}, muted={0.663,0.737,0.671}, green={0.561,0.878,0.627}, red={1.0,0.47,0.47},
    border={0.173,0.231,0.184}, dim={0.133,0.188,0.165}, ink={0.106,0.078,0.039},
  },
  leather = {
    background={0.095,0.073,0.050}, surface={0.170,0.130,0.084}, surfaceAlt={0.215,0.168,0.108},
    selected={0.330,0.225,0.098}, deep={0.058,0.043,0.028}, gold={0.91,0.72,0.34},
    cream={1.0,0.89,0.66}, muted={0.80,0.71,0.54}, green={0.56,0.86,0.50}, red={1.0,0.45,0.40},
    border={0.46,0.34,0.18}, dim={0.25,0.185,0.10}, ink={0.12,0.08,0.03},
  },
  moonglade = {
    background={0.047,0.051,0.110}, surface={0.075,0.082,0.165}, surfaceAlt={0.098,0.106,0.208},
    selected={0.133,0.141,0.278}, deep={0.035,0.039,0.086}, gold={0.63,0.78,0.98},
    cream={0.90,0.92,1.0}, muted={0.62,0.66,0.82}, green={0.56,0.90,0.78}, red={1.0,0.50,0.55},
    border={0.20,0.22,0.40}, dim={0.14,0.15,0.30}, ink={0.04,0.05,0.12},
  },
}
R.PALETTES = PALETTES
-- The shared code asks R.UI for the theme key and palette.
R.UI = {}
function R.UI.ThemeKey()
  local t = RevUIDB and RevUIDB.theme
  if PALETTES[t] then return t end
  return "emerald"
end
function R.UI:Palette() return PALETTES[R.UI.ThemeKey()] end
-- Info bar "pet" button: opens PetSkillScout's pet page when it is installed.
function R.UI:Open(view)
  local P = rawget(_G, "PetSkillScout")
  if P and P.UI and P.UI.Open then P.UI:Open(view) end
end

-- Saved settings. RevUI is a theme addon: the theme is on after install;
-- things that replace whole game windows or change game settings are off.
R.DEFAULTS = {skinGame = true, theme = "emerald", ownBags = false, bagsUI = true, plateStack = false,
  classPower = true}
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, _, name)
  if name ~= R.name then return end
  self:UnregisterAllEvents()
  RevUIDB = RevUIDB or {}
  for k, v in pairs(R.DEFAULTS) do if RevUIDB[k] == nil then RevUIDB[k] = v end end
end)
