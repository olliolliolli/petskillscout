-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- The game writes NPC dialogue and quest text in dark brown for its parchment.
-- The theme replaces the parchment with a dark panel, so while such a window
-- is open its dark text is switched to a light colour. Gossip lists are
-- recycled on scrolling, hence the short repeat. Theme off: colours go back.
local PSS = PetSkillScout
PSS.SkinText = {}
local T = PSS.SkinText
T.WINDOWS = {"GossipFrame", "QuestFrame", "ItemTextFrame", "PetitionFrame", "TabardFrame", "GuildRegistrarFrame",
  "SpellBookFrame", "BankFrame", "MailFrame", "OpenMailFrame", "ProfessionsBookFrame", "BlackMarketFrame"}
T.LIGHT = {0.92, 0.89, 0.82}
local changed = setmetatable({}, {__mode = "k"})

function T.IsDark(r, g, b)
  return type(r) == "number" and type(g) == "number" and type(b) == "number"
    and 0.3 * r + 0.59 * g + 0.11 * b < 0.32
end

-- Colour written into the text itself ("|cff000000Our Man in Theramore|r":
-- gossip quest titles, NORMAL_QUEST_DISPLAY) beats SetTextColor: dark codes
-- in the text are swapped for the light colour.
local LIGHT_CODE = string.format("|cff%02x%02x%02x", T.LIGHT[1] * 255, T.LIGHT[2] * 255, T.LIGHT[3] * 255)
local function DarkCode(hex)
  local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
  return T.IsDark(r / 255, g / 255, b / 255)
end
local textChanged = setmetatable({}, {__mode = "k"})
local function FixCodes(fs)
  local ok, text = pcall(fs.GetText, fs)
  text = ok and PSS.Plain(text)
  if type(text) ~= "string" or not text:find("|c", 1, true) then return end
  local out = text:gsub("|c%x%x(%x%x%x%x%x%x)", function(hex) if DarkCode(hex) then return LIGHT_CODE end end)
  if out ~= text then
    if not textChanged[fs] then textChanged[fs] = text end
    pcall(fs.SetText, fs, out)
  end
end
T.FixCodes = FixCodes

local function FixString(fs)
  pcall(FixCodes, fs)
  local ok, r, g, b, a = pcall(fs.GetTextColor, fs)
  if not ok or not T.IsDark(PSS.Plain(r), PSS.Plain(g), PSS.Plain(b)) then return end
  if not changed[fs] then changed[fs] = {r, g, b, a} end
  pcall(fs.SetTextColor, fs, T.LIGHT[1], T.LIGHT[2], T.LIGHT[3])
end

local function Walk(f, depth)
  if depth > 10 then return end
  local okR, regs = pcall(function() return {f:GetRegions()} end)
  for _, r in ipairs(okR and regs or {}) do
    local okK, kind = pcall(r.GetObjectType, r)
    if okK and kind == "FontString" then FixString(r) end
  end
  local okC, kids = pcall(function() return {f:GetChildren()} end)
  for _, c in ipairs(okC and kids or {}) do
    local okV, vis = pcall(c.IsVisible, c)
    if okV and vis then Walk(c, depth + 1) end
  end
end

function T:Scan()
  if not (PSS.Skin and PSS.Skin.active) then
    for fs, c in pairs(changed) do pcall(fs.SetTextColor, fs, c[1], c[2], c[3], c[4]) end
    wipe(changed)
    return
  end
  for _, n in ipairs(self.WINDOWS) do
    local f = _G[n]
    local ok, vis = pcall(function() return f and f:IsVisible() end)
    if ok and vis then Walk(f, 0) end
  end
end

local acc = 0
local ev = CreateFrame("Frame")
ev:SetScript("OnUpdate", function(_, e)
  acc = acc + (e or 0)
  if acc < 0.2 then return end
  acc = 0
  pcall(T.Scan, T)
end)
ev.pssKey = "SkinText"
PSS:Every(ev, 0.2)
