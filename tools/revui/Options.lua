-- Copyright (c) 2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- RevUI settings: a page in the game's settings (Options > AddOns > RevUI)
-- and /revui. Most theme parts take effect after a reload (the layout
-- replaces game frames once per session); the page offers one.
local R = RevUI
local function L(k) return R:L(k) end
local function DB() return RevUIDB or {} end

-- RevUI's own strings (the rest come from the shared translations).
local OWN = {
  en = {title = "RevUI", sub = "Flat dark theme for the WoW: Forever interface. Most changes need a reload.",
    themeEmerald = "Emerald", themeLeather = "Leather", themeMoonglade = "Moonglade", reload = "Reload interface",
    move = "Move frames", sec1 = "Theme", sec2 = "Unit frames", sec3 = "Bars, chat and minimap",
    sec4 = "Nameplates", sec5 = "Bags", help = "/revui - settings   /revui move - move frames"},
  uk = {title = "RevUI", sub = "Пласка темна тема для інтерфейсу WoW: Forever. Більшість змін потребує перезавантаження.",
    themeEmerald = "Смарагд", themeLeather = "Шкіра", themeMoonglade = "Місячна галявина", reload = "Перезавантажити інтерфейс",
    move = "Перемістити рамки", sec1 = "Тема", sec2 = "Рамки юнітів", sec3 = "Панелі, чат і мінікарта",
    sec4 = "Неймплейти", sec5 = "Сумки", help = "/revui - налаштування   /revui move - переміщення рамок"},
  pl = {title = "RevUI", sub = "Płaski, ciemny motyw interfejsu WoW: Forever. Większość zmian wymaga przeładowania.",
    themeEmerald = "Szmaragd", themeLeather = "Skóra", themeMoonglade = "Moonglade", reload = "Przeładuj interfejs",
    move = "Przesuń ramki", sec1 = "Motyw", sec2 = "Ramki postaci", sec3 = "Paski, czat i minimapa",
    sec4 = "Paski nad postaciami", sec5 = "Torby", help = "/revui - ustawienia   /revui move - przesuwanie ramek"},
  de = {title = "RevUI", sub = "Flaches, dunkles Design für die WoW: Forever-Oberfläche. Die meisten Änderungen brauchen ein Neuladen.",
    themeEmerald = "Smaragd", themeLeather = "Leder", themeMoonglade = "Mondlichtung", reload = "Oberfläche neu laden",
    move = "Rahmen verschieben", sec1 = "Design", sec2 = "Einheitenrahmen", sec3 = "Leisten, Chat und Minikarte",
    sec4 = "Namensplaketten", sec5 = "Taschen", help = "/revui - Einstellungen   /revui move - Rahmen verschieben"},
  fr = {title = "RevUI", sub = "Thème sombre et plat pour l'interface de WoW: Forever. La plupart des changements demandent un rechargement.",
    themeEmerald = "Émeraude", themeLeather = "Cuir", themeMoonglade = "Reflet-de-Lune", reload = "Recharger l'interface",
    move = "Déplacer les cadres", sec1 = "Thème", sec2 = "Cadres d'unité", sec3 = "Barres, discussion et minicarte",
    sec4 = "Barres d'info", sec5 = "Sacs", help = "/revui - options   /revui move - déplacer les cadres"},
  it = {title = "RevUI", sub = "Tema scuro e piatto per l'interfaccia di WoW: Forever. Quasi tutte le modifiche richiedono di ricaricare l'interfaccia.",
    themeEmerald = "Smeraldo", themeLeather = "Cuoio", themeMoonglade = "Radura di Luna", reload = "Ricarica interfaccia",
    move = "Sposta riquadri", sec1 = "Tema", sec2 = "Riquadri delle unità", sec3 = "Barre, chat e minimappa",
    sec4 = "Targhette", sec5 = "Borse", help = "/revui - impostazioni   /revui move - sposta i riquadri"},
  es = {title = "RevUI", sub = "Tema oscuro y plano para la interfaz de WoW: Forever. La mayoría de los cambios necesitan recargar.",
    themeEmerald = "Esmeralda", themeLeather = "Cuero", themeMoonglade = "Claro de la Luna", reload = "Recargar interfaz",
    move = "Mover marcos", sec1 = "Tema", sec2 = "Marcos de unidad", sec3 = "Barras, chat y minimapa",
    sec4 = "Placas de nombre", sec5 = "Bolsas", help = "/revui - opciones   /revui move - mover marcos"},
  pt = {title = "RevUI", sub = "Tema escuro e plano para a interface do WoW: Forever. A maioria das mudanças precisa recarregar.",
    themeEmerald = "Esmeralda", themeLeather = "Couro", themeMoonglade = "Clareira da Lua", reload = "Recarregar interface",
    move = "Mover quadros", sec1 = "Tema", sec2 = "Quadros de unidade", sec3 = "Barras, bate-papo e minimapa",
    sec4 = "Placas de nome", sec5 = "Bolsas", help = "/revui - opções   /revui move - mover quadros"},
  ru = {title = "RevUI", sub = "Плоская тёмная тема для интерфейса WoW: Forever. Большинство изменений требует перезагрузки.",
    themeEmerald = "Изумруд", themeLeather = "Кожа", themeMoonglade = "Лунная поляна", reload = "Перезагрузить интерфейс",
    move = "Переместить рамки", sec1 = "Тема", sec2 = "Рамки юнитов", sec3 = "Панели, чат и миникарта",
    sec4 = "Индикаторы", sec5 = "Сумки", help = "/revui - настройки   /revui move - перемещение рамок"},
}
for lang, t in pairs(OWN) do
  R.Locale[lang] = R.Locale[lang] or {}
  for k, v in pairs(t) do R.Locale[lang]["rv_" .. k] = v end
end

local function SkinApply()
  if R.Skin then pcall(R.Skin.Refresh, R.Skin) end
  if R.Layout then pcall(R.Layout.Apply, R.Layout) end
end

local ROWS = {
  {sec = "sec1"},
  {key = "skinGame", label = "optSkinGame", hint = "optSkinGameHint", apply = SkinApply},
  {key = "theme", label = "optTheme", choice = {{"emerald", "rv_themeEmerald"}, {"leather", "rv_themeLeather"},
    {"moonglade", "rv_themeMoonglade"}}, apply = SkinApply},
  {key = "skinFonts", label = "optSkinFonts", hint = "optSkinFontsHint", apply = SkinApply},
  {sec = "sec2"},
  {key = "skinUnits", label = "optSkinUnits", hint = "optSkinUnitsHint", apply = SkinApply},
  {key = "skinParty", label = "optSkinParty", hint = "optSkinPartyHint", apply = SkinApply},
  {key = "classPower", label = "optClassPower", hint = "optClassPowerHint",
    apply = function() if R.ClassPower then pcall(R.ClassPower.Refresh, R.ClassPower) end end},
  {sec = "sec3"},
  {key = "skinBars", label = "optSkinBars", hint = "optSkinBarsHint", apply = SkinApply},
  {key = "cdmAbove", label = "optCdmAbove", hint = "optCdmAboveHint",
    apply = function() if R.Layout and R.Layout.PlaceCooldowns then pcall(R.Layout.PlaceCooldowns) end end},
  {key = "skinChat", label = "optSkinChat", hint = "optSkinChatHint", apply = SkinApply},
  {key = "skinChatSize", label = "optChatSize", choice = {{"s", "sizeS"}, {"m", "sizeM"}, {"l", "sizeL"}, {"xl", "sizeXL"}},
    default = "m", apply = function() if R.Layout and R.Layout.applied.chat then pcall(R.Layout.PlaceChat, R.Layout) end end},
  {key = "skinMinimap", label = "optSkinMinimap", hint = "optSkinMinimapHint", apply = SkinApply},
  {key = "skinMinimapBar", label = "optMinimapBar", hint = "optMinimapBarHint",
    apply = function() if R.Layout and R.Layout.applied.minimap then pcall(R.Layout.SquareMinimapButtons, R.Layout) end end},
  {key = "skinMinimapSize", label = "optMinimapSize", choice = {{150, "sizeS"}, {176, "sizeM"}, {210, "sizeL"}, {250, "sizeXL"}},
    default = 176, apply = function()
      local LY = R.Layout
      if LY and LY.applied.minimap then pcall(LY.PlaceMinimap, LY); pcall(LY.RefreshMinimapButtons, LY); pcall(LY.SquareMinimapButtons, LY) end
    end},
  {sec = "sec4"},
  {key = "skinPlates", label = "optSkinPlates", hint = "optSkinPlatesHint", apply = SkinApply},
  {key = "plateExtras", label = "optPlateExtras", hint = "optPlateExtrasHint"},
  {key = "plateStack", label = "optPlateStack", hint = "optPlateStackHint", default = false,
    apply = function() if R.ApplyPlateStacking then pcall(R.ApplyPlateStacking, R) end end},
  {sec = "sec5"},
  {key = "skinBags", label = "optSkinBags", hint = "optSkinBagsHint", apply = SkinApply},
  {key = "bagsUI", label = "optBagsUI", hint = "optBagsUIHint", default = true,
    apply = function() if R.Bags then pcall(R.Bags.Refresh, R.Bags) end end},
  {key = "ownBags", label = "optOwnBags", hint = "optOwnBagsHint", default = false,
    apply = function() if R.Inventory and not R.Inventory:Enabled() then pcall(R.Inventory.Close, R.Inventory) end end},
}

local function Value(row)
  local v = DB()[row.key]
  if v == nil then
    if row.default ~= nil then return row.default end
    if row.choice then return row.choice[1][1] end
    return true
  end
  return v
end

local panel = CreateFrame("Frame")
panel:Hide()
local built = false
local function Build()
  if built then return end
  built = true
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(L("rv_title") .. "  |cff999999" .. tostring(R.version) .. "|r")
  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6); sub:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  sub:SetJustifyH("LEFT"); sub:SetText(L("rv_sub") .. "\n" .. L("rv_help"))
  local reload = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reload:SetSize(190, 24); reload:SetPoint("TOPRIGHT", -16, -14)
  reload:SetText(L("rv_reload")); reload:SetScript("OnClick", function() ReloadUI() end)
  local move = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  move:SetSize(150, 24); move:SetPoint("RIGHT", reload, "LEFT", -8, 0)
  move:SetText(L("rv_move")); move:SetScript("OnClick", function()
    if R.Layout and R.Layout.Unlock then pcall(R.Layout.Unlock, R.Layout, true) end
  end)
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -12)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 12)
  local body = CreateFrame("Frame", nil, scroll)
  body:SetSize(600, 10)
  scroll:SetScrollChild(body)
  scroll:SetScript("OnSizeChanged", function(_, w) body:SetWidth(w) end)
  local y = 0
  for _, row in ipairs(ROWS) do
    if row.sec then
      y = y - 8
      local h = body:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      h:SetPoint("TOPLEFT", 4, y); h:SetText(L("rv_" .. row.sec))
      local line = body:CreateTexture(nil, "ARTWORK")
      line:SetColorTexture(0.85, 0.7, 0.43, 0.5); line:SetHeight(1)
      line:SetPoint("TOPLEFT", 4, y - 18); line:SetPoint("TOPRIGHT", -4, y - 18)
      y = y - 26
    elseif row.choice then
      local label = body:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      label:SetPoint("TOPLEFT", 30, y - 5); label:SetText(L(row.label))
      local b = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
      b:SetSize(180, 22); b:SetPoint("TOPLEFT", 300, y - 1)
      local function Show()
        local v = Value(row)
        for _, o in ipairs(row.choice) do if o[1] == v then b:SetText(L(o[2])) end end
      end
      b:SetScript("OnClick", function()
        local v, idx = Value(row), 1
        for i, o in ipairs(row.choice) do if o[1] == v then idx = i end end
        RevUIDB[row.key] = row.choice[idx % #row.choice + 1][1]
        Show()
        if row.apply then row.apply() end
      end)
      row.refresh = Show
      y = y - 28
    else
      local cb = CreateFrame("CheckButton", nil, body, "UICheckButtonTemplate")
      cb:SetSize(26, 26); cb:SetPoint("TOPLEFT", 4, y)
      local label = body:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      label:SetPoint("LEFT", cb, "RIGHT", 4, 1); label:SetText(L(row.label))
      local hint = body:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
      hint:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2); hint:SetPoint("RIGHT", body, "RIGHT", -8, 0)
      hint:SetJustifyH("LEFT"); hint:SetText(row.hint and L(row.hint) or "")
      cb:SetScript("OnClick", function(self)
        RevUIDB[row.key] = self:GetChecked() and true or false
        if row.apply then row.apply() end
      end)
      row.refresh = function() cb:SetChecked(Value(row) and true or false) end
      y = y - (row.hint and 44 or 30)
    end
  end
  body:SetHeight(-y + 10)
end
panel:SetScript("OnShow", function()
  Build()
  for _, row in ipairs(ROWS) do if row.refresh then row.refresh() end end
end)

local category
if Settings and Settings.RegisterCanvasLayoutCategory then
  category = Settings.RegisterCanvasLayoutCategory(panel, "RevUI")
  Settings.RegisterAddOnCategory(category)
end

SLASH_REVUI1 = "/revui"
SlashCmdList.REVUI = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "move" then
    if R.Layout and R.Layout.Unlock then pcall(R.Layout.Unlock, R.Layout, true) end
    return
  end
  if category and Settings.OpenToCategory then
    Settings.OpenToCategory(category:GetID())
  else
    R:Print(L("rv_help"))
  end
end
BINDING_HEADER_REVUI = "RevUI"
