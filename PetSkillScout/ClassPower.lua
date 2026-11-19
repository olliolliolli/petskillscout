-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Class resources for the theme's own unit frames. The layout parks the
-- game's TargetFrame and with it ComboFrame - on WoW: Forever the only place
-- the game shows combo points (Blizzard_UnitFrame/Camelot/ComboFrame.lua:
-- GetComboPoints("player", "target"), max UnitPowerMax(player, ComboPoints),
-- events PLAYER_TARGET_CHANGED / UNIT_POWER_FREQUENT / UNIT_POWER_UPDATE /
-- UNIT_POWER_POINT_CHARGE / UNIT_MAXPOWER; COMBO_TARGET_CHANGED from
-- Camelot/TargetBoundComboPointBar.lua). So:
-- * combo points: a row of flat pips under the target frame, left of the
--   target-of-target frame, while you have points on your target;
-- * druid mana: Forever has no alternate mana bar (AlternatePowerBar loads
--   only in mainline / wrath+), so a thin mana bar under the player frame,
--   right of the pet frame, while a druid is in bear or cat form.
-- Off with the option "classPower" (on by default when the theme is on).
local PSS = PetSkillScout
PSS.ClassPower = {}
local CP = PSS.ClassPower

local FLAT = "Interface\Buttons\WHITE8X8"
local MAX = 5
local function DB() return PetSkillScoutDB or {} end
local function Plain(v) if PSS.IsSecret and PSS.IsSecret(v) then return nil end return v end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
end
local function Col(k, def)
  local S = PSS.Skin
  return (S and S.Colour and S:Colour(k)) or def
end
local function PowerType(name, fallback)
  return Enum and Enum.PowerType and Enum.PowerType[name] or fallback
end

function CP:Enabled()
  local LY, S = PSS.Layout, PSS.Skin
  return DB().classPower ~= false and S and S.active and LY and LY.applied and LY.applied.units and true or false
end

local pips, bar, built
local function Edge(f, c)
  for _, t in ipairs(f.edge) do t:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
end
local function MakeEdges(f)
  f.edge = {}
  for i = 1, 4 do
    local t = f:CreateTexture(nil, "OVERLAY"); t:SetTexture(FLAT); f.edge[i] = t
  end
  f.edge[1]:SetPoint("TOPLEFT"); f.edge[1]:SetPoint("TOPRIGHT"); f.edge[1]:SetHeight(1)
  f.edge[2]:SetPoint("BOTTOMLEFT"); f.edge[2]:SetPoint("BOTTOMRIGHT"); f.edge[2]:SetHeight(1)
  f.edge[3]:SetPoint("TOPLEFT"); f.edge[3]:SetPoint("BOTTOMLEFT"); f.edge[3]:SetWidth(1)
  f.edge[4]:SetPoint("TOPRIGHT"); f.edge[4]:SetPoint("BOTTOMRIGHT"); f.edge[4]:SetWidth(1)
end

local function Build()
  local LY = PSS.Layout
  local units = LY and LY.units
  if built or not (units and units.target and units.player) then return built end
  built = true
  -- Combo points: under the target frame, left side (the target-of-target
  -- frame takes the right 120 px of the row).
  pips = CreateFrame("Frame", nil, units.target)
  pips:SetSize(MAX * 17 - 2, 7)
  pips:SetPoint("TOPLEFT", units.target, "BOTTOMLEFT", 0, -6)
  pips:Hide()
  pips.p = {}
  for i = 1, MAX do
    local p = CreateFrame("Frame", nil, pips)
    p:SetSize(15, 7)
    p:SetPoint("LEFT", pips, "LEFT", (i - 1) * 17, 0)
    p.bg = p:CreateTexture(nil, "BACKGROUND"); p.bg:SetAllPoints(); p.bg:SetTexture(FLAT)
    p.fill = p:CreateTexture(nil, "ARTWORK"); p.fill:SetPoint("TOPLEFT", 1, -1); p.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    p.fill:SetTexture(FLAT)
    MakeEdges(p)
    pips.p[i] = p
  end
  -- Druid mana: under the player frame, right of the pet frame (120 px).
  bar = CreateFrame("StatusBar", nil, units.player)
  bar:SetStatusBarTexture(FLAT)
  bar:SetSize(100, 8)
  bar:SetPoint("TOPRIGHT", units.player, "BOTTOMRIGHT", 0, -6)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND"); bar.bg:SetAllPoints(); bar.bg:SetTexture(FLAT)
  MakeEdges(bar)
  bar:Hide()
  return built
end

function CP:Colours()
  if not built then return end
  local edge, acc = Col("edge", {0.3, 0.3, 0.3, 1}), Col("accent", {0.85, 0.7, 0.43, 1})
  for _, p in ipairs(pips.p) do
    p.bg:SetVertexColor(0.04, 0.04, 0.04, 0.85)
    Edge(p, edge)
    p.fill:SetVertexColor(acc[1], acc[2], acc[3], 1)
  end
  bar.bg:SetVertexColor(0.04, 0.04, 0.04, 0.85)
  Edge(bar, edge)
  local c = PowerBarColor and PowerBarColor.MANA or {r = 0, g = 0.55, b = 1}
  bar:SetStatusBarColor(c.r or 0, c.g or 0.55, c.b or 1)
end

function CP:UpdateCombo()
  if not (built or Build()) then return end
  if not self:Enabled() then pips:Hide(); return end
  local max = Plain(Call(UnitPowerMax, "player", PowerType("ComboPoints", 4)))
  if type(max) ~= "number" or max <= 0 then pips:Hide(); return end
  max = math.min(max, MAX)
  local n = Plain(Call(GetComboPoints, "player", "target"))
  if type(n) ~= "number" or n <= 0 then pips:Hide(); return end
  for i, p in ipairs(pips.p) do
    p:SetShown(i <= max)
    p.fill:SetShown(i <= n)
  end
  -- The last point in a brighter colour: a finisher is fully charged.
  local full = n >= max
  local acc = Col("accent", {0.85, 0.7, 0.43, 1})
  for i = 1, max do
    local f = pips.p[i].fill
    if full then f:SetVertexColor(1, 0.35, 0.2, 1) else f:SetVertexColor(acc[1], acc[2], acc[3], 1) end
  end
  pips:Show()
end

function CP:UpdateMana()
  if not (built or Build()) then return end
  local _, class = UnitClass("player")
  if not self:Enabled() or Plain(class) ~= "DRUID" then bar:Hide(); return end
  local manaType = PowerType("Mana", 0)
  local now = Plain(Call(UnitPowerType, "player"))
  if now == nil or now == manaType then bar:Hide(); return end
  local cur = Plain(Call(UnitPower, "player", manaType))
  local max = Plain(Call(UnitPowerMax, "player", manaType))
  if type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then bar:Hide(); return end
  bar:SetMinMaxValues(0, max)
  bar:SetValue(cur)
  bar:Show()
end

function CP:Refresh()
  if not (built or Build()) then return end
  self:Colours()
  self:UpdateCombo()
  self:UpdateMana()
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "COMBO_TARGET_CHANGED"}) do
  pcall(ev.RegisterEvent, ev, e)
end
for _, e in ipairs({"UNIT_POWER_FREQUENT", "UNIT_POWER_UPDATE", "UNIT_POWER_POINT_CHARGE", "UNIT_MAXPOWER",
    "UNIT_DISPLAYPOWER"}) do
  pcall(ev.RegisterUnitEvent, ev, e, "player")
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_ENTERING_WORLD" then
    -- The layout builds its frames on this event too: one pass after it.
    PSS:Soon("classpower", function() pcall(CP.Refresh, CP) end, 0.5)
    -- A theme change (colours) or the theme switched off: redraw.
    if not CP.hooked and PSS.Skin and PSS.Skin.Refresh then
      CP.hooked = true
      PSS.HookSecure(PSS.Skin, "Refresh", function() PSS:Soon("classpower", function() pcall(CP.Refresh, CP) end, 0.5) end)
    end
    return
  end
  if event == "UNIT_DISPLAYPOWER" then pcall(CP.UpdateMana, CP) end
  if event ~= "UNIT_DISPLAYPOWER" then pcall(CP.UpdateCombo, CP) end
  if event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
    pcall(CP.UpdateMana, CP)
  end
end)

-- Texts for the option (Settings > interface section).
for lang, t in pairs({
  en = {"Combo points and druid mana", "Combo points under the target frame and a druid's mana bar in bear or cat form (the game's own are hidden with its unit frames)"},
  uk = {"Комбо-поінти й мана друїда", "Комбо-поінти під рамкою цілі та смуга мани друїда у формі ведмедя чи кота (стандартні ховаються разом із рамками гри)"},
  pl = {"Punkty combo i mana druida", "Punkty combo pod ramką celu i pasek many druida w formie niedźwiedzia lub kota (te z gry znikają razem z jej ramkami)"},
  de = {"Combopunkte und Druidenmana", "Combopunkte unter dem Zielrahmen und eine Manaleiste für Druiden in Bär- oder Katzengestalt (die des Spiels verschwinden mit seinen Rahmen)"},
  fr = {"Points de combo et mana du druide", "Points de combo sous le cadre de la cible et barre de mana du druide en forme d'ours ou de félin (ceux du jeu disparaissent avec ses cadres)"},
  it = {"Punti combo e mana del druido", "Punti combo sotto il riquadro del bersaglio e barra del mana del druido in forma d'orso o felina (quelli del gioco spariscono con i suoi riquadri)"},
  es = {"Puntos de combo y maná de druida", "Puntos de combo bajo el marco del objetivo y barra de maná del druida en forma de oso o felina (los del juego se ocultan con sus marcos)"},
  pt = {"Pontos de combo e mana do druida", "Pontos de combo sob o quadro do alvo e barra de mana do druida em forma de urso ou felina (os do jogo somem com os quadros dele)"},
  ru = {"Комбо-очки и мана друида", "Комбо-очки под рамкой цели и полоса маны друида в облике медведя или кошки (стандартные скрыты вместе с рамками игры)"},
}) do
  PSS.Locale = PSS.Locale or {}
  PSS.Locale[lang] = PSS.Locale[lang] or {}
  PSS.Locale[lang].optClassPower, PSS.Locale[lang].optClassPowerHint = t[1], t[2]
end
