-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Report a problem: a small window with the report page link and a short
-- diagnostic code the player copies (Ctrl+C) into the form. Nothing is sent
-- by the addon itself; no character, realm or target names in the code.
local PSS = PetSkillScout
PSS.REPORT_URL = "https://revaddons.com/report/?addon=pss"

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function Base64(s)
  local out = {}
  for i = 1, #s, 3 do
    local a, b, c = s:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local c1 = math.floor(n / 262144) % 64
    local c2 = math.floor(n / 4096) % 64
    local c3 = math.floor(n / 64) % 64
    local c4 = n % 64
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
      .. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
  end
  return table.concat(out)
end

local function Str(v)
  if v == nil then return "-" end
  if PSS.IsSecret and PSS.IsSecret(v) then return "secret" end
  return (tostring(v):gsub("\n", " | "))
end

function PSS:ReportText()
  local db = PetSkillScoutDB or {}
  local L = {}
  local function Add(s) L[#L + 1] = s end
  local function Get(fn, ...) if type(fn) ~= "function" then return nil end local r = {pcall(fn, ...)}; return r[1] and r[2], r[3] end
  local _, class = Get(UnitClass, "player")
  local _, inst = Get(IsInInstance)
  Add(("v=%s lang=%s class=%s lvl=%s inst=%s"):format(Str(self.version), Str(Get(GetLocale)),
    Str(class), Str((Get(UnitLevel, "player"))), Str(inst)))
  local opts = {}
  for _, k in ipairs({"skinGame", "ownBags", "bagsUI", "skinPlates", "plateExtras", "plateStack", "gearTooltip",
      "gearSpec", "language", "mmButtonsFree"}) do
    opts[#opts + 1] = k .. "=" .. Str(db[k])
  end
  Add("opts: " .. table.concat(opts, " "))
  local G = self.Gear
  if G and G.CarefulAimPct then Add("aim=" .. Str(G:CarefulAimPct())) end
  local SK, MM, QP = self.Skin, self.Minimap or self.MM, self.QuestPins
  Add("errors: skin=" .. Str(SK and SK.lastError) .. " minimap=" .. Str(MM and MM._lastError)
    .. " pins=" .. Str(QP and QP._lastError) .. " holidays=" .. Str(self.Holidays and self.Holidays.lastError))
  return table.concat(L, "\n")
end

function PSS:Report()
  local code = "PSS1:" .. Base64(self:ReportText())
  local f = _G.PetSkillScoutReport
  if not f then
    f = CreateFrame("Frame", "PetSkillScoutReport", UIParent, "BackdropTemplate")
    f:SetSize(460, 190); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetToplevel(true)
    f:SetClampedToScreen(true)
    if f.SetBackdrop then
      f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
      f:SetBackdropColor(0.05, 0.08, 0.07, 0.97); f:SetBackdropBorderColor(0.86, 0.7, 0.35, 1)
    end
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", 12, -10); t:SetPoint("TOPRIGHT", -12, -10); t:SetJustifyH("LEFT")
    t:SetText(PSS:L("reportHint"))
    local link = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    link:SetSize(420, 20); link:SetPoint("TOPLEFT", 18, -32); link:SetAutoFocus(false)
    link:SetText(PSS.REPORT_URL)
    link:SetScript("OnTextChanged", function(self, user) if user then self:SetText(PSS.REPORT_URL); self:HighlightText() end end)
    link:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    link:SetScript("OnEscapePressed", function() f:Hide() end)
    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", 12, -58); sub:SetPoint("TOPRIGHT", -12, -58); sub:SetJustifyH("LEFT")
    sub:SetText(PSS:L("reportCode"))
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -74); sf:SetPoint("BOTTOMRIGHT", -32, 40)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetMaxLetters(0); eb:SetFontObject(ChatFontNormal); eb:SetWidth(400); eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function() f:Hide() end)
    eb:SetScript("OnTextChanged", function(self, user) if user then self:SetText(f.code or ""); self:HighlightText() end end)
    sf:SetScrollChild(eb)
    f.eb = eb
    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(90, 22); close:SetPoint("BOTTOMRIGHT", -12, 10); close:SetText(CLOSE or "Close")
    close:SetScript("OnClick", function() f:Hide() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "PetSkillScoutReport") end
  end
  f.code = code
  f.eb:SetText(code)
  f:Show()
  f.eb:SetFocus(); f.eb:HighlightText()
end
