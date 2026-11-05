-- Game interface skin (optional, off by default), in the spirit of ElvUI:
-- the Blizzard art of windows, tooltips, chat, minimap, unit frames and
-- (separate toggle) action bars is faded out and replaced with flat panels
-- in the addon theme colours: dark fill, 1 px border, cropped icons, flat
-- status bars and a square minimap.
-- Safety: nothing is moved, resized or hidden with Hide(); Blizzard art only
-- gets alpha 0 and new textures are drawn behind. Secure frames (action
-- buttons, unit frames) are only touched out of combat. Every change is
-- remembered and undone when the toggle is turned off or the Classic theme
-- is picked, without /reload.
local PSS = PetSkillScout
PSS.Skin = {}
local S = PSS.Skin

local FLAT = "Interface\\Buttons\\WHITE8X8"
local MINIMAP_MASK = "Textures\\MinimapMask"

-- UI replacement addons that skin everything themselves.
local FULL_UI = {"ElvUI", "Tukui", "KkthnxUI", "NDui", "GW2_UI", "SpartanUI", "SuperVillain", "LUI", "RealUI"}
local BAR_UI = {"Bartender4", "Dominos"}

local hidden = setmetatable({}, {__mode = "k"})   -- region -> original alpha
local hookedAlpha = setmetatable({}, {__mode = "k"})
local hookedShow = setmetatable({}, {__mode = "k"})
local backdrops = setmetatable({}, {__mode = "k"}) -- frame -> {bg, t, b, l, r, kind}
local crops = setmetatable({}, {__mode = "k"})     -- icon texture -> true
local bars = setmetatable({}, {__mode = "k"})      -- statusbar -> original texture
local busy = false
local col = {}
S.active, S.bars = false, false

local function Loaded(name)
  local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
  if not f then return false end
  local ok, r = pcall(f, name)
  return ok and r and true or false
end

function S:Conflict(list)
  for _, n in ipairs(list or FULL_UI) do if Loaded(n) then return n end end
end

-- Field that is a widget table (missing keys and methods are ignored).
local function F(t, k)
  local v = type(t) == "table" and t[k]
  return type(v) == "table" and v or nil
end

local function Theme() return PSS.UI and PSS.UI.ThemeKey and PSS.UI.ThemeKey() or "journal" end

function S:Wanted()
  local db = PetSkillScoutDB
  return db and db.skinGame == true and Theme() ~= "blizzard" and not self:Conflict() and true or false
end

function S:BarsWanted()
  return self:Wanted() and PetSkillScoutDB.skinBars ~= false and not self:Conflict(BAR_UI) and true or false
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

local function Protected(f)
  if not (f and f.IsProtected) then return false end
  local ok, p = pcall(f.IsProtected, f)
  return ok and p and true or false
end

local function Mix(a, b, t) return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t} end

local function UpdateColours()
  local p = PSS.UI and PSS.UI.Palette and PSS.UI:Palette()
  if not p then return end
  col.window = {p.background[1], p.background[2], p.background[3], 0.94}
  col.inset = {p.surface[1], p.surface[2], p.surface[3], 0.92}
  col.tip = {p.deep[1], p.deep[2], p.deep[3], 0.95}
  col.chat = {p.deep[1], p.deep[2], p.deep[3], 0.55}
  col.panel = {p.deep[1], p.deep[2], p.deep[3], 0.80}
  col.input = {p.surfaceAlt[1], p.surfaceAlt[2], p.surfaceAlt[3], 0.40}
  col.button = {p.surfaceAlt[1], p.surfaceAlt[2], p.surfaceAlt[3], 0.95}
  col.slot = {0, 0, 0, 0.75}
  local edge = Mix(p.border, p.gold, 0.35)
  col.edge = {edge[1], edge[2], edge[3], 1}
  col.accent = {p.gold[1], p.gold[2], p.gold[3], 1}
end
S.colours = col
S.UpdateColours = UpdateColours

-- Fading Blizzard art --------------------------------------------------------
-- Blizzard fades some pieces back in (chat tabs, button art); any alpha set
-- while the skin is on is turned back to 0.
local function OnAlpha(region, a)
  if busy or not S.active or hidden[region] == nil then return end
  if a ~= 0 then busy = true; pcall(region.SetAlpha, region, 0); busy = false end
end

local function Fade(region)
  if type(region) ~= "table" or not region.SetAlpha then return end
  if hidden[region] == nil then
    local a = 1
    if region.GetAlpha then
      local ok, v = pcall(region.GetAlpha, region)
      if ok and type(v) == "number" and not (PSS.IsSecret and PSS.IsSecret(v)) then a = v end
    end
    hidden[region] = a
  end
  if not hookedAlpha[region] and hooksecurefunc then
    hookedAlpha[region] = true
    pcall(PSS.HookSecure, region, "SetAlpha", OnAlpha)
  end
  busy = true; pcall(region.SetAlpha, region, 0); busy = false
end
S.Fade = Fade

local function Unfade()
  busy = true
  for region, a in pairs(hidden) do pcall(region.SetAlpha, region, a) end
  busy = false
  for region in pairs(hidden) do hidden[region] = nil end
end

local function IsTexture(r)
  return type(r) == "table" and r.GetObjectType and r:GetObjectType() == "Texture" or false
end

local function Regions(frame)
  if not (frame and frame.GetRegions) then return {} end
  local out = {pcall(frame.GetRegions, frame)}
  if not table.remove(out, 1) then return {} end
  return out
end

local function Children(frame)
  if not (frame and frame.GetChildren) then return {} end
  local out = {pcall(frame.GetChildren, frame)}
  if not table.remove(out, 1) then return {} end
  return out
end

local function Layer(tex)
  if not tex.GetDrawLayer then return nil end
  local ok, l = pcall(tex.GetDrawLayer, tex)
  return ok and l or nil
end

local function Size(r)
  local ok, w, h = pcall(function() return r:GetWidth(), r:GetHeight() end)
  if ok and type(w) == "number" and type(h) == "number" then return w, h end
  return 0, 0
end

-- Flat panels -------------------------------------------------------------
local function NewTex(frame, layer, sub)
  local t = frame:CreateTexture(nil, layer, nil, sub)
  if t.SetColorTexture then t:SetColorTexture(1, 1, 1, 1) else t:SetTexture(FLAT) end
  return t
end

-- inset = {left, top, right, bottom} offsets from the frame edges (classic
-- art has transparent margins); kind = colour key of the fill.
function S:Backdrop(frame, kind, inset, edgeLayer)
  if type(frame) ~= "table" or not frame.CreateTexture then return end
  local bd = backdrops[frame]
  if not bd then
    bd = {bg = NewTex(frame, "BACKGROUND", -8)}
    local el = edgeLayer or "BORDER"
    bd.t, bd.b, bd.l, bd.r = NewTex(frame, el, 7), NewTex(frame, el, 7), NewTex(frame, el, 7), NewTex(frame, el, 7)
    backdrops[frame] = bd
  end
  bd.kind = kind or "window"
  local L, T, R, B = 0, 0, 0, 0
  if inset then L, T, R, B = inset[1], inset[2], inset[3], inset[4] end
  bd.bg:ClearAllPoints()
  bd.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", L, T)
  bd.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", R, B)
  local bg = bd.bg
  bd.t:ClearAllPoints(); bd.t:SetPoint("TOPLEFT", bg, "TOPLEFT"); bd.t:SetPoint("TOPRIGHT", bg, "TOPRIGHT"); bd.t:SetHeight(1)
  bd.b:ClearAllPoints(); bd.b:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT"); bd.b:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT"); bd.b:SetHeight(1)
  bd.l:ClearAllPoints(); bd.l:SetPoint("TOPLEFT", bg, "TOPLEFT"); bd.l:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT"); bd.l:SetWidth(1)
  bd.r:ClearAllPoints(); bd.r:SetPoint("TOPRIGHT", bg, "TOPRIGHT"); bd.r:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT"); bd.r:SetWidth(1)
  local c, e = col[bd.kind] or col.window, col.edge
  bd.bg:SetVertexColor(c[1], c[2], c[3], c[4])
  for _, k in ipairs({"t", "b", "l", "r"}) do bd[k]:SetVertexColor(e[1], e[2], e[3], e[4]); bd[k]:Show() end
  bd.bg:Show()
  return bd
end

local function HideBackdrops()
  for _, bd in pairs(backdrops) do
    for _, k in ipairs({"bg", "t", "b", "l", "r"}) do pcall(bd[k].Hide, bd[k]) end
  end
end

-- Icon crop (removes the stock icon border, ElvUI style).
local function Crop(icon)
  if not IsTexture(icon) or not icon.SetTexCoord then return end
  crops[icon] = true
  pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
end

local function Uncrop()
  for icon in pairs(crops) do pcall(icon.SetTexCoord, icon, 0, 1, 0, 1); crops[icon] = nil end
end

-- Flat status bar texture.
local function FlatBar(bar)
  if type(bar) ~= "table" or not bar.SetStatusBarTexture then return end
  if bars[bar] == nil then
    local old = false
    local ok, tex = pcall(bar.GetStatusBarTexture, bar)
    if ok and type(tex) == "table" and tex.GetTexture then
      local ok2, file = pcall(tex.GetTexture, tex)
      if ok2 and file then old = file end
    end
    bars[bar] = old
  end
  pcall(bar.SetStatusBarTexture, bar, FLAT)
end

local function UnflatBars()
  for bar, old in pairs(bars) do
    if old then pcall(bar.SetStatusBarTexture, bar, old) end
    bars[bar] = nil
  end
end

-- Windows --------------------------------------------------------------------
local function G(name) local v = _G[name]; return type(v) == "table" and v or nil end

-- Icons stay; portraits are faded like the rest of the art (ElvUI look).
local function SkipSet(frame)
  local s = {}
  for _, k in ipairs({"icon", "Icon", "IconTexture"}) do
    if type(F(frame, k)) == "table" then s[F(frame, k)] = true end
  end
  local name = frame.GetName and frame:GetName()
  if type(name) == "string" and type(_G[name .. "Icon"]) == "table" then s[_G[name .. "Icon"]] = true end
  for _, k in ipairs({"portrait", "Portrait", "PortraitFrame", "PortraitContainer"}) do
    if type(F(frame, k)) == "table" then Fade(F(frame, k)) end
  end
  if type(name) == "string" then
    for _, k in ipairs({"Portrait", "PortraitFrame"}) do
      if type(_G[name .. k]) == "table" then Fade(_G[name .. k]) end
    end
  end
  return s
end

-- Classic 384x512 panels draw their art with transparent margins.
local CLASSIC_INSETS = {
  default = {11, -12, -32, 76},
  ContainerFrame = {8, -4, -4, 2},
  WorldMapFrame = {0, 0, 0, 0},
  LootFrame = {12, -12, -66, 6},
  GameMenuFrame = {0, 0, 0, 0},
  StaticPopup = {0, 0, 0, 0},
}

local function InsetFor(frame, name)
  if F(frame, "NineSlice") then return {0, 0, 0, 0} end
  if type(name) == "string" then
    for prefix, v in pairs(CLASSIC_INSETS) do
      if prefix ~= "default" and name:sub(1, #prefix) == prefix then return v end
    end
  end
  local w, h = Size(frame)
  if w >= 330 and w <= 400 and h >= 420 then return CLASSIC_INSETS.default end
  return {0, 0, 0, 0}
end

-- Buttons made of Left/Middle/Right art (UIPanelButtonTemplate and tabs).
local function SkinTextButton(b)
  if type(b) ~= "table" then return end
  local name = b.GetName and b:GetName()
  local found = false
  for _, k in ipairs({"Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled",
    "LeftActive", "MiddleActive", "RightActive", "LeftHighlight", "MiddleHighlight", "RightHighlight"}) do
    local r = F(b, k) or (name and _G[name .. k])
    if r then Fade(r); found = true end
  end
  if not found then return end
  for _, get in ipairs({"GetNormalTexture", "GetPushedTexture", "GetDisabledTexture"}) do
    if type(b[get]) == "function" then
      local ok, t = pcall(b[get], b)
      if ok and IsTexture(t) then Fade(t) end
    end
  end
  S:Backdrop(b, "button", {1, -1, -1, 1})
end

local function SkinInset(f)
  if type(f) ~= "table" then return end
  if F(f, "NineSlice") then Fade(F(f, "NineSlice")) end
  for _, k in ipairs({"Bg", "Background"}) do if F(f, k) then Fade(F(f, k)) end end
  S:Backdrop(f, "inset")
end

local function WalkChildren(frame, depth)
  if depth > 4 then return end
  for _, c in ipairs(Children(frame)) do
    local t = c.GetObjectType and c:GetObjectType()
    if t == "Button" then
      SkinTextButton(c)
    elseif t == "Frame" then
      local name = c.GetName and c:GetName()
      if c.NineSlice or (type(name) == "string" and name:find("Inset$")) then SkinInset(c) end
    end
    WalkChildren(c, depth + 1)
  end
end

function S:Window(frame)
  if type(frame) ~= "table" or not frame.GetRegions then return end
  if InCombat() and Protected(frame) then return end
  local name = frame.GetName and frame:GetName()
  local skip = SkipSet(frame)
  if F(frame, "NineSlice") then Fade(F(frame, "NineSlice")) end
  if F(frame, "Border") and F(frame, "Border") ~= frame then Fade(F(frame, "Border")) end
  for _, k in ipairs({"Bg", "Background", "TitleBg", "TopTileStreaks", "BackgroundTexture"}) do
    if F(frame, k) then Fade(F(frame, k)) end
  end
  for _, r in ipairs(Regions(frame)) do
    if IsTexture(r) and not skip[r] then
      local layer = Layer(r)
      if layer == "BACKGROUND" or layer == "BORDER" then Fade(r)
      elseif layer == "ARTWORK" then
        local w, h = Size(r)
        if w >= 96 and h >= 48 then Fade(r) end
      end
    end
  end
  if F(frame, "Inset") then SkinInset(F(frame, "Inset")) end
  if name ~= "WorldMapFrame" then WalkChildren(frame, 1) end
  if type(name) == "string" then
    for i = 1, 8 do SkinTextButton(_G[name .. "Tab" .. i]) end
  end
  S:Backdrop(frame, "window", InsetFor(frame, name))
end

local WINDOWS = {
  "CharacterFrame", "SpellBookFrame", "PlayerSpellsFrame", "PlayerTalentFrame", "TalentFrame",
  "ContainerFrameCombinedBags", "BankFrame", "MerchantFrame", "MailFrame", "OpenMailFrame",
  "QuestFrame", "QuestLogFrame", "QuestLogDetailFrame", "GossipFrame", "FriendsFrame",
  "WorldMapFrame", "PVEFrame", "LFGParentFrame", "TradeFrame", "PetStableFrame", "TaxiFrame",
  "ClassTrainerFrame", "CraftFrame", "TradeSkillFrame", "ProfessionsFrame", "AuctionHouseFrame", "AuctionFrame",
  "GuildFrame", "CommunitiesFrame", "InspectFrame", "DressUpFrame", "GameMenuFrame", "LootFrame",
  "CollectionsJournal", "EncounterJournal", "AchievementFrame", "MacroFrame", "HelpFrame", "BattlefieldFrame",
  "PVPFrame", "ItemTextFrame", "TabardFrame", "GuildRegistrarFrame", "PetitionFrame",
  "ReadyCheckFrame", "RaidParentFrame", "ChannelFrame", "AddonList", "SettingsPanel", "TimeManagerFrame",
}
local TOOLTIPS = {"GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip",
  "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "WorldMapTooltip", "FriendsTooltip"}

local function HookShow(frame, fn)
  if type(frame) ~= "table" or hookedShow[frame] or not frame.HookScript then return end
  hookedShow[frame] = true
  pcall(PSS.HookScript, frame, "OnShow", function(f) if S.active then pcall(fn, f) end end)
end

local function WindowNow(f) S:Window(f) end

local function SkinWindows()
  local list = {}
  for _, n in ipairs(WINDOWS) do list[#list + 1] = G(n) end
  for i = 1, 13 do list[#list + 1] = G("ContainerFrame" .. i) end
  for i = 1, 4 do list[#list + 1] = G("StaticPopup" .. i) end
  for _, f in pairs(list) do
    if f then S:Window(f); HookShow(f, WindowNow) end
  end
end

-- Tooltips -------------------------------------------------------------------
local function SkinTooltip(tip)
  if type(tip) ~= "table" then return end
  if F(tip, "NineSlice") then Fade(F(tip, "NineSlice")) end
  for _, r in ipairs(Regions(tip)) do
    if IsTexture(r) then
      local layer = Layer(r)
      if layer == "BACKGROUND" or layer == "BORDER" then Fade(r) end
    end
  end
  S:Backdrop(tip, "tip")
  local sb = F(tip, "StatusBar") or (tip.GetName and tip:GetName() and _G[tip:GetName() .. "StatusBar"])
  if sb then FlatBar(sb) end
end

local function SkinTooltips()
  for _, n in ipairs(TOOLTIPS) do
    local tip = G(n)
    if tip then SkinTooltip(tip); HookShow(tip, SkinTooltip) end
  end
end

-- Chat -----------------------------------------------------------------------
local CHAT_BG = {"Background", "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture",
  "TopTexture", "BottomTexture", "LeftTexture", "RightTexture"}

local function SkinChat()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local p = "ChatFrame" .. i
    local cf = G(p)
    if cf then
      for _, k in ipairs(CHAT_BG) do Fade(G(p .. k)) end
      -- With the chat panel layout the panel itself is the backdrop.
      if PetSkillScoutDB.skinChat == false then S:Backdrop(cf, "chat", {-4, 4, 4, -4}) end
      Fade(G(p .. "ButtonFrameBackground"))
      local eb = G(p .. "EditBox")
      if eb then
        for _, k in ipairs({"Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight"}) do
          Fade(G(p .. "EditBox" .. k)); if F(eb, k) then Fade(F(eb, k)) end
        end
        S:Backdrop(eb, "window", {4, -4, -4, 4})
      end
      local tab = G(p .. "Tab")
      if tab then
        for _, r in ipairs(Regions(tab)) do
          if IsTexture(r) then Fade(r) end
        end
        for _, k in ipairs({"Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight",
          "HighlightLeft", "HighlightMiddle", "HighlightRight", "leftSelectedTexture",
          "middleSelectedTexture", "rightSelectedTexture"}) do
          if F(tab, k) then Fade(F(tab, k)) end
        end
      end
    end
  end
end

-- Minimap: square, flat border ----------------------------------------------
local oldShape, shapeSet = nil, false
local function SkinMinimap()
  local mm = G("Minimap")
  if not mm then return end
  for _, n in ipairs({"MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture", "MinimapBackdrop",
    "MiniMapTrackingBorder", "MiniMapMailBorder", "MinimapZoomInButtonBorder", "GameTimeFrameBorder",
    "MiniMapWorldMapButtonBorder", "MinimapNorthTag"}) do
    Fade(G(n))
  end
  local mc = G("MinimapCluster")
  if mc then
    if F(mc, "BorderTop") then Fade(F(mc, "BorderTop")) end
    if F(mc, "Background") then Fade(F(mc, "Background")) end
  end
  if mm.SetMaskTexture then pcall(mm.SetMaskTexture, mm, FLAT) end
  S:Backdrop(mm, "window", {-1, 1, 1, -1}, "BACKGROUND")
  if not shapeSet then oldShape, shapeSet = _G.GetMinimapShape, true end
  _G.GetMinimapShape = function() return "SQUARE" end
end

local function UnskinMinimap()
  local mm = G("Minimap")
  if mm and mm.SetMaskTexture and shapeSet then pcall(mm.SetMaskTexture, mm, MINIMAP_MASK) end
  if shapeSet then _G.GetMinimapShape = oldShape; shapeSet = false; oldShape = nil end
end

-- Unit frames: art faded, flat bars on a dark panel ------------------------
local UNITS = {
  {"PlayerFrame", {"PlayerFrameTexture", "PlayerFrameBackground"}, "PlayerFrameHealthBar", "PlayerFrameManaBar"},
  {"TargetFrame", {"TargetFrameTextureFrameTexture", "TargetFrameBackground"}, "TargetFrameHealthBar", "TargetFrameManaBar"},
  {"PetFrame", {"PetFrameTexture"}, "PetFrameHealthBar", "PetFrameManaBar"},
  {"TargetFrameToT", {"TargetFrameToTTextureFrameTexture", "TargetFrameToTBackground"}, "TargetFrameToTHealthBar", "TargetFrameToTManaBar"},
  {"FocusFrame", {"FocusFrameTextureFrameTexture", "FocusFrameBackground"}, "FocusFrameHealthBar", "FocusFrameManaBar"},
}

local function SkinUnitFrames()
  for _, u in ipairs(UNITS) do
    local f = G(u[1])
    if f then
      for _, n in ipairs(u[2]) do Fade(G(n)) end
      local hp, mp = G(u[3]), G(u[4])
      FlatBar(hp); FlatBar(mp)
      if hp and mp and hp.CreateTexture then
        -- Panel behind both bars, owned by the health bar.
        local bd = S:Backdrop(hp, "slot", {-1, 1, 1, -1}, "BACKGROUND")
        if bd then
          bd.bg:ClearAllPoints()
          bd.bg:SetPoint("TOPLEFT", hp, "TOPLEFT", -1, 1)
          bd.bg:SetPoint("BOTTOMRIGHT", mp, "BOTTOMRIGHT", 1, -1)
        end
      end
    end
  end
  for _, n in ipairs({"CastingBarFrameBorder", "CastingBarFrameBorderShield"}) do Fade(G(n)) end
  local cb = G("CastingBarFrame")
  if cb then FlatBar(cb); S:Backdrop(cb, "slot", {-1, 1, 1, -1}, "BACKGROUND") end
end

-- Quest / objective tracker: flat theme headers ---------------------------
-- The gold header art goes; each header gets a flat panel, accent text and
-- an accent line underneath. Quest lines keep Blizzard's colours (red =
-- high level), only the header look changes.
local TRACKER_MODULES = {"QuestObjectiveTracker", "CampaignQuestObjectiveTracker", "AchievementObjectiveTracker",
  "BonusObjectiveTracker", "WorldQuestObjectiveTracker", "ScenarioObjectiveTracker", "ProfessionsRecipeTracker",
  "MonthlyActivitiesObjectiveTracker", "AdventureObjectiveTracker", "InitiativeTasksObjectiveTracker"}
local TRACKER_HEADERS = {"QuestHeader", "AchievementHeader", "ScenarioHeader", "CampaignQuestHeader",
  "ProfessionHeader", "MonthlyActivitiesHeader", "BonusObjectiveHeader", "WorldQuestHeader", "UIWidgetsHeader"}

local trackerLines = setmetatable({}, {__mode = "k"})
local function StyleTrackerHeader(h, main)
  if type(h) ~= "table" or not h.GetRegions then return end
  local text = F(h, "Text")
  local minimize = F(h, "MinimizeButton")
  for _, r in ipairs(Regions(h)) do
    if IsTexture(r) and r ~= text then Fade(r) end
  end
  if F(h, "Background") then Fade(F(h, "Background")) end
  S:Backdrop(h, main and "button" or "panel", {0, -2, 0, 2})
  local acc = col.accent or {1, 1, 1, 1}
  if text and text.SetTextColor then pcall(text.SetTextColor, text, acc[1], acc[2], acc[3]) end
  local line = trackerLines[h]
  if not line then
    line = h:CreateTexture(nil, "OVERLAY")
    line:SetTexture(FLAT)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 2)
    line:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 2)
    trackerLines[h] = line
  end
  line:SetVertexColor(acc[1], acc[2], acc[3], 0.8)
  line:Show()
  if minimize then
    -- keep the button, drop its round/gold frame pieces
    for _, k in ipairs({"Border", "Background"}) do if F(minimize, k) then Fade(F(minimize, k)) end end
  end
end

local function SkinTracker()
  local otf = G("ObjectiveTrackerFrame")
  if otf then
    StyleTrackerHeader(F(otf, "Header") or F(otf, "HeaderMenu"), true)
    local blocks = G("ObjectiveTrackerBlocksFrame")
    if blocks then
      for _, k in ipairs(TRACKER_HEADERS) do StyleTrackerHeader(F(blocks, k), false) end
    end
  end
  for _, n in ipairs(TRACKER_MODULES) do
    local m = G(n)
    if m then StyleTrackerHeader(F(m, "Header"), false) end
  end
end

-- Quest blocks: theme fonts for titles and objective lines, accent dashes,
-- and the round yellow POI badges replaced by square theme markers
-- ("?" ready to turn in, "…" in progress; brighter for the tracked quest).
local TRACK_FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
local poiMarks = setmetatable({}, {__mode = "k"})

local function SetTrackFont(fs, size)
  if type(fs) == "table" and fs.SetFont then pcall(fs.SetFont, fs, TRACK_FONT, size, "") end
  if type(fs) == "table" and fs.SetShadowOffset then
    pcall(fs.SetShadowOffset, fs, 1, -1)
    pcall(fs.SetShadowColor, fs, 0, 0, 0, 1)
  end
end

local function QuestDone(q)
  if type(q) ~= "number" then return false end
  local cq = C_QuestLog
  local f = (cq and (cq.ReadyForTurnIn or cq.IsComplete)) or IsQuestComplete
  if not f then return false end
  local ok, r = pcall(f, q)
  return ok and r and true or false
end

local function StylePOI(b, title)
  if type(b) ~= "table" or not b.GetRegions then return end
  for _, r in ipairs(Regions(b)) do if IsTexture(r) then Fade(r) end end
  for _, k in ipairs({"Display", "NormalTexture", "PushedTexture", "HighlightTexture", "Glow"}) do
    local c = F(b, k)
    if c then
      if c.GetRegions then for _, r in ipairs(Regions(c)) do if IsTexture(r) then Fade(r) end end end
      if IsTexture(c) then Fade(c) end
    end
  end
  -- A small filled square, centred on the first line of the quest title.
  local m = poiMarks[b]
  if not m then
    m = CreateFrame("Frame", nil, b)
    m:SetSize(8, 8)
    m:SetFrameLevel((b:GetFrameLevel() or 1) + 2)
    m.fill = m:CreateTexture(nil, "ARTWORK")
    m.fill:SetAllPoints()
    m.fill:SetTexture(FLAT)
    m.ring = {}
    for i = 1, 4 do
      local t = m:CreateTexture(nil, "OVERLAY")
      t:SetTexture(FLAT)
      m.ring[i] = t
    end
    -- 1 px ring two pixels outside the square (tracked quest).
    m.ring[1]:SetPoint("TOPLEFT", m, "TOPLEFT", -3, 3); m.ring[1]:SetPoint("TOPRIGHT", m, "TOPRIGHT", 3, 3); m.ring[1]:SetHeight(1)
    m.ring[2]:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", -3, -3); m.ring[2]:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 3, -3); m.ring[2]:SetHeight(1)
    m.ring[3]:SetPoint("TOPLEFT", m, "TOPLEFT", -3, 3); m.ring[3]:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", -3, -3); m.ring[3]:SetWidth(1)
    m.ring[4]:SetPoint("TOPRIGHT", m, "TOPRIGHT", 3, 3); m.ring[4]:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", 3, -3); m.ring[4]:SetWidth(1)
    poiMarks[b] = m
  end
  m:ClearAllPoints()
  if type(title) == "table" then
    m:SetPoint("TOPRIGHT", title, "TOPLEFT", -7, -5)
  else
    m:SetPoint("CENTER", b, "CENTER", 0, 0)
  end
  local q = rawget(b, "questID")
  local done = QuestDone(q)
  local tracked = false
  if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and type(q) == "number" then
    local ok, t = pcall(C_SuperTrack.GetSuperTrackedQuestID)
    tracked = ok and t == q
  end
  local acc = col.accent or {1, 1, 1, 1}
  if done then
    m.fill:SetVertexColor(1, 0.80, 0.20, 1)
  else
    m.fill:SetVertexColor(acc[1] * 0.75, acc[2] * 0.75, acc[3] * 0.75, 0.9)
  end
  for _, t in ipairs(m.ring) do
    t:SetVertexColor(1, 1, 1, 0.85)
    t:SetShown(tracked and true or false)
  end
  m:Show()
end

local function WalkTracker(frame, depth)
  if type(frame) ~= "table" or depth > 6 or not frame.GetChildren then return end
  local acc = col.accent or {1, 1, 1, 1}
  for _, c in ipairs({frame:GetChildren()}) do
    local title = rawget(c, "HeaderText")
    if type(title) == "table" then SetTrackFont(title, 12) end
    local text, dash = rawget(c, "Text"), rawget(c, "Dash")
    if type(text) == "table" and type(dash) == "table" then
      SetTrackFont(text, 11)
      SetTrackFont(dash, 11)
      if dash.SetTextColor then pcall(dash.SetTextColor, dash, acc[1], acc[2], acc[3]) end
    end
    local poi = rawget(c, "poiButton")
    if type(poi) == "table" then pcall(StylePOI, poi, type(title) == "table" and title or nil) end
    if rawget(c, "questID") ~= nil and c.GetObjectType and c:GetObjectType() == "Button" and c.GetRegions then
      local parentTitle = rawget(frame, "HeaderText")
      pcall(StylePOI, c, type(parentTitle) == "table" and parentTitle or nil)
    end
    WalkTracker(c, depth + 1)
  end
end

local function SkinTrackerBlocks()
  for _, n in ipairs(TRACKER_MODULES) do
    local m = G(n)
    if m then WalkTracker(F(m, "ContentsFrame") or m, 1) end
  end
  WalkTracker(G("ObjectiveTrackerBlocksFrame"), 1)
end

local function HidePOIMarks()
  for _, m in pairs(poiMarks) do pcall(m.Hide, m) end
end

local poiEvents = CreateFrame("Frame")
for _, e in ipairs({"SUPER_TRACKING_CHANGED", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED"}) do
  pcall(poiEvents.RegisterEvent, poiEvents, e)
end
poiEvents:SetScript("OnEvent", function()
  if S.active then PSS:Soon("tracker-poi", function() if S.active then pcall(SkinTrackerBlocks) end end, 0.2) end
end)

local trackerHooked = false
local function HookTracker()
  if trackerHooked or not hooksecurefunc then return end
  trackerHooked = true
  -- Every tracker section calls Update, often several times per frame, and
  -- restyling it marks the tracker for another layout: one pass per burst.
  local function again()
    if not S.active then return end
    PSS:Soon("tracker", function() if S.active then pcall(SkinTracker); pcall(SkinTrackerBlocks) end end, 0.2)
  end
  local otf = G("ObjectiveTrackerFrame")
  if otf then
    for _, m in ipairs({"Update", "Layout"}) do
      if type(otf[m]) == "function" then pcall(PSS.HookSecure, otf, m, again) end
    end
  end
  for _, fn in ipairs({"ObjectiveTracker_Update", "ObjectiveTracker_Expand", "ObjectiveTracker_Collapse"}) do
    if type(_G[fn]) == "function" then PSS.HookSecure(fn, again) end
  end
  for _, n in ipairs(TRACKER_MODULES) do
    local m = G(n)
    if m and type(m.Update) == "function" then pcall(PSS.HookSecure, m, "Update", again) end
  end
end

local function HideTrackerLines()
  for _, line in pairs(trackerLines) do pcall(line.Hide, line) end
end

-- Action bars ----------------------------------------------------------------
local BAR_BUTTONS = {
  {"ActionButton", 12}, {"MultiBarBottomLeftButton", 12}, {"MultiBarBottomRightButton", 12},
  {"MultiBarRightButton", 12}, {"MultiBarLeftButton", 12}, {"MultiBar5Button", 12},
  {"MultiBar6Button", 12}, {"MultiBar7Button", 12}, {"PetActionButton", 10}, {"StanceButton", 10},
  {"ShapeshiftButton", 10}, {"PossessButton", 2}, {"BonusActionButton", 12},
}
local BAR_ART = {
  "MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
  "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "MainMenuMaxLevelBar0", "MainMenuMaxLevelBar1",
  "MainMenuMaxLevelBar2", "MainMenuMaxLevelBar3", "MainMenuXPBarTexture0", "MainMenuXPBarTexture1",
  "MainMenuXPBarTexture2", "MainMenuXPBarTexture3", "ReputationWatchBarTexture0", "ReputationWatchBarTexture1",
  "ReputationWatchBarTexture2", "ReputationWatchBarTexture3", "ReputationXPBarTexture0", "ReputationXPBarTexture1",
  "ReputationXPBarTexture2", "ReputationXPBarTexture3", "SlidingActionBarTexture0", "SlidingActionBarTexture1",
  "ShapeshiftBarLeft", "ShapeshiftBarMiddle", "ShapeshiftBarRight", "PossessBackground1", "PossessBackground2",
  "MainMenuBarPerformanceBarFrame", "MainMenuBarBackpackButtonNormalTexture",
}

local BTN_FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"

local function Fill(region, b, inset)
  if type(region) ~= "table" or not region.ClearAllPoints then return end
  inset = inset or 1
  pcall(region.ClearAllPoints, region)
  pcall(region.SetPoint, region, "TOPLEFT", b, "TOPLEFT", inset, -inset)
  pcall(region.SetPoint, region, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
end

local function Font(fs, size)
  if type(fs) == "table" and fs.SetFont then pcall(fs.SetFont, fs, BTN_FONT, size, "OUTLINE") end
end

-- Key labels: small, top right, short ("CTRL-1" / "c-1" -> "C1").
local SHORT_KEYS = {{"CTRL%-", "C"}, {"SHIFT%-", "S"}, {"ALT%-", "A"}, {"c%-", "C"}, {"s%-", "S"}, {"a%-", "A"},
  {"Mouse Button ", "M"}, {"BUTTON", "M"}, {"Middle Mouse", "M3"}, {"Num Pad ", "N"}, {"NUMPAD", "N"},
  {"Mouse Wheel Up", "WU"}, {"Mouse Wheel Down", "WD"}, {"MOUSEWHEELUP", "WU"}, {"MOUSEWHEELDOWN", "WD"}}
local function StyleHotkey(b)
  if not S.bars then return end
  local name = b.GetName and b:GetName()
  local hk = F(b, "HotKey") or (name and G(name .. "HotKey"))
  if not hk then return end
  -- Text only in combat; font and anchors out of combat.
  if not (InCombatLockdown and InCombatLockdown()) then
    Font(hk, 10)
    pcall(hk.ClearAllPoints, hk)
    pcall(hk.SetPoint, hk, "TOPRIGHT", b, "TOPRIGHT", -2, -2)
    pcall(hk.SetPoint, hk, "TOPLEFT", b, "TOPLEFT", 2, -2)
    if hk.SetJustifyH then pcall(hk.SetJustifyH, hk, "RIGHT") end
  end
  local ok, t = pcall(hk.GetText, hk)
  if ok and type(t) == "string" and not (PSS.IsSecret and PSS.IsSecret(t)) and t ~= "" then
    local short = t
    for _, r in ipairs(SHORT_KEYS) do short = short:gsub(r[1], r[2]) end
    if short ~= t then pcall(hk.SetText, hk, short) end
  end
end
S.StyleHotkey = StyleHotkey

local function SkinActionButton(b)
  if type(b) ~= "table" then return end
  local name = b.GetName and b:GetName()
  if b.GetNormalTexture then
    local ok, nt = pcall(b.GetNormalTexture, b)
    if ok and IsTexture(nt) then Fade(nt) end
  end
  for _, k in ipairs({"SlotBackground", "SlotArt", "FloatingBG", "NormalTexture", "IconMask"}) do
    if F(b, k) then Fade(F(b, k)) end
  end
  if name then
    Fade(G(name .. "FloatingBG")); Fade(G(name .. "NormalTexture")); Fade(G(name .. "NormalTexture2"))
  end
  -- Same size for every icon: no round mask, cropped, 1 px inside the border.
  local icon = F(b, "icon") or F(b, "Icon") or (name and G(name .. "Icon"))
  if icon then
    local mask = F(b, "IconMask")
    if mask and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, mask) end
    Fill(icon, b, 1)
    Crop(icon)
  end
  -- Cooldown, flash, glow and state textures follow the same square.
  for _, k in ipairs({"cooldown", "Cooldown", "Flash", "Border", "NewActionTexture", "SpellHighlightTexture",
    "AutoCastable", "AutoCastShine", "AutoCastOverlay"}) do
    local r = F(b, k) or (name and G(name .. k))
    if r then Fill(r, b, 1) end
  end
  if name then Fill(G(name .. "Cooldown"), b, 1); Fill(G(name .. "Flash"), b, 1) end
  local function flat(getter, setter, r, g, bl, a)
    if type(b[setter]) ~= "function" then return end
    pcall(b[setter], b, FLAT)
    local ok, t = pcall(b[getter], b)
    if ok and IsTexture(t) then
      Fill(t, b, 1)
      pcall(t.SetVertexColor, t, r, g, bl, a)
    end
  end
  local acc = col.accent or {1, 1, 1, 1}
  flat("GetHighlightTexture", "SetHighlightTexture", 1, 1, 1, 0.18)
  flat("GetPushedTexture", "SetPushedTexture", 0, 0, 0, 0.35)
  flat("GetCheckedTexture", "SetCheckedTexture", acc[1], acc[2], acc[3], 0.35)
  -- Texts: count bottom right, macro name bottom, key top right.
  local count = F(b, "Count") or (name and G(name .. "Count"))
  if count then
    Font(count, 11)
    pcall(count.ClearAllPoints, count)
    pcall(count.SetPoint, count, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  end
  local mname = F(b, "Name") or (name and G(name .. "Name"))
  if mname then
    Font(mname, 9)
    pcall(mname.ClearAllPoints, mname)
    pcall(mname.SetPoint, mname, "BOTTOMLEFT", b, "BOTTOMLEFT", 2, 2)
    pcall(mname.SetPoint, mname, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
  end
  StyleHotkey(b)
  if not hookedShow[b] and hooksecurefunc then
    hookedShow[b] = true
    if type(b.UpdateHotkeys) == "function" then pcall(PSS.HookSecure, b, "UpdateHotkeys", StyleHotkey) end
  end
  -- Border on the button edge, fill behind the icon.
  S:Backdrop(b, "slot", {0, 0, 0, 0}, "OVERLAY")
  local bd = backdrops[b]
  if bd and bd.bg.SetDrawLayer then pcall(bd.bg.SetDrawLayer, bd.bg, "BACKGROUND", -8) end
end

local hotkeyHooked = false
local function SkinBars()
  if not hotkeyHooked and type(ActionButton_UpdateHotkeys) == "function" and hooksecurefunc then
    hotkeyHooked = true
    PSS.HookSecure("ActionButton_UpdateHotkeys", function(b) pcall(StyleHotkey, b) end)
  end
  for _, def in ipairs(BAR_BUTTONS) do
    for i = 1, def[2] do SkinActionButton(G(def[1] .. i)) end
  end
  for _, n in ipairs(BAR_ART) do Fade(G(n)) end
  for _, n in ipairs({"MainMenuBar", "MainMenuBarArtFrame", "MainActionBar", "MainMenuBarArtFrameBackground"}) do
    local f = G(n)
    if f then
      for _, k in ipairs({"LeftEndCap", "RightEndCap", "BorderArt", "Background", "BackgroundLarge", "BackgroundSmall"}) do
        if F(f, k) then Fade(F(f, k)) end
      end
      if F(f, "EndCaps") then Fade(F(f, "EndCaps")) end
      if F(f, "ActionBarPageNumber") then Fade(F(f, "ActionBarPageNumber")) end
    end
  end
  for _, n in ipairs({"MainMenuExpBar", "ReputationWatchStatusBar"}) do
    local bar = G(n)
    if bar then FlatBar(bar); S:Backdrop(bar, "slot", {-1, 1, 1, -1}, "BACKGROUND") end
  end
end

-- Public -------------------------------------------------------------------
local pendingCombat = false

local function Clear()
  HideTrackerLines()
  HidePOIMarks()
  Unfade()
  HideBackdrops()
  Uncrop()
  UnflatBars()
  UnskinMinimap()
end

function S:Refresh()
  if InCombat() then pendingCombat = true; return end
  pendingCombat = false
  local db = PetSkillScoutDB
  local clash = db and db.skinGame == true and self:Conflict()
  if clash and self.warned ~= clash then
    self.warned = clash
    PSS:Print(string.format(PSS:L("skinConflict"), clash))
  end
  local want, wantBars = self:Wanted(), self:BarsWanted()
  self.active = false
  Clear()
  self.active, self.bars = want, wantBars
  if not want then return end
  UpdateColours()
  pcall(SkinWindows)
  pcall(SkinTooltips)
  pcall(SkinChat)
  pcall(SkinMinimap)
  pcall(SkinUnitFrames)
  pcall(SkinTracker)
  pcall(SkinTrackerBlocks)
  pcall(HookTracker)
  if wantBars then pcall(SkinBars) end
  if PSS.Layout and PSS.Layout.Restyle then pcall(PSS.Layout.Restyle, PSS.Layout) end
end

-- Number of faded Blizzard pieces (tests).
function S:Count()
  local n = 0
  for _ in pairs(hidden) do n = n + 1 end
  return n
end
function S:IsFaded(region) return hidden[region] ~= nil end
function S:BackdropOf(frame) return backdrops[frame] end

S.frame = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_REGEN_ENABLED"}) do
  pcall(S.frame.RegisterEvent, S.frame, e)
end
local loadTimer = nil
S.frame:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_REGEN_ENABLED" then
    if pendingCombat then pcall(S.Refresh, S) end
  elseif event == "ADDON_LOADED" then
    -- Load-on-demand Blizzard windows (talents, auction house, journals...).
    if S.active and type(name) == "string" and name:find("^Blizzard_") then
      if C_Timer and C_Timer.After then
        if not loadTimer then
          loadTimer = true
          C_Timer.After(0.5, function() loadTimer = nil; if S.active then pcall(S.Refresh, S) end end)
        end
      else
        pcall(S.Refresh, S)
      end
    end
  else
    pcall(S.Refresh, S)
  end
end)
