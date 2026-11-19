-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- PetSkillScout's own inventory window, in the addon's theme, for keyboard
-- and mouse and for the gamepad. Replaces the game's bag windows while on.
--
-- How it is built (WoW: Forever UI code, ui-forever):
--  * The game's bag windows (ContainerFrameCombinedBags, ContainerFrame1..13)
--    are closed as soon as they open (CloseAllBags, not protected), and ours
--    opens in their place; opening the bags again closes ours (a toggle).
--  * The picture (cells with icon, count, quality, cooldown) is plain frames,
--    so the window opens and is drawn in combat too.
--  * Item use goes through secure buttons (SecureActionButtonTemplate,
--    type "item", item "<bag> <slot>"), laid over the cells. They are made
--    once out of combat and only shown, hidden or moved out of combat. In
--    combat the window is for looking only (the game forbids more).
--  * Gamepad: while the window is open, out of combat, the pad keys are bound
--    to our buttons with SetOverrideBindingClick (the way the game's own
--    gamepad UI binds them, InputBindingStack): D-pad moves, A uses, X picks
--    up / puts down, Y cleans up, B closes, LB / RB show one bag.
--    Key names: GAMEPAD_* globals (PAD1 A, PAD2 B, PAD3 X, PAD4 Y...).
local PSS = PetSkillScout
PSS.Inventory = {}
local I = PSS.Inventory

local FLAT = "Interface\\Buttons\\WHITE8X8"
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
local COLS, SIZE, GAP = 10, 36, 4
local BAGS = {0, 1, 2, 3, 4}
-- The reagent bag (bag 5) on clients that have one.
if Constants and Constants.InventoryConstants and (Constants.InventoryConstants.NumReagentBagSlots or 0) > 0 then
  BAGS[#BAGS + 1] = (Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag) or 5
end
local MAXSLOTS = 180

local function G(n) return _G[n] end
local function Plain(v) if PSS.IsSecret and PSS.IsSecret(v) then return nil end return v end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function DB() return PetSkillScoutDB or {} end
local function Col(k, def)
  local c = PSS.Skin and PSS.Skin.Colour and PSS.Skin:Colour(k)
  return c or def
end
local function Pad() return InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled() and true or false end
-- Part of the theme: off whenever the theme is off (or RevUI draws it).
function I:Enabled()
  if DB().ownBags ~= true or (PSS.RevUILoaded and PSS:RevUILoaded()) then return false end
  if PSS.Skin and PSS.Skin.Wanted and not PSS.Skin:Wanted() then return false end
  return true
end -- off unless switched on

local TEXT = {
  en = {title = "Inventory", search = "Search...", sort = "Sort", all = "All bags", backpack = "Backpack",
    padHelp = "A use   X pick up / put   Y clean up   LB/RB bag   B close   Select: game / window", combat = "In combat: view only",
    mouseHelp = "Right-click: use   Left-click: pick up / put"},
  uk = {title = "Інвентар", search = "Пошук...", sort = "Сортувати", all = "Усі сумки", backpack = "Рюкзак",
    padHelp = "A використати   X взяти / покласти   Y прибрати   LB/RB сумка   B закрити   Select: гра / вікно", combat = "У бою: лише перегляд",
    mouseHelp = "Права кнопка: використати   Ліва: взяти / покласти"},
  pl = {title = "Ekwipunek", search = "Szukaj...", sort = "Sortuj", all = "Wszystkie torby", backpack = "Plecak",
    padHelp = "A użyj   X weź / połóż   Y uporządkuj   LB/RB torba   B zamknij", combat = "W walce: tylko podgląd",
    mouseHelp = "Prawy: użyj   Lewy: weź / połóż"},
  de = {title = "Inventar", search = "Suchen...", sort = "Sortieren", all = "Alle Taschen", backpack = "Rucksack",
    padHelp = "A benutzen   X aufnehmen / ablegen   Y aufräumen   LB/RB Tasche   B schließen", combat = "Im Kampf: nur ansehen",
    mouseHelp = "Rechtsklick: benutzen   Linksklick: aufnehmen / ablegen"},
  fr = {title = "Inventaire", search = "Rechercher...", sort = "Trier", all = "Tous les sacs", backpack = "Sac à dos",
    padHelp = "A utiliser   X prendre / poser   Y ranger   LB/RB sac   B fermer", combat = "En combat : lecture seule",
    mouseHelp = "Clic droit : utiliser   Clic gauche : prendre / poser"},
  it = {title = "Inventario", search = "Cerca...", sort = "Ordina", all = "Tutte le borse", backpack = "Zaino",
    padHelp = "A usa   X prendi / posa   Y riordina   LB/RB borsa   B chiudi", combat = "In combattimento: solo vista",
    mouseHelp = "Destro: usa   Sinistro: prendi / posa"},
  es = {title = "Inventario", search = "Buscar...", sort = "Ordenar", all = "Todas las bolsas", backpack = "Mochila",
    padHelp = "A usar   X coger / dejar   Y ordenar   LB/RB bolsa   B cerrar", combat = "En combate: solo ver",
    mouseHelp = "Clic derecho: usar   Clic izquierdo: coger / dejar"},
  pt = {title = "Inventário", search = "Buscar...", sort = "Organizar", all = "Todas as bolsas", backpack = "Mochila",
    padHelp = "A usar   X pegar / pôr   Y organizar   LB/RB bolsa   B fechar", combat = "Em combate: só ver",
    mouseHelp = "Clique direito: usar   Esquerdo: pegar / pôr"},
  ru = {title = "Инвентарь", search = "Поиск...", sort = "Сортировать", all = "Все сумки", backpack = "Рюкзак",
    padHelp = "A использовать   X взять / положить   Y разобрать   LB/RB сумка   B закрыть", combat = "В бою: только просмотр",
    mouseHelp = "Правая кнопка: использовать   Левая: взять / положить"},
}
local function T(k)
  local l = TEXT[DB().language or "en"] or TEXT.en
  return l[k] or TEXT.en[k]
end

-- Small helpers ----------------------------------------------------------------
local function Edges(parent, w)
  local e = {}
  for i = 1, 4 do
    e[i] = parent:CreateTexture(nil, "OVERLAY", nil, 6); e[i]:SetTexture(FLAT)
    -- Thin lines snapped to the pixel grid can round to zero pixels at some
    -- window positions / UI scales and vanish (the game's NineSlice turns the
    -- snapping off the same way).
    pcall(e[i].SetSnapToPixelGrid, e[i], false); pcall(e[i].SetTexelSnappingBias, e[i], 0)
  end
  e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(w or 1)
  e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(w or 1)
  e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(w or 1)
  e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(w or 1)
  return e
end
local function EdgeColor(e, c, a)
  for i = 1, 4 do e[i]:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1); e[i]:Show() end
end
local function EdgeHide(e) for i = 1, 4 do e[i]:Hide() end end
local function Text(parent, size, c, flags)
  local s = parent:CreateFontString(nil, "OVERLAY"); s:SetFont(FONT, size, flags or "")
  c = c or Col("cream", {0.95, 0.89, 0.78})
  s:SetTextColor(c[1], c[2], c[3])
  return s
end
local function Fill(parent, layer, c, a)
  local t = parent:CreateTexture(nil, layer); t:SetTexture(FLAT); t:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1)
  return t
end
-- The theme's refresh (after a loading screen, a theme change) takes every
-- backdrop it drew away and redraws only the game's windows: ours are put
-- back each time the window is refreshed.
local themed = {}
local function ReBackdrop()
  local S = PSS.Skin
  if not (S and S.active and S.Backdrop) then return end
  for f, kind in pairs(themed) do pcall(S.Backdrop, S, f, kind) end
end
local function Backdrop(f, kind)
  if PSS.Skin and PSS.Skin.active and PSS.Skin.Backdrop then
    themed[f] = kind
    local ok = pcall(PSS.Skin.Backdrop, PSS.Skin, f, kind)
    if ok then return end
  end
  Fill(f, "BACKGROUND", {0.05, 0.08, 0.07}, 0.95):SetAllPoints()
  EdgeColor(Edges(f, 1), {0.4, 0.4, 0.3})
end
local function Btn(parent, name, w, label, fn)
  local b = CreateFrame("Button", name, parent)
  b:SetSize(w, 24)
  Backdrop(b, "button")
  b.text = Text(b, 11); b.text:SetPoint("CENTER"); b.text:SetText(label or "")
  b:SetScript("OnClick", fn)
  return b
end
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

-- The window ---------------------------------------------------------------------
local win, cells, secure, bagBtns = nil, {}, {}, {}
local Blocked
local function Build()
  if win then return win end
  win = CreateFrame("Frame", "PetSkillScoutInventory", UIParent)
  -- HIGH like the game's own windows beside it: at DIALOG it covered the
  -- loot window (HIGH) that opens when a clam or a box is opened from it.
  win:SetFrameStrata("HIGH"); win:SetToplevel(true)
  win:SetClampedToScreen(true)
  win:EnableMouse(true); win:SetMovable(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", function(self) if not InCombat() then self:StartMoving() end end)
  win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Saved only when moved at its own place, as a spot on the screen.
    if not I.withPartner and PetSkillScoutDB then
      local l, b = self:GetLeft(), self:GetBottom()
      if l and b then PetSkillScoutDB.invPos = {"BOTTOMLEFT", "BOTTOMLEFT", l, b} end
    end
    I:PlaceSecure()
  end)
  -- Solid background of its own (the theme's backdrop alone came out
  -- see-through: the quest list showed through the window).
  local wc = Col("window", {0.05, 0.08, 0.07, 1})
  win.bgFill = Fill(win, "BACKGROUND", wc, 1); win.bgFill:SetAllPoints()
  win.bgFill:SetDrawLayer("BACKGROUND", -8)
  EdgeColor(Edges(win, 1), Col("edge", {0.4, 0.4, 0.3}))
  -- Header: title, search, Clean Up, close.
  win.title = Text(win, 15); win.title:SetPoint("TOPLEFT", 12, -10)
  win.close = Btn(win, "PetSkillScoutInventoryClose", 24, "X", function() I:Close() end)
  win.close:SetPoint("TOPRIGHT", -8, -8)
  win.sort = Btn(win, "PetSkillScoutInventorySort", 90, "", function() I:Sort() end)
  win.sort:SetPoint("RIGHT", win.close, "LEFT", -6, 0)
  win.search = CreateFrame("EditBox", "PetSkillScoutInventorySearch", win)
  win.search:SetHeight(22); win.search:SetAutoFocus(false); win.search:SetFont(FONT, 12, "")
  win.search:SetTextInsets(6, 6, 0, 0)
  Backdrop(win.search, "input")
  win.search:SetPoint("LEFT", win.title, "RIGHT", 14, 0)
  win.search:SetPoint("RIGHT", win.sort, "LEFT", -8, 0)
  win.search.hint = Text(win.search, 11, Col("muted", {0.66, 0.74, 0.67}))
  win.search.hint:SetPoint("LEFT", 6, 0)
  win.search:SetScript("OnTextChanged", function(self)
    self.hint:SetShown(self:GetText() == "")
    Call(C_Container and C_Container.SetItemSearch, self:GetText() or "")
    I:Paint()
  end)
  win.search:SetScript("OnEscapePressed", function(self)
    if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
  end)
  win.search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  win.line = Fill(win, "ARTWORK", Col("accent", {0.85, 0.7, 0.43}), 0.6); win.line:SetHeight(1)
  win.line:SetPoint("TOPLEFT", 10, -40); win.line:SetPoint("TOPRIGHT", -10, -40)
  -- Bag row.
  for i, bag in ipairs(BAGS) do
    local b = CreateFrame("Button", "PetSkillScoutInventoryBag" .. i, win)
    b:SetSize(28, 28)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.edge = Edges(b, 1)
    b.count = Text(b, 10); b.count:SetPoint("LEFT", b, "RIGHT", 4, 4)
    b.barBg = Fill(b, "ARTWORK", {0, 0, 0}, 0.6); b.barBg:SetSize(30, 3); b.barBg:SetPoint("TOPLEFT", b, "BOTTOMRIGHT", 4, 9)
    b.bar = Fill(b, "OVERLAY", {0.45, 0.85, 0.5}); b.bar:SetHeight(3); b.bar:SetPoint("LEFT", b.barBg, "LEFT")
    b.bag = bag
    b:SetScript("OnClick", function(self) I:Focus(DB().bagFocus ~= self.bag and self.bag or nil) end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(BagName(self.bag))
      GameTooltip:AddLine(string.format("%d / %d", NumSlots(self.bag) - Free(self.bag), NumSlots(self.bag)), 1, 1, 1)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    bagBtns[i] = b
  end
  win.line2 = Fill(win, "ARTWORK", Col("accent", {0.85, 0.7, 0.43}), 0.2); win.line2:SetHeight(1)
  -- Item cells (picture only).
  for i = 1, MAXSLOTS do
    local c = CreateFrame("Frame", nil, win)
    c:SetSize(SIZE, SIZE)
    c.bg = Fill(c, "BACKGROUND", {0, 0, 0}, 0.55); c.bg:SetAllPoints()
    c.icon = c:CreateTexture(nil, "ARTWORK"); c.icon:SetPoint("TOPLEFT", 1, -1); c.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.edge = Edges(c, 1)
    c.count = Text(c, 11, {1, 1, 1}, "OUTLINE"); c.count:SetPoint("BOTTOMRIGHT", -2, 2)
    c.cd = CreateFrame("Cooldown", nil, c, "CooldownFrameTemplate"); c.cd:SetAllPoints(c.icon)
    pcall(c.cd.SetSwipeTexture, c.cd, FLAT); pcall(c.cd.SetSwipeColor, c.cd, 0, 0, 0, 0.6)
    -- Quest items: the game's own border / "!" (ContainerFrameItemButtonMixin:UpdateQuestItem).
    c.quest = c:CreateTexture(nil, "OVERLAY", nil, 5); c.quest:SetAllPoints(); c.quest:Hide()
    c.paw = c:CreateTexture(nil, "OVERLAY", nil, 7); c.paw:SetSize(12, 12); c.paw:SetPoint("TOPRIGHT", -1, -1)
    c.paw:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTraining"); c.paw:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c:Hide()
    cells[i] = c
  end
  -- Footer: money, help.
  win.money = Text(win, 12); win.money:SetPoint("BOTTOMRIGHT", -12, 10)
  -- Help: up to two lines inside the window, light text (it ran past the
  -- edge and was hard to read in one dim line).
  win.help = Text(win, 11, Col("cream", {0.95, 0.89, 0.78}))
  win.help:SetPoint("BOTTOMLEFT", 12, 30); win.help:SetPoint("BOTTOMRIGHT", -12, 30)
  win.help:SetJustifyH("LEFT"); win.help:SetWordWrap(true); win.help:SetSpacing(3)
  win.line3 = Fill(win, "ARTWORK", Col("accent", {0.85, 0.7, 0.43}), 0.2); win.line3:SetHeight(1)
  win.line3:SetPoint("BOTTOMLEFT", 10, 64); win.line3:SetPoint("BOTTOMRIGHT", -10, 64)
  -- Gamepad selection mark.
  -- Gold glow on the window's edges while the gamepad controls it.
  win.glow = CreateFrame("Frame", nil, win); win.glow:SetPoint("TOPLEFT", -3, 3); win.glow:SetPoint("BOTTOMRIGHT", 3, -3)
  win.glow:SetFrameLevel(win:GetFrameLevel() + 40)
  win.glow.edge = Edges(win.glow, 3); win.glow:Hide()
  win.sel = CreateFrame("Frame", nil, win); win.sel:SetFrameLevel(win:GetFrameLevel() + 30)
  win.sel.edge = Edges(win.sel, 2); win.sel:Hide()
  win:SetScript("OnHide", function() I:OnHidden() end)
  win:Hide()
  return win
end

-- Secure buttons: one per slot, made once out of combat.
local function MakeSecure()
  if #secure > 0 or InCombat() then return end
  for i = 1, MAXSLOTS do
    local s = CreateFrame("Button", "PetSkillScoutInvItem" .. i, Build(), "SecureActionButtonTemplate")
    s.pssNav = "item"
    s:SetSize(SIZE, SIZE)
    s:RegisterForClicks("AnyUp", "AnyDown")
    s:SetAttribute("useOnKeyDown", false)
    -- "/use bag slot" (SlashCommands.lua -> SecureCmdUseItem ->
    -- C_Container.UseContainerItem): sells at a merchant, moves at a bank,
    -- places in mail / trade, else uses or equips - what a right click in the
    -- game's bag does. (type "item" equips gear first: SecureTemplates.lua.)
    s:SetAttribute("type2", "macro")
    s:SetFrameStrata("HIGH")
    s:SetScript("PostClick", function(self, button, down)
      -- Up and down both arrive now: pick up once, on the up press (or a Click()).
      if down or button ~= "LeftButton" or not self.bag then return end
      local link = Plain(Call(C_Container.GetContainerItemLink, self.bag, self.slot))
      if link and HandleModifiedItemClick and IsModifiedClick() and HandleModifiedItemClick(link) then return end
      Call(C_Container.PickupContainerItem, self.bag, self.slot)
    end)
    -- Drag with the mouse: pick the item up as the drag starts, put it down
    -- where the mouse is let go (like the game's bag buttons).
    s:RegisterForDrag("LeftButton")
    s:SetScript("OnDragStart", function(self)
      if self.bag and not CursorHasItem() then Call(C_Container.PickupContainerItem, self.bag, self.slot) end
    end)
    s:SetScript("OnReceiveDrag", function(self)
      if self.bag and CursorHasItem() then Call(C_Container.PickupContainerItem, self.bag, self.slot) end
    end)
    s:SetScript("OnEnter", function(self) I:Tip(self) end)
    s:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end; ResetCursor() end)
    s:Hide()
    secure[i] = s
  end
end

-- Contents -----------------------------------------------------------------------
local slots = {} -- index -> {bag, slot}
local function Layout()
  wipe(slots)
  for _, bag in ipairs(BAGS) do
    for slot = 1, NumSlots(bag) do slots[#slots + 1] = {bag = bag, slot = slot} end
  end
  local n = math.min(#slots, MAXSLOTS)
  local rows = math.ceil(n / COLS)
  local w = COLS * (SIZE + GAP) - GAP + 24
  local top = 92
  win:SetSize(math.max(w, 380), top + rows * (SIZE + GAP) - GAP + 80)
  local per = math.floor((win:GetWidth() - 24) / #BAGS)
  for i, b in ipairs(bagBtns) do b:ClearAllPoints(); b:SetPoint("TOPLEFT", 12 + (i - 1) * per, -48) end
  win.line2:ClearAllPoints(); win.line2:SetPoint("TOPLEFT", 10, -84); win.line2:SetPoint("TOPRIGHT", -10, -84)
  for i, c in ipairs(cells) do
    if i <= n then
      local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
      c:ClearAllPoints(); c:SetPoint("TOPLEFT", win, "TOPLEFT", 12 + col * (SIZE + GAP), -top - row * (SIZE + GAP))
      c.bag, c.slot = slots[i].bag, slots[i].slot
      c:Show()
    else
      c:Hide(); c.bag = nil
    end
  end
  I.count = n
end

function I:PlaceSecure()
  if InCombat() or #secure == 0 then self.securePending = true; return end
  self.securePending = nil
  local open = I:IsOpen()
  for i, s in ipairs(secure) do
    local c = cells[i]
    if open and c and c:IsShown() and c.bag then
      s.bag, s.slot = c.bag, c.slot
      s:SetAttribute("macrotext2", (SLASH_USE1 or "/use") .. " " .. c.bag .. " " .. c.slot)
      s:ClearAllPoints(); s:SetAllPoints(c)
      s:SetFrameLevel(win:GetFrameLevel() + 20)
      s:Show()
    else
      s:Hide()
    end
  end
end

local diet
function I:Paint()
  if not (win and win:IsShown()) then return end
  local acc = Col("accent", {0.85, 0.7, 0.43, 1})
  local focus = DB().bagFocus
  local searching = win.search:GetText() ~= ""
  for i = 1, self.count or 0 do
    local c = cells[i]
    local info = Call(C_Container.GetContainerItemInfo, c.bag, c.slot)
    info = type(info) == "table" and info or nil
    local icon = info and Plain(info.iconFileID)
    c.icon:SetTexture(icon)
    c.icon:SetShown(icon ~= nil)
    local n = info and Plain(info.stackCount) or 0
    c.count:SetText(n and n > 1 and n or "")
    local q = info and Plain(info.quality)
    if q and q >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q] then
      local qc = ITEM_QUALITY_COLORS[q]; EdgeColor(c.edge, {qc.r, qc.g, qc.b}, 1)
    else
      EdgeColor(c.edge, Col("edge", {0.3, 0.3, 0.25}), 0.6)
    end
    c.icon:SetVertexColor(q == 0 and 0.55 or 1, q == 0 and 0.55 or 1, q == 0 and 0.55 or 1)
    if info and Plain(info.isLocked) then c.icon:SetDesaturated(true) else c.icon:SetDesaturated(false) end
    local qi = info and Call(C_Container.GetContainerItemQuestInfo, c.bag, c.slot)
    local isQ, qID, qAct = type(qi) == "table" and Plain(qi.isQuestItem), type(qi) == "table" and Plain(qi.questID),
      type(qi) == "table" and Plain(qi.isActive)
    if qID and not qAct then c.quest:SetTexture(TEXTURE_ITEM_QUEST_BANG or "Interface\\ContainerFrame\\UI-Icon-QuestBang"); c.quest:Show()
    elseif qID or isQ then c.quest:SetTexture(TEXTURE_ITEM_QUEST_BORDER or "Interface\\ContainerFrame\\UI-Icon-QuestBorder"); c.quest:Show()
    else c.quest:Hide() end
    local id = info and Plain(info.itemID)
    local food = id and PSS.Foods and PSS.Foods[id]
    c.paw:SetShown(food and diet and diet[food[1]] and true or false)
    local s, d, e = Call(C_Container.GetContainerItemCooldown, c.bag, c.slot)
    if s and d and e then pcall(c.cd.SetCooldown, c.cd, s, d) else c.cd:Clear() end
    local dim = (focus ~= nil and c.bag ~= focus) or (searching and info and Plain(info.isFiltered))
    c:SetAlpha(dim and 0.2 or 1)
  end
  for _, b in ipairs(bagBtns) do
    local n = NumSlots(b.bag)
    b:SetShown(n > 0)
    if n > 0 then
      local used = n - Free(b.bag)
      b.icon:SetTexture(BagIcon(b.bag))
      b.count:SetText(used .. "/" .. n)
      local fill = used / n
      b.bar:SetWidth(math.max(1, 30 * fill))
      if fill >= 1 then b.bar:SetVertexColor(1, 0.35, 0.35) elseif fill >= 0.8 then b.bar:SetVertexColor(1, 0.8, 0.3)
      else b.bar:SetVertexColor(0.45, 0.85, 0.5) end
      EdgeColor(b.edge, focus == b.bag and acc or Col("edge", {0.4, 0.4, 0.3}), 1)
      b.icon:SetAlpha((focus == nil or focus == b.bag) and 1 or 0.45)
    end
  end
  local money = Plain(Call(GetMoney)) or 0
  -- Gold / silver / copper with the coin icons.
  local B = "|TInterface\\MoneyFrame\\UI-%sIcon:12:12:2:0|t"
  local g, sv, cp = math.floor(money / 10000), math.floor(money / 100) % 100, money % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. B:format("Gold") end
  if g > 0 or sv > 0 then parts[#parts + 1] = sv .. B:format("Silver") end
  parts[#parts + 1] = cp .. B:format("Copper")
  win.money:SetText(table.concat(parts, " "))
  local h = InCombat() and T("combat") or self:HelpText()
  -- Keys in the accent colour, actions in light text, a dot between them.
  local hex = string.format("%02x%02x%02x", acc[1] * 255, acc[2] * 255, acc[3] * 255)
  h = h:gsub("   ", "  |cff666666·|r  ")
  h = h:gsub("(%f[%w]%u%u?/?%u?%u?%f[%W])", "|cff" .. hex .. "%1|r")
  win.help:SetText(h)
  self:ShowSel()
end

-- What X / a right click does on an item now: sell at a merchant, move at a
-- bank, place in mail / trade / auction, else use - the game's own words
-- (BetterBags gamepad.lua USE_LABELS, ContainerFrame.lua).
local USE_AT = {
  {"MerchantFrame", "CONTEXT_ACTION_LABEL_SELL"}, {"BankFrame", "CONTEXT_ACTION_LABEL_MOVE"},
  {"GuildBankFrame", "CONTEXT_ACTION_LABEL_MOVE"}, {"MailFrame", "CONTEXT_ACTION_LABEL_PLACE"},
  {"TradeFrame", "CONTEXT_ACTION_LABEL_PLACE"}, {"AuctionHouseFrame", "CONTEXT_ACTION_LABEL_PLACE"},
  {"AuctionFrame", "CONTEXT_ACTION_LABEL_PLACE"},
}
local KEYS = {
  en = {pick = "pick up / put", close = "close", win = "next window", game = "game", rc = "Right-click", lc = "Left-click"},
  uk = {pick = "взяти / покласти", close = "закрити", win = "інше вікно", game = "гра", rc = "Права кнопка", lc = "Ліва"},
  ru = {pick = "взять / положить", close = "закрыть", win = "другое окно", game = "игра", rc = "Правая кнопка", lc = "Левая"},
  pl = {pick = "weź / połóż", close = "zamknij", win = "inne okno", game = "gra", rc = "Prawy", lc = "Lewy"},
  de = {pick = "aufnehmen / ablegen", close = "schließen", win = "anderes Fenster", game = "Spiel", rc = "Rechtsklick", lc = "Linksklick"},
  fr = {pick = "prendre / poser", close = "fermer", win = "autre fenêtre", game = "jeu", rc = "Clic droit", lc = "Clic gauche"},
  it = {pick = "prendi / posa", close = "chiudi", win = "altra finestra", game = "gioco", rc = "Destro", lc = "Sinistro"},
  es = {pick = "coger / dejar", close = "cerrar", win = "otra ventana", game = "juego", rc = "Clic derecho", lc = "Clic izquierdo"},
  pt = {pick = "pegar / pôr", close = "fechar", win = "outra janela", game = "jogo", rc = "Clique direito", lc = "Esquerdo"},
}
function I:UseLabel()
  for _, u in ipairs(USE_AT) do
    local f = G(u[1])
    if f and f:IsShown() and _G[u[2]] then return _G[u[2]] end
  end
  return _G.CONTEXT_ACTION_LABEL_USE or (_G.USE or "Use")
end
function I:HelpText()
  local k = KEYS[DB().language or "en"] or KEYS.en
  local use = self:UseLabel()
  if Pad() then
    local more = ({uk = "ще", ru = "ещё", pl = "więcej", de = "mehr", fr = "plus", it = "altro", es = "más", pt = "mais"})[DB().language or "en"] or "more"
    local t = "X " .. use .. "   A " .. k.pick .. "   Y " .. more .. "   B " .. k.close
    if self.Partner and self.Partner() then t = t .. "   LT/RT " .. k.win end
    return t .. "   Select " .. k.game
  end
  return k.rc .. ": " .. use .. "   " .. k.lc .. ": " .. k.pick
end

function I:Tip(owner, c)
  if self.closed then return end
  local bag, slot = owner.bag or (c and c.bag), owner.slot or (c and c.slot)
  if not bag then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  pcall(GameTooltip.SetBagItem, GameTooltip, bag, slot)
  GameTooltip:Show()
end

function I:Refresh()
  if not win then return end
  win.title:SetText(T("title"))
  win.sort.text:SetText(T("sort"))
  win.search.hint:SetText(T("search"))
  ReBackdrop()
  if PSS.PetCare and PSS.PetCare.Diet then
    local ok, d = pcall(PSS.PetCare.Diet, PSS.PetCare); diet = ok and d or nil
  end
  if not InCombat() then Layout(); self:PlaceSecure() end
  self:Paint()
end

-- Open / close ---------------------------------------------------------------------
-- The item buttons are secure children of the window, so the game treats the
-- window as protected: it cannot be shown or hidden in combat. So it is never
-- hidden once shown: "closed" is invisible (alpha 0, no mouse, item buttons
-- hidden out of combat). In combat it can still be opened and closed - for
-- looking only.
Blocked = function() return InCombat() and win and win:IsProtected() end
-- Closed (invisible) window: its buttons must not catch the mouse either
-- (bag buttons showed their tooltips over the game world). Protected ones
-- are left alone in combat and done after it.
local muted = setmetatable({}, {__mode = "k"})
local function MuteChildren(root, off)
  for _, c in ipairs({root:GetChildren()}) do
    if not (InCombat() and c:IsProtected()) then
      if off then
        if c:IsMouseEnabled() then muted[c] = true; c:EnableMouse(false) end
      elseif muted[c] then
        muted[c] = nil; c:EnableMouse(true)
      end
    end
    MuteChildren(c, off)
  end
end
I.MuteChildren = function(off) if win then MuteChildren(win, off) end end
function I:IsOpen() return win and win:IsShown() and not self.closed and true or false end
function I:Open()
  if not self:Enabled() then return end
  Build()
  self.closed = nil
  win:SetAlpha(1)
  MuteChildren(win, false)
  if InCombat() then
    if not win:IsShown() and not win:IsProtected() then win:Show() end
    self:Paint()
    return
  end
  MakeSecure()
  -- Its own place each time it opens on its own (the spot beside a merchant
  -- or bank is only for that visit).
  if not self.withPartner then
    self.placed = true
    win:ClearAllPoints()
    local p = DB().invPos
    if p then win:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else win:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 120) end
  end
  win:Show(); win:EnableMouse(true)
  self:Refresh()
  self.sel = self.sel or 1
  I.Schedule()
end
function I:Close()
  if not win then return end
  self.closed = true
  win:SetAlpha(0)
  MuteChildren(win, true)
  if not InCombat() then win:EnableMouse(false); self:PlaceSecure() else self.securePending = true end
  win.search:ClearFocus()
  if GameTooltip:GetOwner() and GameTooltip:GetOwner().bag then GameTooltip:Hide() end
  I.unfocused = nil; I.withPartner = nil
  I.Schedule()
end
function I:Toggle()
  if self:IsOpen() then self:Close() else self:Open() end
end
function I:OnHidden()
  I.Schedule()
  for _, s in ipairs(secure) do if not InCombat() then s:Hide() end end
  if InCombat() then self.securePending = true end
  win.search:ClearFocus()
  if GameTooltip:GetOwner() and GameTooltip:GetOwner().bag then GameTooltip:Hide() end
end
function I:Sort()
  if PlaySound and SOUNDKIT and SOUNDKIT.UI_BAG_SORTING_01 then PlaySound(SOUNDKIT.UI_BAG_SORTING_01) end
  Call(C_Container and C_Container.SortBags)
end
function I:Focus(bag)
  if PetSkillScoutDB then PetSkillScoutDB.bagFocus = bag end
  self:Paint()
end
function I:CycleBag(step)
  local list = {false}
  for _, bag in ipairs(BAGS) do if NumSlots(bag) > 0 then list[#list + 1] = bag end end
  local cur = DB().bagFocus or false
  local k = 1
  for i, v in ipairs(list) do if v == cur then k = i end end
  k = (k - 1 + step) % #list + 1
  self:Focus(list[k] or nil)
end

-- Gamepad navigation ------------------------------------------------------------
-- Selection index: 1..count over the item grid.
-- Rows: 1 = Clean Up / close, 2 = bags, then the item grid. self.top is
-- the top row (1 or 2) while the selection is up there, else nil.
function I:TopRow(r)
  if r == 1 then return {win.sort, win.close} end
  local list = {}
  for _, b in ipairs(bagBtns) do if b:IsShown() then list[#list + 1] = b end end
  return list
end
function I:Selected()
  if self.top then
    local row = self:TopRow(self.top)
    return row[math.min(self.topCol or 1, #row)]
  end
  return cells[self.sel or 1]
end
function I:ShowSel()
  if not (win and win:IsShown()) then return end
  local c = false
  if c and c:IsShown() then
    win.sel:ClearAllPoints(); win.sel:SetPoint("TOPLEFT", c, -2, 2); win.sel:SetPoint("BOTTOMRIGHT", c, 2, -2)
    EdgeColor(win.sel.edge, Col("accent", {0.85, 0.7, 0.43, 1}), 1)
    win.sel:Show()
    if self.top then
      -- The tooltip of the button left behind closes first (it stayed up
      -- when moving from a bag to Clean Up, which has no tooltip).
      GameTooltip:Hide()
      local fn = c:GetScript("OnEnter"); if fn then pcall(fn, c) end
    else
      self:Tip(secure[self.sel] or c, c)
    end
  else
    win.sel:Hide()
  end
end
function I:Move(dx, dy)
  local n = self.count or 0
  if self.top then
    if dx ~= 0 then
      local row = self:TopRow(self.top)
      self.topCol = ((self.topCol or 1) - 1 + dx) % math.max(1, #row) + 1
    elseif dy < 0 then
      if self.top == 2 then self.top = 1; self.topCol = 1 end
    elseif dy > 0 then
      if self.top == 1 then self.top = 2; self.topCol = 1
      elseif n > 0 then self.top = nil; self.sel = 1 end
    end
  else
    if n == 0 then self.top = 2; self.topCol = 1
    else
      local i = self.sel or 1
      local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
      if dy < 0 and row == 0 then
        self.top = 2; self.topCol = math.max(1, math.min(#self:TopRow(2), math.floor(col / COLS * #self:TopRow(2)) + 1))
      else
        col = (col + dx) % COLS
        row = row + dy
        local rows = math.ceil(n / COLS)
        if row >= rows then row = rows - 1 end
        i = row * COLS + col + 1
        if i > n then i = n end
        self.sel = i
      end
    end
  end
  self:Bind()
  self:ShowSel()
end
local nav = {}
local function NavButton(key, fn)
  local b = CreateFrame("Button", "PetSkillScoutInvNav" .. key, UIParent)
  b:SetScript("OnClick", fn)
  b:Hide()
  nav[key] = b
  return b
end
NavButton("Up", function() I:Move(0, -1) end)
NavButton("Down", function() I:Move(0, 1) end)
NavButton("Left", function() I:Move(-1, 0) end)
NavButton("Right", function() I:Move(1, 0) end)
NavButton("Sort", function() I:Sort() end)
-- B closes ours and the window it was opened with (auction, merchant...),
-- through each window's own close function.
local CLOSERS = {BankFrame = "CloseBankFrame", MerchantFrame = "CloseMerchant", MailFrame = "CloseMail",
  TradeFrame = "CloseTrade", GuildBankFrame = "CloseGuildBankFrame", AuctionFrame = "CloseAuctionHouse"}
NavButton("Close", function()
  local pf = I.Partner and I.Partner()
  I:Close()
  if not pf then return end
  local n = pf:GetName()
  if n == "AuctionHouseFrame" then
    if C_AuctionHouse and C_AuctionHouse.CloseAuctionHouse then pcall(C_AuctionHouse.CloseAuctionHouse) end
  elseif CLOSERS[n] and _G[CLOSERS[n]] then
    pcall(_G[CLOSERS[n]])
  end
end)
NavButton("Prev", function() I:CycleBag(-1) end)
NavButton("Next", function() I:CycleBag(1) end)
-- Select (PADBACK, GAMEPAD_MENU_LEFT): like the game's own "toggle UI
-- focus", the pad goes back to the character while the window stays open,
-- and Select again gives it back to the window.
-- LT / RT: jump between our window and the bank (the bank is the game's
-- window, its own gamepad navigation takes over while ours lets go).
NavButton("Swap", function()
  if not (I.Partner and I.Partner()) then return end
  I.unfocused = not I.unfocused
  I:Bind(); I:ShowSel()
  GameTooltip:Hide()
  -- No call into the game's focus manager (addon calls there can taint it):
  -- with our keys let go, the bank is the game's only open window and its
  -- navigation already has it.
end)
NavButton("Focus", function()
  I.unfocused = not I.unfocused
  I:Bind(); I:ShowSel()
  if I.unfocused then GameTooltip:Hide() end
end)
-- Gamepad: the game's own navigation ---------------------------------------------
-- Done the way BetterBags does it on WoW: Forever (integrations/gamepad.lua,
-- MIT): the window joins the game's list of open gamepad windows
-- (GamepadMode.FrameControlsManager:FrameShown) a frame after it opens, and
-- leaves it as it closes and before combat. The game's D-pad cursor
-- (SmartNavigation) then moves over our buttons, A presses the selected one
-- (a left click: an item is picked up / put down), B calls our
-- SmartNavigationCloseHandler, LT / RT jump to the window beside (bank,
-- merchant...), Select hands the pad back to the character - all the game's.
-- X uses the selected item through one secure button (type2 "click",
-- clickbutton2 = the item's secure button), bound out of combat only.
-- No C_Timer from hooks on the game's bag code (it taints the game's gamepad
-- UI): a driver frame runs the work on the next frame.
local function available()
  return GamepadMode and GamepadMode.FrameControlsManager and SmartNavigation and InputUtil
    and InputUtil.IsGamepadUIEnabled and SmartNavigation_MarkFrameIgnored and true or false
end
local function restricted()
  return C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive and Enum.AddOnRestrictionType
    and C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Combat) or false
end
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(f) f:Hide(); pcall(I.Update, I) end)
I.Schedule = function() driver:Show() end

local use = CreateFrame("Button", "PetSkillScoutInvUse", UIParent, "SecureActionButtonTemplate")
use:SetAttribute("type2", "click")
-- SecureActionButton_OnClick acts on the down or the up press by
-- "useOnKeyDown" (else the ActionButtonUseKeyDown setting): X acts on its
-- down press, and the item button it clicks (Click(), no down flag) on the
-- "up" path - set explicitly, so the setting cannot make either a no-op.
use:RegisterForClicks("AnyDown", "AnyUp")
use:SetAttribute("useOnKeyDown", true)
use:SetScript("PreClick", function(self, button) I.lastX = date("%H:%M:%S") .. " " .. tostring(button) end)

-- Buttons the cursor may land on: items, the bag row, Clean Up, close.
local function Navigable(f) return f.pssNav ~= nil end
local marked = setmetatable({}, {__mode = "k"})
local function MarkControls(root)
  for _, child in ipairs({root:GetChildren()}) do
    local focusable = child:IsObjectType("Button") or child:IsObjectType("EditBox")
    if not marked[child] and not Navigable(child) and focusable then
      SmartNavigation_MarkFrameIgnored(child, true); marked[child] = true
    end
    MarkControls(child)
  end
end

function I:Glow(on)
  if not (win and win.glow) then return end
  if on then EdgeColor(win.glow.edge, Col("accent", {0.85, 0.7, 0.43, 1}), 0.9); win.glow:Show() else win.glow:Hide() end
end

-- Y on an item: "more actions", like the game's own bag (ContainerFrame.lua,
-- ContainerFrameCombinedBagsMixin:SetupGamepad itemMoreActions): feed to the
-- pet (hunters), split the stack, link in chat, destroy. A menu of the game
-- (MenuUtil.CreateContextMenu), which its gamepad navigation already drives.
local MORE = {
  en = {"Feed to pet", "Split stack", "Link in chat", "Destroy"},
  uk = {"Нагодувати пета", "Розділити стос", "Посилання в чат", "Знищити"},
  ru = {"Покормить питомца", "Разделить стопку", "Ссылка в чат", "Уничтожить"},
  pl = {"Nakarm zwierzaka", "Podziel stos", "Link na czacie", "Zniszcz"},
  de = {"Tier füttern", "Stapel teilen", "Im Chat verlinken", "Zerstören"},
  fr = {"Nourrir le familier", "Diviser la pile", "Lien dans le chat", "Détruire"},
  it = {"Nutri il famiglio", "Dividi la pila", "Link in chat", "Distruggi"},
  es = {"Alimentar a la mascota", "Dividir montón", "Enlazar en el chat", "Destruir"},
  pt = {"Alimentar ajudante", "Dividir pilha", "Link no chat", "Destruir"},
}
function I:MoreMenu(btn)
  if not (btn and btn.bag and MenuUtil and MenuUtil.CreateContextMenu) then return end
  local bag, slot = btn.bag, btn.slot
  local info = Call(C_Container.GetContainerItemInfo, bag, slot)
  if type(info) ~= "table" then return end
  local L = MORE[DB().language or "en"] or MORE.en
  local id, count, link = Plain(info.itemID), Plain(info.stackCount) or 1, Plain(info.hyperlink)
  MenuUtil.CreateContextMenu(btn, function(_, root)
    if link then root:CreateTitle(link) end
    local _, cls = UnitClass("player")
    if cls == "HUNTER" and UnitExists("pet") and id and C_PetInfo and C_PetInfo.CanPetEatItem
        and Plain(Call(C_PetInfo.CanPetEatItem, id)) then
      root:CreateButton(L[1], function()
        ClearCursor(); Call(C_Container.PickupContainerItem, bag, slot)
        if CursorHasItem() and C_Item and C_Item.DropItemOnUnit then pcall(C_Item.DropItemOnUnit, "pet") end
        ClearCursor()
      end)
    end
    if count > 1 and not Plain(info.isLocked) and StackSplitFrame then
      root:CreateButton(L[2], function()
        btn.SplitStack = function(_, n) Call(C_Container.SplitContainerItem, bag, slot, n) end
        pcall(StackSplitFrame.OpenStackSplitFrame, StackSplitFrame, count, btn, "BOTTOMRIGHT", "TOPRIGHT")
      end)
    end
    if link then
      root:CreateButton(L[3], function()
        if ChatFrameUtil and ChatFrameUtil.InsertLink then ChatFrameUtil.InsertLink(link)
        elseif ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        if ChatFrame1EditBox and not ChatFrame1EditBox:IsShown() and ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
      end)
    end
    root:CreateButton("|cffff6060" .. L[4] .. "|r", function()
      ClearCursor(); Call(C_Container.PickupContainerItem, bag, slot)
      if CursorHasItem() then
        local name = Plain(Call(C_Item.GetItemNameByID, id)) or link or ""
        StaticPopup_Show("DELETE_ITEM", name)
      end
    end)
  end)
end
local menuBtn = CreateFrame("Button", "PetSkillScoutInvMenu", UIParent)
menuBtn:SetScript("OnClick", function()
  local b = I.bound
  if b then I:MoreMenu(b) end
end)

function I:Retarget()
  if InCombat() or self.combat then return end
  -- On whatever of ours the game's cursor is on ("focused" alone not required).
  local b = self.registered and SmartNavigation:GetCurrentButton()
  self.lastRetarget = date("%H:%M:%S") .. " cur=" .. tostring(b and b.GetName and b:GetName())
    .. " nav=" .. tostring(b and b.pssNav) .. " reg=" .. tostring(self.registered)
  if b and b.pssNav == "item" and b:IsShown() then
    use:SetAttribute("clickbutton2", b)
    SetOverrideBindingClick(use, true, GAMEPAD_FACE_LEFT or "PAD3", use:GetName(), "RightButton")
    SetOverrideBindingClick(use, true, GAMEPAD_FACE_TOP or "PAD4", "PetSkillScoutInvMenu", "LeftButton")
    self.lastRetarget = self.lastRetarget .. " -> X=" .. tostring(GetBindingAction(GAMEPAD_FACE_LEFT or "PAD3", true))
    self.bound = b
  elseif self.bound then
    ClearOverrideBindings(use); self.bound = nil
  end
end

function I:Diag()
  local shown = 0
  for _, b in ipairs(secure) do if b:IsShown() then shown = shown + 1 end end
  local cur = SmartNavigation and SmartNavigation.GetCurrentButton and SmartNavigation:GetCurrentButton()
  local x = GetBindingAction and GetBindingAction(GAMEPAD_FACE_LEFT or "PAD3", true)
  local cb = use:GetAttribute("clickbutton2")
  return string.format("secure %d shown %d | reg %s focus %s combat %s | cur %s nav %s | bound %s | X=%s | cb %s item %s type2 %s",
    #secure, shown, tostring(self.registered), tostring(self.focused), tostring(self.combat),
    tostring(cur and cur.GetName and cur:GetName()), tostring(cur and cur.pssNav), tostring(self.bound and self.bound:GetName()),
    tostring(x), tostring(cb and cb.GetName and cb:GetName()), tostring(cb and cb:GetAttribute("macrotext2")),
    tostring(cb and cb:GetAttribute("type2"))) .. " | last move: " .. tostring(self.lastRetarget) .. " | last X: " .. tostring(self.lastX)
end
function I:Update()
  -- Partner windows (bank, merchant, auction, mail, trade, guild bank).
  if self.partnerOpened then
    self.partnerOpened = nil
    local pf = self.Partner and self.Partner()
    if pf and self:Enabled() then
      self:CloseGameBags()
      self.withPartner = true
      self:Open()
      if win and not InCombat() then
        win:ClearAllPoints(); win:SetPoint("TOPLEFT", pf, "TOPRIGHT", 12, 0)
        self.byPartner = true
        self:PlaceSecure()
      end
    end
  end
  if self.partnerClosed then
    self.partnerClosed = nil
    if self.withPartner and not (self.Partner and self.Partner()) then self:Close() end
  end
  self:HandleGameBags()
  if not available() or not win then return end
  local M = GamepadMode.FrameControlsManager
  local open = I:IsOpen() and Pad()
  if open then
    if restricted() or InCombat() or self.combat then return end
    if not win.pssNavSetup then
      win.pssNavSetup = true
      win.SmartNavigationCloseHandler = function()
        if CursorHasItem() then ClearCursor(); return true end
        local nb = G("PetSkillScoutInvNavClose"); if nb then nb:Click() else I:Close() end
        return true
      end
      win.FocusGamepad = function() I.focused = true; I:Glow(true); I:Retarget() end
      win.UnfocusGamepad = function() I.focused = false; I:Glow(false); I:Retarget() end
      SmartNavigation:RegisterCallback("SelectedButtonUpdated", function() I:Retarget() end, I)
    end
    for _, b in ipairs({win.sort, win.close}) do b.pssNav = "button" end
    for _, b in ipairs(bagBtns) do b.pssNav = "bag" end
    MarkControls(win)
    if not self.registered then
      self.registered = true
      M:FrameShown(win)
    elseif self.dirty then
      SmartNavigation:RefreshButtonGroups(win)
    end
    self.dirty = nil
  elseif self.registered and not restricted() then
    self.registered = false; self.focused = false
    M:FrameHidden(win)
    self:Glow(false)
  end
  self:Retarget()
end

-- Before combat the window leaves the game's list (the game refuses an
-- addon's calls to its gamepad UI under the combat restriction).
function I:LeaveForCombat()
  self.combat = true
  if self.bound then ClearOverrideBindings(use); self.bound = nil end
  if self.registered and available() and not restricted() then
    self.registered = false; self.focused = false
    GamepadMode.FrameControlsManager:FrameHidden(win)
    self:Glow(false)
  end
end

-- Old entry points kept as no-ops for callers.
function I:Bind() I.Schedule() end
I.ApplyKeys = function() end

-- Replacing the game's bag windows ------------------------------------------------
-- Your bags only (backpack and bags 1-4), not the bank's.
-- The game's bag windows are never closed from here (that ran the game's
-- gamepad code from ours and got PetSkillScout blocked:
-- SetPreferredGamepadInteractTarget). Like BetterBags (core/init.lua
-- HideBlizzardBags) they are moved once under a hidden frame: they still
-- open and close by the game's own code, just unseen, and ours follows the
-- game's bag functions (hooksecurefunc ToggleAllBags...).
function I:CloseGameBags() end
local hiddenParent
function I:HideGameBags()
  if InCombat() or self.gameBagsHidden or not self:Enabled() then return end
  hiddenParent = hiddenParent or CreateFrame("Frame", "PetSkillScoutHiddenBags")
  hiddenParent:Hide()
  local cb = G("ContainerFrameCombinedBags")
  if cb then cb:SetParent(hiddenParent) end
  for i = 1, 13 do local f = G("ContainerFrame" .. i); if f then f:SetParent(hiddenParent) end end
  self.gameBagsHidden = true
end
-- Windows the game opens your bags with: our inventory opens next to them,
-- closes with them, and LT / RT jump between them and ours.
local PARTNERS = {
  {frame = "BankFrame", open = "BANKFRAME_OPENED", close = "BANKFRAME_CLOSED"},
  {frame = "MerchantFrame", open = "MERCHANT_SHOW", close = "MERCHANT_CLOSED"},
  {frame = "AuctionHouseFrame", open = "AUCTION_HOUSE_SHOW", close = "AUCTION_HOUSE_CLOSED"},
  {frame = "AuctionFrame", open = "AUCTION_HOUSE_SHOW", close = "AUCTION_HOUSE_CLOSED"},
  {frame = "MailFrame", open = "MAIL_SHOW", close = "MAIL_CLOSED"},
  {frame = "TradeFrame", open = "TRADE_SHOW", close = "TRADE_CLOSED"},
  {frame = "GuildBankFrame", open = "GUILDBANKFRAME_OPENED", close = "GUILDBANKFRAME_CLOSED"},
}
-- Each partner window tells us itself when it goes away (Esc, the close
-- button, walking off): the close events do not always come, or come while
-- the window is still shown. The work runs on the next frame (driver).
local hookedPartner = {}
local function HookPartners()
  for _, p in ipairs(PARTNERS) do
    local f = G(p.frame)
    if f and not hookedPartner[f] and f.HookScript then
      hookedPartner[f] = true
      f:HookScript("OnHide", function() I.partnerClosed = true; I.Schedule() end)
    end
  end
end
local function Partner()
  HookPartners()
  for _, p in ipairs(PARTNERS) do
    local f = G(p.frame)
    if f and f:IsShown() then return f end
  end
end
I.Partner = Partner
local BankOpen = function() return Partner() ~= nil end
local function Want(what)
  if not I:Enabled() then return end
  I.want = what
  I.Schedule()
end
function I:HandleGameBags()
  local w = self.want
  if not w then return end
  self.want = nil
  if w == "toggle" then self:Toggle()
  elseif w == "open" then if not self:IsOpen() then self:Open() end
  elseif w == "close" then if self:IsOpen() and not self.withPartner then self:Close() end end
end
local hookedFns
local function HookGame()
  I:HideGameBags()
  if hookedFns then return end
  hookedFns = true
  for _, fn in ipairs({"ToggleAllBags", "ToggleBackpack", "ToggleBackpack_Combined"}) do
    if type(_G[fn]) == "function" then hooksecurefunc(fn, function() Want("toggle") end) end
  end
  for _, fn in ipairs({"OpenAllBags", "OpenBackpack"}) do
    if type(_G[fn]) == "function" then hooksecurefunc(fn, function() Want("open") end) end
  end
  if type(CloseAllBags) == "function" then hooksecurefunc("CloseAllBags", function() Want("close") end) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "ITEM_LOCK_CHANGED",
    "PLAYER_MONEY", "INVENTORY_SEARCH_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_PET",
    "BAG_CONTAINER_UPDATE"}) do
  pcall(ev.RegisterEvent, ev, e)
end
local openEv, closeEv = {}, {}
for _, p in ipairs(PARTNERS) do
  openEv[p.open], closeEv[p.close] = true, true
  pcall(ev.RegisterEvent, ev, p.open); pcall(ev.RegisterEvent, ev, p.close)
end
ev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_ENTERING_WORLD" then
    HookGame()
    if not InCombat() and I:Enabled() then MakeSecure() end
    return
  end
  if openEv[e] then
    HookPartners()
    I.partnerOpened = true; I.Schedule()
    return
  elseif closeEv[e] then
    I.partnerClosed = true; I.Schedule()
    return
  end
  if e == "PLAYER_REGEN_DISABLED" then
    I:LeaveForCombat()
    if I:IsOpen() then I:Paint() end
    return
  end
  if e == "PLAYER_REGEN_ENABLED" then
    if I:Enabled() then MakeSecure() end
    I.combat = nil
    I:HideGameBags()
    if I.closed and win then win:EnableMouse(false); MuteChildren(win, true) end
    if I:IsOpen() and win then MuteChildren(win, false) end
    if I:IsOpen() then I:Refresh() elseif I.securePending then I:PlaceSecure() end
    I.Schedule()
    return
  end
  if I:IsOpen() then
    if e == "BAG_UPDATE_DELAYED" or e == "BAG_CONTAINER_UPDATE" then I:Refresh(); I.dirty = true; I.Schedule()
    else PSS:Soon("inv paint", function() if I:IsOpen() then I:Paint() end end, 0.1) end
  end
end)

-- Texts for the option (Settings > gear section).
for lang, t in pairs({
  en = {"Own inventory window", "PetSkillScout's own bags in the theme, with gamepad navigation; replaces the game's bag windows"},
  uk = {"Власне вікно інвентарю", "Сумки PetSkillScout у темі аддону, з навігацією геймпадом; замінює вікна сумок гри"},
  pl = {"Własne okno ekwipunku", "Torby PetSkillScout w motywie, z nawigacją padem; zastępuje okna toreb gry"},
  de = {"Eigenes Inventarfenster", "PetSkillScouts Taschen im Design, mit Gamepad-Navigation; ersetzt die Taschenfenster des Spiels"},
  fr = {"Fenêtre d'inventaire propre", "Les sacs de PetSkillScout au thème, navigation à la manette ; remplace les sacs du jeu"},
  it = {"Finestra inventario propria", "Le borse di PetSkillScout a tema, con navigazione col gamepad; sostituisce quelle del gioco"},
  es = {"Ventana de inventario propia", "Las bolsas de PetSkillScout con el tema y navegación con mando; reemplaza las del juego"},
  pt = {"Janela de inventário própria", "As bolsas do PetSkillScout no tema, com navegação por controle; substitui as do jogo"},
  ru = {"Собственное окно инвентаря", "Сумки PetSkillScout в теме аддона, с навигацией геймпадом; заменяет окна сумок игры"},
}) do
  PSS.Locale[lang] = PSS.Locale[lang] or {}
  PSS.Locale[lang].optOwnBags, PSS.Locale[lang].optOwnBagsHint = t[1], t[2]
end
