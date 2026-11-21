-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Bags with the theme (keyboard and mouse; the gamepad keeps the game's own
-- bag navigation). Built on the game's own frames - Forever's bags are the
-- modern ones (Blizzard_UIPanels_Game/Mainline/ContainerFrame.xml / .lua):
-- ContainerFrameCombinedBags or ContainerFrame1..13, BagItemSearchBox,
-- BagItemAutoSortButton (C_Container.SortBags), the PortraitButton menu
-- (DropdownButton) and the MoneyFrame. Nothing of them is replaced:
--  * a top bar: wide search, Clean Up, sort direction, the bag menu;
--  * a strip under the bags: every bag with fill, the bag filters of the
--    chosen bag, ammo left and the price of your junk;
--  * on the items: quality edge, junk dimmed, a paw on food your pet eats;
--  * hovering a bag lights its slots, a click shows only that bag.
-- Item buttons are never moved; only drawn over (alpha, textures).
local PSS = PetSkillScout
PSS.Bags = {}
local B = PSS.Bags

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
local function G(n) return _G[n] end
local function Plain(v) if PSS.IsSecret and PSS.IsSecret(v) then return nil end return v end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function DB() return PetSkillScoutDB or {} end

local TEXT = {
  en = {sort = "Clean Up", dir = "Sort direction", dirL = "Sort: right to left", dirR = "Sort: left to right",
    menu = "Bag settings", search = "Search...", ammo = "Ammo: %d", junk = "Junk: %s", only = "Click: only this bag. Again: all bags.",
    filters = "\"Clean Up\" puts into %s:", filterTip = "Lit: Clean Up moves this kind of item into the chosen bag. Click to switch.", ignore = "Ignore on Clean Up", backpack = "Backpack", food = "Your pet eats this"},
  uk = {sort = "Прибрати", dir = "Напрямок сортування", dirL = "Сортування: справа наліво", dirR = "Сортування: зліва направо",
    menu = "Налаштування сумки", search = "Пошук...", ammo = "Набої: %d", junk = "Мотлох: %s", only = "Клік: лише ця сумка. Ще раз: усі.",
    filters = "Кнопка «Прибрати» кладе в «%s»:", filterTip = "Світиться: «Прибрати» складає такі предмети у вибрану сумку. Клік — увімкнути чи вимкнути.", ignore = "Не чіпати при прибиранні", backpack = "Рюкзак", food = "Ваш пет це їсть"},
  pl = {sort = "Uporządkuj", dir = "Kierunek sortowania", dirL = "Sortuj: od prawej", dirR = "Sortuj: od lewej",
    menu = "Ustawienia torby", search = "Szukaj...", ammo = "Amunicja: %d", junk = "Śmieci: %s", only = "Klik: tylko ta torba. Ponownie: wszystkie.",
    filters = "„Uporządkuj” wkłada do: %s", filterTip = "Podświetlone: Uporządkuj przenosi takie przedmioty do wybranej torby. Klik przełącza.", ignore = "Pomijaj przy porządkowaniu", backpack = "Plecak", food = "Twój zwierzak to je"},
  de = {sort = "Aufräumen", dir = "Sortierrichtung", dirL = "Sortieren: von rechts", dirR = "Sortieren: von links",
    menu = "Taschen-Einstellungen", search = "Suchen...", ammo = "Munition: %d", junk = "Plunder: %s", only = "Klick: nur diese Tasche. Erneut: alle.",
    filters = "„Aufräumen“ legt in %s:", filterTip = "Leuchtet: Aufräumen legt solche Gegenstände in die gewählte Tasche. Klick schaltet um.", ignore = "Beim Aufräumen ignorieren", backpack = "Rucksack", food = "Dein Tier frisst das"},
  fr = {sort = "Ranger", dir = "Sens du tri", dirL = "Tri : de droite à gauche", dirR = "Tri : de gauche à droite",
    menu = "Options du sac", search = "Rechercher...", ammo = "Munitions : %d", junk = "Camelote : %s", only = "Clic : ce sac seul. Encore : tous.",
    filters = "« Ranger » met dans %s :", filterTip = "Allumé : Ranger place ce type d'objet dans le sac choisi. Clic pour changer.", ignore = "Ignorer au rangement", backpack = "Sac à dos", food = "Votre familier mange ceci"},
  it = {sort = "Riordina", dir = "Direzione ordinamento", dirL = "Ordina: da destra", dirR = "Ordina: da sinistra",
    menu = "Impostazioni borsa", search = "Cerca...", ammo = "Munizioni: %d", junk = "Cianfrusaglie: %s", only = "Clic: solo questa borsa. Ancora: tutte.",
    filters = "\"Riordina\" mette in %s:", filterTip = "Acceso: Riordina sposta questo tipo di oggetti nella borsa scelta. Clic per cambiare.", ignore = "Ignora nel riordino", backpack = "Zaino", food = "Il tuo famiglio lo mangia"},
  es = {sort = "Ordenar", dir = "Dirección de orden", dirL = "Ordenar: de derecha a izquierda", dirR = "Ordenar: de izquierda a derecha",
    menu = "Ajustes de bolsa", search = "Buscar...", ammo = "Munición: %d", junk = "Basura: %s", only = "Clic: solo esta bolsa. Otra vez: todas.",
    filters = "\"Ordenar\" guarda en %s:", filterTip = "Encendido: Ordenar mueve este tipo de objeto a la bolsa elegida. Clic para cambiar.", ignore = "Ignorar al ordenar", backpack = "Mochila", food = "Tu mascota come esto"},
  pt = {sort = "Organizar", dir = "Direção da organização", dirL = "Organizar: da direita", dirR = "Organizar: da esquerda",
    menu = "Opções da bolsa", search = "Buscar...", ammo = "Munição: %d", junk = "Lixo: %s", only = "Clique: só esta bolsa. De novo: todas.",
    filters = "\"Organizar\" guarda em %s:", filterTip = "Aceso: Organizar move este tipo de item para a bolsa escolhida. Clique para alternar.", ignore = "Ignorar ao organizar", backpack = "Mochila", food = "Seu ajudante come isto"},
  ru = {sort = "Разобрать", dir = "Направление сортировки", dirL = "Сортировка: справа налево", dirR = "Сортировка: слева направо",
    menu = "Настройки сумки", search = "Поиск...", ammo = "Боеприпасы: %d", junk = "Хлам: %s", only = "Клик: только эта сумка. Ещё раз: все.",
    filters = "Кнопка «Разобрать» кладёт в «%s»:", filterTip = "Горит: «Разобрать» складывает такие предметы в выбранную сумку. Клик — включить или выключить.", ignore = "Не трогать при сортировке", backpack = "Рюкзак", food = "Ваш питомец это ест"},
}
local function T(k)
  local l = TEXT[DB().language or "en"] or TEXT.en
  return l[k] or TEXT.en[k]
end

local function Col(k, def)
  local c = PSS.Skin and PSS.Skin.Colour and PSS.Skin:Colour(k)
  return c or def
end
local function On()
  if DB().bagsUI ~= true then return false end -- off unless switched on
  if PSS.RevUILoaded and PSS:RevUILoaded() then return false end
  -- Our own inventory window replaces the game's bags: nothing to dress up.
  if PSS.Inventory and PSS.Inventory.Enabled and PSS.Inventory:Enabled() then return false end
  if not (PSS.Skin and PSS.Skin.active) then return false end
  return true
end
-- Gamepad: the game's own bag navigation (A / X / Y / B) stays; we only draw
-- the item marks and the bag strip (no top bar, the search is left alone).
local function Pad() return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() end

-- Small helpers ----------------------------------------------------------------
local function Edges(parent, layer, w)
  local e = {}
  for i = 1, 4 do e[i] = parent:CreateTexture(nil, layer or "OVERLAY", nil, 6); e[i]:SetTexture(FLAT) end
  e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(w or 1)
  e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(w or 1)
  e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(w or 1)
  e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(w or 1)
  return e
end
local function EdgeColor(e, c, a)
  for i = 1, 4 do e[i]:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1) end
end
local function Panel(f, bgKey)
  local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetTexture(FLAT)
  local c = Col(bgKey or "panel", {0.05, 0.08, 0.07, 0.9})
  bg:SetVertexColor(c[1], c[2], c[3], c[4] or 0.9)
  f.pssEdge = Edges(f, "BORDER")
  EdgeColor(f.pssEdge, Col("edge", {0.4, 0.4, 0.3, 1}))
  return bg
end
local function Text(parent, size, c)
  local s = parent:CreateFontString(nil, "OVERLAY"); s:SetFont(FONT, size, "")
  c = c or {0.95, 0.89, 0.78}
  s:SetTextColor(c[1], c[2], c[3])
  return s
end
local function Btn(parent, w, label, tip, fn)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, 22)
  Panel(b, "button")
  b.text = Text(b, 11); b.text:SetPoint("CENTER"); b.text:SetText(label or "")
  b:SetScript("OnEnter", function(self)
    EdgeColor(self.pssEdge, Col("accent", {0.85, 0.7, 0.43, 1}))
    if self.tip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(type(self.tip) == "function" and self.tip() or self.tip)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self)
    EdgeColor(self.pssEdge, Col("edge", {0.4, 0.4, 0.3, 1}))
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  end)
  b.tip = tip
  b:SetScript("OnClick", fn)
  return b
end
local function Money(copper)
  if GetCoinTextureString then return GetCoinTextureString(copper) end
  return tostring(math.floor(copper / 10000)) .. "g"
end

-- Bags of the player -----------------------------------------------------------
local BAGS = {0, 1, 2, 3, 4}
local function NumSlots(bag) return Plain(Call(C_Container and C_Container.GetContainerNumSlots, bag)) or 0 end
local function Free(bag) return Plain(Call(C_Container and C_Container.GetContainerNumFreeSlots, bag)) or 0 end
local function BagIcon(bag)
  if bag == 0 then return "Interface\\Buttons\\Button-Backpack-Up" end
  local inv = C_Container and C_Container.ContainerIDToInventoryID and Call(C_Container.ContainerIDToInventoryID, bag)
  return inv and Plain(Call(GetInventoryItemTexture, "player", inv)) or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
end
local function BagName(bag)
  if bag == 0 then return T("backpack") end
  return Plain(Call(C_Container and C_Container.GetBagName, bag)) or ("Bag " .. bag)
end

-- The container frames on screen, and their item buttons.
local function Containers()
  local out = {}
  local cb = G("ContainerFrameCombinedBags")
  if cb and cb:IsShown() then out[#out + 1] = cb end
  for i = 1, 13 do
    local f = G("ContainerFrame" .. i)
    if f and f:IsShown() then out[#out + 1] = f end
  end
  return out
end
local function Buttons(frame)
  local list = {}
  if type(frame.EnumerateValidItems) == "function" then
    pcall(function() for _, b in frame:EnumerateValidItems() do list[#list + 1] = b end end)
  end
  return list
end
local function BagOf(btn)
  local bag = btn.GetBagID and Call(btn.GetBagID, btn)
  return Plain(bag), btn.GetID and btn:GetID()
end
-- The frame that holds the search box: the combined bag, else the backpack.
local function Main()
  local cb = G("ContainerFrameCombinedBags")
  if cb and cb:IsShown() then return cb end
  local f1 = G("ContainerFrame1")
  if f1 and f1:IsShown() then return f1 end
end

-- Item overlays ------------------------------------------------------------------
local over = {}
local function Overlay(btn)
  local o = over[btn]
  if o then return o end
  o = {}
  o.edge = Edges(btn, "OVERLAY", 1)
  o.paw = btn:CreateTexture(nil, "OVERLAY", nil, 7)
  o.paw:SetSize(12, 12); o.paw:SetPoint("TOPRIGHT", -1, -1)
  o.paw:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTraining")
  o.paw:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  o.paw:Hide()
  over[btn] = o
  return o
end
local diet
local function PaintItem(btn, focus)
  local o = Overlay(btn)
  local bag, slot = BagOf(btn)
  local info = bag and slot and Call(C_Container and C_Container.GetContainerItemInfo, bag, slot)
  local q = type(info) == "table" and Plain(info.quality)
  local id = type(info) == "table" and Plain(info.itemID)
  -- Quality edge (common and poor get none).
  if q and q >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
    local c = ITEM_QUALITY_COLORS[q]
    EdgeColor(o.edge, {c.r, c.g, c.b}, 0.9)
    for i = 1, 4 do o.edge[i]:Show() end
  else
    for i = 1, 4 do o.edge[i]:Hide() end
  end
  -- Junk dimmed.
  local icon = btn.icon or btn.Icon or rawget(btn, "IconTexture")
  if icon and icon.SetVertexColor then
    if q == 0 then icon:SetVertexColor(0.55, 0.55, 0.55) elseif icon.pssDim then icon:SetVertexColor(1, 1, 1) end
    icon.pssDim = q == 0
  end
  -- Food your pet eats.
  local food = id and PSS.Foods and PSS.Foods[id]
  o.paw:SetShown(food and diet and diet[food[1]] and true or false)
  -- One bag shown: the others are faded.
  btn:SetAlpha((focus == nil or focus == bag) and 1 or 0.18)
  -- Lit while its bag in the strip is hovered.
  if B.hoverBag ~= nil and bag == B.hoverBag then
    EdgeColor(o.edge, Col("accent", {0.85, 0.7, 0.43, 1}), 1)
    for i = 1, 4 do o.edge[i]:Show() end
  end
end
local function ClearItem(btn)
  local o = over[btn]
  if not o then return end
  for i = 1, 4 do o.edge[i]:Hide() end
  o.paw:Hide()
  local icon = btn.icon or btn.Icon
  if icon and icon.pssDim then icon:SetVertexColor(1, 1, 1); icon.pssDim = nil end
  btn:SetAlpha(1)
end

-- Top bar ------------------------------------------------------------------------
local top
local function Top()
  if top then return top end
  top = CreateFrame("Frame", "PetSkillScoutBagTop", UIParent)
  top:SetHeight(26)
  top:EnableMouse(true)
  -- A click on the bar's empty part puts the cursor in the search box.
  top:SetScript("OnMouseDown", function() local s = G("BagItemSearchBox"); if s then s:SetFocus() end end)
  top.line = top:CreateTexture(nil, "ARTWORK"); top.line:SetTexture(FLAT); top.line:SetHeight(1)
  top.line:SetPoint("BOTTOMLEFT", 0, -3); top.line:SetPoint("BOTTOMRIGHT", 0, -3)
  top.menu = Btn(top, 24, "...", function() return T("menu") end, function()
    local f = Main()
    local pb = f and (f.PortraitButton or G((f:GetName() or "") .. "PortraitButton"))
    if pb and pb.OpenMenu then pcall(pb.OpenMenu, pb) elseif pb and pb.Click then pcall(pb.Click, pb) end
  end)
  top.menu:SetPoint("RIGHT", 0, 0)
  top.dir = Btn(top, 24, "<>", function()
    local rtl = Plain(Call(C_Container and C_Container.GetSortBagsRightToLeft))
    return T(rtl and "dirL" or "dirR")
  end, function(self)
    local rtl = Plain(Call(C_Container and C_Container.GetSortBagsRightToLeft))
    Call(C_Container and C_Container.SetSortBagsRightToLeft, not rtl)
    B:Refresh()
    if self:IsMouseOver() then self:GetScript("OnEnter")(self) end
  end)
  top.dir:SetPoint("RIGHT", top.menu, "LEFT", -4, 0)
  top.sort = Btn(top, 86, T("sort"), nil, function()
    if PlaySound and SOUNDKIT and SOUNDKIT.UI_BAG_SORTING_01 then PlaySound(SOUNDKIT.UI_BAG_SORTING_01) end
    Call(C_Container and C_Container.SortBags)
  end)
  top.sort:SetPoint("RIGHT", top.dir, "LEFT", -4, 0)
  return top
end

-- Strip under the bags -----------------------------------------------------------
local strip
local FILTERS = {
  {"ClassEquipment", "bags-icon-equipment"}, {"ClassConsumables", "bags-icon-consumables"},
  {"ClassProfessionGoods", "bags-icon-profession-goods"}, {"ClassReagents", "bags-icon-reagents"},
  {"ClassJunk", "bags-icon-junk"}, {"ClassQuestItems", "bags-icon-quest"},
}
local FILTER_NAME = {ClassEquipment = "BAG_FILTER_EQUIPMENT", ClassConsumables = "BAG_FILTER_CONSUMABLES",
  ClassProfessionGoods = "BAG_FILTER_PROFESSION_GOODS", ClassReagents = "BAG_FILTER_REAGENTS",
  ClassJunk = "BAG_FILTER_JUNK", ClassQuestItems = "BAG_FILTER_QUEST_ITEMS"}
local function Flag(name) return Enum and Enum.BagSlotFlags and Enum.BagSlotFlags[name] end
local function GetFlag(bag, name)
  local f = Flag(name)
  return f and Plain(Call(C_Container and C_Container.GetBagSlotFlag, bag, f)) and true or false
end
local function SetFlag(bag, name, v)
  local f = Flag(name)
  if f then Call(C_Container and C_Container.SetBagSlotFlag, bag, f, v) end
end
local function Strip()
  if strip then return strip end
  strip = CreateFrame("Frame", "PetSkillScoutBagStrip", UIParent)
  strip:SetHeight(140)
  strip:SetFrameStrata("HIGH")
  Panel(strip)
  strip.bags = {}
  for i, bag in ipairs(BAGS) do
    local b = CreateFrame("Button", nil, strip)
    b:SetSize(30, 30)
    b:SetPoint("TOPLEFT", 8 + (i - 1) * 64, -6)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.edge = Edges(b, "OVERLAY", 1)
    b.count = Text(b, 10); b.count:SetPoint("LEFT", b, "RIGHT", 4, 6)
    b.barBg = b:CreateTexture(nil, "ARTWORK"); b.barBg:SetTexture(FLAT)
    b.barBg:SetSize(26, 3); b.barBg:SetPoint("TOPLEFT", b, "BOTTOMRIGHT", 4, 12)
    b.barBg:SetVertexColor(0, 0, 0, 0.6)
    b.bar = b:CreateTexture(nil, "OVERLAY"); b.bar:SetTexture(FLAT); b.bar:SetHeight(3)
    b.bar:SetPoint("LEFT", b.barBg, "LEFT")
    b.bag = bag
    b:SetScript("OnEnter", function(self)
      B.hoverBag = self.bag; B:Paint()
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(BagName(self.bag))
      GameTooltip:AddLine(string.format("%d / %d", NumSlots(self.bag) - Free(self.bag), NumSlots(self.bag)), 1, 1, 1)
      GameTooltip:AddLine(T("only"), 0.7, 0.7, 0.7, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
      B.hoverBag = nil; B:Paint()
      if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    b:SetScript("OnClick", function(self, btn)
      if btn == "RightButton" then
        B.selBag = self.bag
      else
        DB().bagFocus = DB().bagFocus ~= self.bag and self.bag or nil
        B.selBag = self.bag
      end
      B:Refresh()
    end)
    strip.bags[i] = b
  end
  -- Filters of the chosen bag (not the backpack: the game has none for it).
  strip.fLabel = Text(strip, 10, Col("muted", {0.66, 0.74, 0.67}))
  strip.fLabel:SetPoint("TOPLEFT", 8, -50); strip.fLabel:SetText(T("filters"))
  strip.filters = {}
  for i, f in ipairs(FILTERS) do
    -- A named switch (the game's own filter names): lit when Clean Up puts
    -- that kind of item into the chosen bag.
    local b = CreateFrame("Button", nil, strip)
    b:SetHeight(20)
    b.bg = Panel(b, "button")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(14, 14); b.icon:SetPoint("LEFT", 4, 0)
    pcall(b.icon.SetAtlas, b.icon, f[2])
    b.text = Text(b, 10); b.text:SetPoint("LEFT", b.icon, "RIGHT", 3, 0)
    b.text:SetText(_G[FILTER_NAME[f[1]]] or f[1])
    -- Two rows of three, sized to the strip in Refresh (they ran past the
    -- window's edge in one row).
    b.text:SetPoint("RIGHT", b, "RIGHT", -3, 0); b.text:SetJustifyH("LEFT"); b.text:SetWordWrap(false)
    b.edge = b.pssEdge
    b.flag = f[1]
    b:SetScript("OnClick", function(self)
      local bag = B.selBag
      if not bag or bag == 0 then return end
      -- The same as the game's own bag menu (ContainerFrame.lua,
      -- ContainerFrame_AddButtons_BagFilters): toggles one flag and tells the
      -- bag settings manager. The new state is shown at once and confirmed in
      -- chat; the game's answer comes a moment later.
      local value = not GetFlag(bag, self.flag)
      SetFlag(bag, self.flag, value)
      local M = _G.ContainerFrameSettingsManager
      local f = Flag(self.flag)
      if M and M.SetFilterFlag and f then pcall(M.SetFilterFlag, M, bag, f, value) end
      B.pendingFlag = {bag = bag, flag = self.flag, value = value}
      PSS:Print(string.format("%s: %s %s", BagName(bag), _G[FILTER_NAME[self.flag]] or self.flag,
        value and "|cff7ee0a3✓|r" or "|cffff7a7a✗|r"))
      B:Refresh()
      if C_Timer then C_Timer.After(0.5, function() B.pendingFlag = nil; B:Refresh() end) end
    end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(_G[FILTER_NAME[self.flag]] or self.flag)
      GameTooltip:AddLine(T("filterTip"), 1, 1, 1, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    strip.filters[i] = b
  end
  strip.ignore = CreateFrame("Button", nil, strip)
  strip.ignore:SetSize(14, 14)
  strip.ignore:SetPoint("LEFT", strip.filters[#strip.filters], "RIGHT", 12, 0)
  Panel(strip.ignore, "input")
  strip.ignore.mark = strip.ignore:CreateTexture(nil, "OVERLAY"); strip.ignore.mark:SetTexture(FLAT)
  strip.ignore.mark:SetPoint("TOPLEFT", 3, -3); strip.ignore.mark:SetPoint("BOTTOMRIGHT", -3, 3)
  strip.ignore.text = Text(strip, 10); strip.ignore.text:SetPoint("LEFT", strip.ignore, "RIGHT", 4, 0)
  strip.ignore.text:SetText(T("ignore"))
  strip.ignore:SetScript("OnClick", function()
    local bag = B.selBag or 0
    if bag == 0 then
      local d = Plain(Call(C_Container and C_Container.GetBackpackAutosortDisabled))
      Call(C_Container and C_Container.SetBackpackAutosortDisabled, not d)
    else
      SetFlag(bag, "DisableAutoSort", not GetFlag(bag, "DisableAutoSort"))
    end
    B:Refresh()
  end)
  -- Clean Up on the strip too: the game hides its own sort button in the
  -- gamepad interface (ContainerFrameMixin:UpdateSearchBox).
  strip.sort = Btn(strip, 86, T("sort"), nil, function()
    if PlaySound and SOUNDKIT and SOUNDKIT.UI_BAG_SORTING_01 then PlaySound(SOUNDKIT.UI_BAG_SORTING_01) end
    Call(C_Container and C_Container.SortBags)
  end)
  strip.ammo = Text(strip, 11)
  strip.ammo:SetPoint("BOTTOMLEFT", 8, 7)
  strip.junk = Text(strip, 11, Col("muted", {0.66, 0.74, 0.67}))
  strip.junk:SetPoint("LEFT", strip.ammo, "RIGHT", 16, 0)
  strip.div = strip:CreateTexture(nil, "ARTWORK"); strip.div:SetTexture(FLAT); strip.div:SetHeight(1)
  strip.div:SetPoint("TOPLEFT", 8, -42); strip.div:SetPoint("TOPRIGHT", -8, -42)
  strip.div2 = strip:CreateTexture(nil, "ARTWORK"); strip.div2:SetTexture(FLAT); strip.div2:SetHeight(1)
  strip.div2:SetPoint("BOTTOMLEFT", 8, 26); strip.div2:SetPoint("BOTTOMRIGHT", -8, 26)
  return strip
end

-- Paint --------------------------------------------------------------------------
function B:Paint()
  local focus = On() and DB().bagFocus or nil
  for _, f in ipairs(Containers()) do
    for _, btn in ipairs(Buttons(f)) do
      if On() then pcall(PaintItem, btn, focus) else pcall(ClearItem, btn) end
    end
  end
end

function B:Refresh()
  local main = Main()
  local on = On() and main ~= nil
  local t, s = Top(), Strip()
  if not on then
    t:Hide(); s:Hide(); B:PadPanel(false)
    self:Paint()
    return
  end
  diet = nil
  if PSS.PetCare and PSS.PetCare.Diet then
    local ok, d = pcall(PSS.PetCare.Diet, PSS.PetCare)
    if ok then diet = d end
  end
  local acc = Col("accent", {0.85, 0.7, 0.43, 1})
  if Pad() then
    t:Hide()
  else
  -- Top bar over the search line of the main bag frame.
  t:SetParent(main); t:SetFrameLevel(main:GetFrameLevel() + 10)
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", main, "TOPLEFT", 10, -30)
  t:SetPoint("TOPRIGHT", main, "TOPRIGHT", -10, -30)
  t.line:SetVertexColor(acc[1], acc[2], acc[3], 0.6)
  t.sort.text:SetText(T("sort"))
  t:Show()
  local sb = G("BagItemSearchBox")
  if sb and not InCombat() then
    sb:ClearAllPoints()
    sb:SetPoint("LEFT", t, "LEFT", 6, 0)
    sb:SetPoint("RIGHT", t.sort, "LEFT", -8, 0)
    if sb.Instructions then sb.Instructions:SetText(T("search")) end
  end
  local auto = G("BagItemAutoSortButton")
  if auto and not InCombat() then auto:SetAlpha(0); auto:EnableMouse(false) end
  local pb = main.PortraitButton
  if pb then pb:SetAlpha(0) end
  end
  -- Strip under the main frame (or under the lowest open bag).
  -- Its own window (not a child of the bag window: changing that window's
  -- gamepad buttons tainted it). Follows the bags by anchor.
  s:SetParent(UIParent); s:SetFrameStrata(main:GetFrameStrata() or "MEDIUM"); s:SetFrameLevel(main:GetFrameLevel() + 10)
  s:ClearAllPoints()
  -- Above the bag window: below it sat the gamepad hints and the info bar.
  s:SetPoint("BOTTOMLEFT", main, "TOPLEFT", 0, 4)
  s:SetPoint("BOTTOMRIGHT", main, "TOPRIGHT", 0, 4)
  s.div:SetVertexColor(acc[1], acc[2], acc[3], 0.25)
  s.div2:SetVertexColor(acc[1], acc[2], acc[3], 0.15)
  local width = main:GetWidth() or 300
  local per = math.max(40, math.floor((width - 16) / #BAGS))
  local focus = DB().bagFocus
  if self.selBag == nil then self.selBag = focus or 1 end
  for i, b in ipairs(s.bags) do
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8 + (i - 1) * per, -6)
    local n = NumSlots(b.bag)
    b:SetShown(n > 0)
    if n > 0 then
      local used = n - Free(b.bag)
      b.icon:SetTexture(BagIcon(b.bag))
      b.count:SetText(used .. "/" .. n)
      local fill = used / n
      b.bar:SetWidth(math.max(1, 26 * fill))
      if fill >= 1 then b.bar:SetVertexColor(1, 0.35, 0.35) elseif fill >= 0.8 then b.bar:SetVertexColor(1, 0.8, 0.3)
      else b.bar:SetVertexColor(0.45, 0.85, 0.5) end
      local sel = b.bag == self.selBag
      EdgeColor(b.edge, sel and acc or Col("edge", {0.4, 0.4, 0.3, 1}), 1)
      b.icon:SetAlpha((focus == nil or focus == b.bag) and 1 or 0.45)
    end
  end
  local bag = self.selBag
  local fw = math.floor(((s:GetWidth() or width) - 16 - 8) / 3)
  for i, fb in ipairs(s.filters) do
    fb:ClearAllPoints()
    fb:SetWidth(fw)
    fb:SetPoint("TOPLEFT", s, "TOPLEFT", 8 + ((i - 1) % 3) * (fw + 4), -66 - math.floor((i - 1) / 3) * 24)
  end
  for _, fb in ipairs(s.filters) do
    local can = bag and bag > 0
    fb:SetShown(can and true or false)
    if can then
      local onF = GetFlag(bag, fb.flag)
      local pf = self.pendingFlag
      if pf and pf.bag == bag and pf.flag == fb.flag then onF = pf.value end
      EdgeColor(fb.edge, onF and acc or Col("edge", {0.4, 0.4, 0.3, 1}), 1)
      fb.icon:SetDesaturated(not onF); fb.icon:SetAlpha(onF and 1 or 0.5)
      if onF then fb.text:SetTextColor(acc[1], acc[2], acc[3]) else fb.text:SetTextColor(0.6, 0.6, 0.6) end
    end
  end
  s.fLabel:SetText(string.format(T("filters"), BagName(bag or 0)))
  s.fLabel:SetShown(bag and bag > 0 and true or false)
  local ign
  if (bag or 0) == 0 then ign = Plain(Call(C_Container and C_Container.GetBackpackAutosortDisabled))
  else ign = GetFlag(bag, "DisableAutoSort") end
  s.sort:ClearAllPoints(); s.sort:SetPoint("RIGHT", s.ignore.text, "LEFT", -12, 0)
  s.sort.text:SetText(T("sort"))
  s.sort:SetShown(Pad() and true or false)
  s.ignore.mark:SetVertexColor(acc[1], acc[2], acc[3], ign and 1 or 0)
  s.ignore.text:SetText(T("ignore"))
  -- Right end of the filter row, its text to the left of the box.
  s.ignore:ClearAllPoints(); s.ignore:SetPoint("BOTTOMRIGHT", -8, 6)
  s.ignore.text:ClearAllPoints(); s.ignore.text:SetPoint("RIGHT", s.ignore, "LEFT", -4, 0)
  -- Ammo in the ammo slot, price of grey items.
  local ammo = Plain(Call(GetInventoryItemCount, "player", 0)) or 0
  local ammoID = Plain(Call(GetInventoryItemID, "player", 0))
  s.ammo:SetText(ammoID and string.format(T("ammo"), ammo) or "")
  local junk = 0
  for _, b2 in ipairs(BAGS) do
    for slot = 1, NumSlots(b2) do
      local info = Call(C_Container.GetContainerItemInfo, b2, slot)
      if type(info) == "table" and Plain(info.quality) == 0 and not Plain(info.hasNoValue) then
        local price = select(11, Call(C_Item and C_Item.GetItemInfo or GetItemInfo, Plain(info.itemID) or 0))
        price = Plain(price)
        if type(price) == "number" then junk = junk + price * (Plain(info.stackCount) or 1) end
      end
    end
  end
  s.junk:SetText(junk > 0 and string.format(T("junk"), Money(junk)) or "")
  s:Show()
  self:Paint()
  self:PadPanel(Pad())
end

-- Gamepad: the strip is NOT wired into the game's navigation. Doing that
-- (RefreshButtonGroups, jump overrides, buttonContext) from an addon tainted
-- the bag window's navigation and the game blocked PetSkillScout when items
-- were used with the gamepad. The strip works with the mouse only there.

-- Gamepad: the strip is its own gamepad panel, the documented way
-- (FrameControlsManager.lua: "A frame can subscribe to this by ... manually
-- calling FrameShown on their OnShow event"). LT / RT move between the bag
-- window and the strip; inside it the D-pad moves and A presses
-- (SmartNavigation:Click calls OnSmartNavClick). It does not take the focus
-- by itself (shouldFocusFrame false).
local function SmartClick(b)
  if b.OnSmartNavClick then return end
  b.OnSmartNavClick = function(self)
    local fn = self:GetScript("OnClick")
    if fn then pcall(fn, self, "LeftButton") end
    return true
  end
end
function B:PadPanel(on)
  local s = strip
  local M = GamepadMode and GamepadMode.FrameControlsManager
  if not (s and M) then return end
  if on and s:IsShown() then
    for _, b in ipairs(s.bags) do SmartClick(b) end
    for _, b in ipairs(s.filters) do SmartClick(b) end
    SmartClick(s.ignore); SmartClick(s.sort)
    if not self.padShown then self.padShown = true; pcall(M.FrameShown, M, s, false, false) end
  elseif self.padShown then
    self.padShown = nil
    pcall(M.FrameHidden, M, s)
  end
end

-- Hooks and events -----------------------------------------------------------------
local hooked = {}
local function Soon() PSS:Soon("bags-ui", function() pcall(B.Refresh, B) end, 0.05) end
local function HookFrame(f)
  if not f or hooked[f] then return end
  hooked[f] = true
  pcall(f.HookScript, f, "OnShow", Soon)
  pcall(f.HookScript, f, "OnHide", Soon)
  for _, m in ipairs({"UpdateItems", "UpdateSearchBox", "UpdateFrameSize"}) do
    if type(f[m]) == "function" then pcall(PSS.HookSecure, f, m, Soon) end
  end
end
function B:Hook()
  HookFrame(G("ContainerFrameCombinedBags"))
  for i = 1, 13 do HookFrame(G("ContainerFrame" .. i)) end
  local sb = G("BagItemSearchBox")
  if sb and not hooked[sb] then
    hooked[sb] = true
    -- Esc clears the search first, then (next Esc) closes the bags.
    pcall(sb.HookScript, sb, "OnEscapePressed", function(self)
      if On() and (self:GetText() or "") ~= "" then self:SetText("") end
    end)
  end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "BAG_SLOT_FLAGS_UPDATED",
    "UNIT_PET", "PLAYER_REGEN_ENABLED", "UNIT_INVENTORY_CHANGED"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function()
  B:Hook()
  if Main() then Soon() end
end)

-- Option texts (Settings > Theme).
local OPT = {
  en = {"Themed bags", "Search, Clean Up and bag filters on top, a bag strip below, quality edges and pet food marks"},
  uk = {"Сумки в стилі теми", "Пошук, прибирання й фільтри сумок угорі, смуга сумок унизу, рамки якості та позначки їжі пета"},
  pl = {"Torby w stylu motywu", "Wyszukiwanie, porządkowanie i filtry u góry, pasek toreb na dole, ramki jakości i jedzenie zwierzaka"},
  de = {"Taschen im Design", "Suche, Aufräumen und Filter oben, Taschenleiste unten, Qualitätsrahmen und Tierfutter-Markierung"},
  fr = {"Sacs au thème", "Recherche, rangement et filtres en haut, barre des sacs en bas, bords de qualité et nourriture du familier"},
  it = {"Borse a tema", "Ricerca, riordino e filtri in alto, barra delle borse in basso, bordi di qualità e cibo del famiglio"},
  es = {"Bolsas con el tema", "Búsqueda, ordenar y filtros arriba, barra de bolsas abajo, bordes de calidad y comida de la mascota"},
  pt = {"Bolsas no tema", "Busca, organizar e filtros em cima, barra de bolsas embaixo, bordas de qualidade e comida do ajudante"},
  ru = {"Сумки в стиле темы", "Поиск, сортировка и фильтры сверху, полоса сумок снизу, рамки качества и метки еды питомца"},
}
for lang, t in pairs(OPT) do
  PSS.Locale[lang] = PSS.Locale[lang] or {}
  PSS.Locale[lang].optBagsUI, PSS.Locale[lang].optBagsUIHint = t[1], t[2]
end

-- Key binding: Clean Up (Key Bindings > PetSkillScout); works with a gamepad
-- button bound to it outside the bag window's own controls.
function PetSkillScout_SortBags()
  if PlaySound and SOUNDKIT and SOUNDKIT.UI_BAG_SORTING_01 then PlaySound(SOUNDKIT.UI_BAG_SORTING_01) end
  Call(C_Container and C_Container.SortBags)
end
BINDING_NAME_PETSKILLSCOUT_SORTBAGS = (TEXT[(PetSkillScoutDB and PetSkillScoutDB.language) or "en"] or TEXT.en).sort

-- Gamepad control: the game's bag menu (Y "Manage Bag" on the bag window's
-- portrait; ContainerFrame.lua builds it with Menu, tags
-- MENU_CONTAINER_FRAME_COMBINED / MENU_CONTAINER_FRAME). Menu.ModifyMenu is
-- the way the game lets addons add entries, so the gamepad reaches them with
-- its own navigation (the bag filters and "ignore on Clean Up" are already
-- in that menu from the game). Added: Clean Up, and which bag to show.
if Menu and Menu.ModifyMenu then
  local function Add(owner, root)
    if not On() then return end
    root:CreateDivider()
    root:CreateTitle("PetSkillScout")
    root:CreateButton(T("sort"), function() PetSkillScout_SortBags() end)
    local function IsFocus(bag) return DB().bagFocus == bag end
    local function SetFocus(bag)
      if PetSkillScoutDB then PetSkillScoutDB.bagFocus = bag end
      B.selBag = bag or B.selBag
      B:Refresh()
    end
    root:CreateRadio(T("allBags"), function() return DB().bagFocus == nil end, function() SetFocus(nil) end)
    for _, bag in ipairs(BAGS) do
      if NumSlots(bag) > 0 then
        root:CreateRadio(string.format("%s  %d/%d", BagName(bag), NumSlots(bag) - Free(bag), NumSlots(bag)),
          function() return IsFocus(bag) end, function() SetFocus(bag) end)
      end
    end
  end
  for _, tag in ipairs({"MENU_CONTAINER_FRAME_COMBINED", "MENU_CONTAINER_FRAME"}) do
    pcall(Menu.ModifyMenu, tag, Add)
  end
end
for lang, v in pairs({en = "Show all bags", uk = "Показати всі сумки", pl = "Pokaż wszystkie torby", de = "Alle Taschen zeigen",
    fr = "Afficher tous les sacs", it = "Mostra tutte le borse", es = "Mostrar todas las bolsas", pt = "Mostrar todas as bolsas",
    ru = "Показать все сумки"}) do
  TEXT[lang].allBags = v
end
