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
local OWN2 = {
  en = {sec6 = "Sizes and positions", chatW = "Chat width", chatH = "Chat height", mmSize = "Minimap size",
    scale = "Size: %s", resetPos = "Reset positions", resetAll = "Reset sizes",
    p_player = "player frame", p_target = "target frame", p_targettarget = "target of target", p_pet = "pet frame",
    p_party = "party frames", p_bars = "action bars", p_chat = "chat", p_info = "info bar", p_minimap = "minimap",
    p_buttons = "addon buttons", p_shot = "shot timer", moveHint2 = "Move: the button above or /revui move, then drag the frames; Shift-click on one returns it to its place."},
  uk = {sec6 = "Розміри й розташування", chatW = "Ширина чату", chatH = "Висота чату", mmSize = "Розмір мінімапи",
    scale = "Розмір: %s", resetPos = "Скинути розташування", resetAll = "Скинути розміри",
    p_player = "рамка гравця", p_target = "рамка цілі", p_targettarget = "ціль цілі", p_pet = "рамка пета",
    p_party = "рамки групи", p_bars = "панелі дій", p_chat = "чат", p_info = "інфопанель", p_minimap = "мінімапа",
    p_buttons = "кнопки аддонів", p_shot = "таймер пострілу", moveHint2 = "Переміщення: кнопка вгорі або /revui move, далі тягніть рамки; Shift-клік по рамці повертає її на місце."},
}
for lang, t in pairs(OWN2) do for k, v in pairs(t) do OWN[lang][k] = v end end
for lang, t in pairs(OWN) do
  R.Locale[lang] = R.Locale[lang] or {}
  for k, v in pairs(t) do R.Locale[lang]["rv_" .. k] = v end
end

local function SkinApply()
  if R.Skin then pcall(R.Skin.Refresh, R.Skin) end
  if R.Layout then pcall(R.Layout.Apply, R.Layout) end
end

local function ChatApply()
  local LY = R.Layout
  if LY and LY.applied and LY.applied.chat then pcall(LY.PlaceChat, LY); pcall(LY.FitChatFrame, LY) end
end
local function MinimapApply()
  local LY = R.Layout
  if LY and LY.applied and LY.applied.minimap then pcall(LY.PlaceMinimap, LY); pcall(LY.RefreshMinimapButtons, LY); pcall(LY.SquareMinimapButtons, LY) end
end
local function ScaleValue(key)
  local t = RevUIDB and RevUIDB.layoutScale
  return t and tonumber(t[key]) or 1
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
  {key = "skinMinimap", label = "optSkinMinimap", hint = "optSkinMinimapHint", apply = SkinApply},
  {key = "skinMinimapBar", label = "optMinimapBar", hint = "optMinimapBarHint",
    apply = function() if R.Layout and R.Layout.applied.minimap then pcall(R.Layout.SquareMinimapButtons, R.Layout) end end},
  {sec = "sec6"},
  {key = "chatW", label = "rv_chatW", slider = {300, 900, 10}, default = 440, apply = ChatApply},
  {key = "chatH", label = "rv_chatH", slider = {150, 700, 10}, default = 290, apply = ChatApply},
  {key = "skinMinimapSize", label = "rv_mmSize", slider = {120, 320, 2}, default = 176, apply = MinimapApply},
  {scale = "player"}, {scale = "target"}, {scale = "targettarget"}, {scale = "pet"}, {scale = "party"},
  {scale = "bars"}, {scale = "chat"}, {scale = "info"}, {scale = "buttons"}, {scale = "shot"},
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
    elseif row.slider or row.scale then
      local label = body:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      label:SetPoint("TOPLEFT", 30, y - 5)
      local min, max, step = 50, 200, 5
      if row.slider then min, max, step = row.slider[1], row.slider[2], row.slider[3] end
      local sl = CreateFrame("Slider", nil, body, "OptionsSliderTemplate")
      sl:SetWidth(220); sl:SetPoint("TOPLEFT", 300, y - 4)
      sl:SetMinMaxValues(min, max); sl:SetValueStep(step); sl:SetObeyStepOnDrag(true)
      for _, k in ipairs({"Low", "High", "Text"}) do local r = sl[k]; if r and r.SetText then r:SetText("") end end
      local val = body:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      val:SetPoint("LEFT", sl, "RIGHT", 10, 0)
      local function Get()
        if row.scale then return math.floor(ScaleValue(row.scale) * 100 + 0.5) end
        return tonumber(DB()[row.key]) or row.default
      end
      local busy = false
      local function Show()
        busy = true
        local v = Get(); sl:SetValue(v)
        val:SetText(row.scale and (v .. "%") or tostring(v))
        label:SetText(row.scale and string.format(L("rv_scale"), L("rv_p_" .. row.scale)) or L(row.label))
        busy = false
      end
      sl:SetScript("OnValueChanged", function(_, v)
        if busy then return end
        v = math.floor(v / step + 0.5) * step
        if row.scale then
          RevUIDB.layoutScale = RevUIDB.layoutScale or {}
          RevUIDB.layoutScale[row.scale] = v / 100
          val:SetText(v .. "%")
          if R.Layout and R.Layout.ApplyScale then pcall(R.Layout.ApplyScale, R.Layout, row.scale) end
        else
          RevUIDB[row.key] = v
          val:SetText(tostring(v))
          if row.apply then row.apply() end
        end
      end)
      row.refresh = Show
      y = y - 34
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
  local hint = body:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 4, y - 6); hint:SetPoint("RIGHT", body, "RIGHT", -8, 0)
  hint:SetJustifyH("LEFT"); hint:SetText(L("rv_moveHint2"))
  y = y - 30
  local rp = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
  rp:SetSize(200, 24); rp:SetPoint("TOPLEFT", 4, y)
  rp:SetText(L("rv_resetPos")); rp:SetScript("OnClick", function()
    local LY = R.Layout
    if LY and LY.movables and not InCombatLockdown() then for k in pairs(LY.movables) do pcall(LY.ResetPosition, LY, k) end end
  end)
  local rs = CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
  rs:SetSize(200, 24); rs:SetPoint("LEFT", rp, "RIGHT", 8, 0)
  rs:SetText(L("rv_resetAll")); rs:SetScript("OnClick", function()
    RevUIDB.layoutScale = nil; RevUIDB.chatW = nil; RevUIDB.chatH = nil; RevUIDB.skinMinimapSize = nil
    if R.Layout and R.Layout.ApplyScales then pcall(R.Layout.ApplyScales, R.Layout) end
    ChatApply(); MinimapApply()
    for _, r in ipairs(ROWS) do if r.refresh then r.refresh() end end
  end)
  y = y - 34
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
SLASH_REVUI2 = "/rev"
SlashCmdList.REVUI = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "cpu" or msg == "cpu login" then
    if not R.Profiler then return end
    if msg == "cpu login" then
      RevUIDB.cpuAtLogin = true
      R:Print("CPU check will run for 30 s at the next login: /reload now.")
    else R.Profiler:Start() end
    return
  end
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

-- Minimap button: click opens the settings, drag moves it around the minimap.
local mm = CreateFrame("Button", "RevUIMinimapButton", Minimap)
mm:SetSize(31, 31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
mm:RegisterForDrag("LeftButton")
mm.icon = mm:CreateTexture(nil, "ARTWORK")
mm.icon:SetTexture("Interface/AddOns/RevUI/icon")
mm.icon:SetSize(20, 20)
mm.icon:SetPoint("CENTER", 0, 1)
mm.border = mm:CreateTexture(nil, "OVERLAY")
mm.border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
mm.border:SetSize(53, 53)
mm.border:SetPoint("TOPLEFT")
mm:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
local function MMPlace()
  local a = math.rad((RevUIDB and RevUIDB.minimapAngle) or 200)
  local r = (Minimap:GetWidth() / 2) + 5
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end
mm:SetScript("OnDragStart", function(self)
  self:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    RevUIDB.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
    MMPlace()
  end)
end)
mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
mm:SetScript("OnClick", function() SlashCmdList.REVUI("") end)
mm:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("RevUI " .. tostring(R.version))
  GameTooltip:AddLine(L("rv_help"), 1, 1, 1, true)
  GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
local mmEv = CreateFrame("Frame")
mmEv:RegisterEvent("PLAYER_LOGIN")
mmEv:SetScript("OnEvent", function()
  RevUIDB = RevUIDB or {}
  MMPlace()
  if RevUIDB.minimapButton == false then mm:Hide() end
end)
