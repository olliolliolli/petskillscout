-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- 3D creature viewer adapted from the PlayerModel approach used by HunterPetAtlas.
-- Uses the client's creature database (NPC IDs); no external model files are bundled.
local PSS = PetSkillScout
PSS.ModelPreview = {}
local Preview = PSS.ModelPreview
local modelFrame, modelWidget, modelTitle, modelInfo, statusText
local stableDetails, stablePanel, stableHeading, stableDivider, modelViewport
local stableSkillRows = {}
-- Moderate camera distance: avoid extreme values that can push some creature models out of view.
local currentFacing, currentZoom = math.rad(-25), 0.45
local dragging = false
-- Loader state. mode = "display" (SetDisplayInfo) or "creature" (SetCreature).
local pending, pendingID, pendingDisplay, loadMode = false, nil, nil, nil
local loadElapsed, loadAttempt, triedDisplay, triedCreature = 0, 0, false, false
local pendingUnit, triedUnit = nil, false
local MAX_CREATURE_TRIES = 4 -- the creature cache can need a few seconds to arrive
local modelLoaded = false
local cameraDelay, cameraPasses = 0, 0
local themeParts = {}
local function CurrentTheme()
  local theme = PetSkillScoutDB and PetSkillScoutDB.theme
  if theme == "blizzard" or theme == "classic" or theme == "moonglade" then return theme end
  return "journal"
end
local function Color(tex, rgb)
  tex:SetTexture("Interface\\Buttons\\WHITE8X8")
  tex:SetVertexColor(rgb[1],rgb[2],rgb[3],1)
end
local function ModelTheme()
  if not modelFrame or not themeParts.bg then return end
  local theme = CurrentTheme()
  local journal = theme == "journal"
  local classic = theme == "blizzard"
  local brown = theme == "classic"
  local t = themeParts
  local moon = theme == "moonglade"
  local bg = moon and {0.047,0.051,0.110} or journal and {0.050,0.092,0.074} or {0.095,0.073,0.050}
  local panel = moon and {0.098,0.106,0.208} or journal and {0.102,0.160,0.125} or {0.185,0.143,0.092}
  local rim = moon and {0.26,0.29,0.50} or journal and {0.27,0.34,0.27} or {0.51,0.37,0.19}
  local ink = moon and {0.90,0.92,1.0} or journal and {0.96,0.87,0.68} or {1.0,0.88,0.62}
  local secondary = moon and {0.62,0.66,0.82} or journal and {0.61,0.70,0.62} or {0.80,0.71,0.54}
  Color(t.bg,bg)
  Color(t.header,panel)
  Color(t.footer,panel)
  Color(t.closeBg,panel)
  Color(t.viewportBg,moon and {0.030,0.034,0.075} or journal and {0.035,0.065,0.053} or {0.045,0.032,0.020})
  Color(t.line,moon and {0.63,0.78,0.98} or journal and {0.86,0.70,0.43} or {0.91,0.72,0.34})
  for _,tx in ipairs(t.rims) do tx:SetVertexColor(rim[1],rim[2],rim[3],1) end
  for _,tx in ipairs(t.titles) do tx:SetTextColor(ink[1],ink[2],ink[3]) end
  for _,tx in ipairs(t.secondary) do tx:SetTextColor(secondary[1],secondary[2],secondary[3]) end
  for _,tx in ipairs(t.classicTextures) do
    if classic then tx:Show() else tx:Hide() end
  end
  if t.classicLogo then
    if classic then t.classicLogo:Show() else t.classicLogo:Hide() end
  end
  if t.classicHeaderTrim then
    if classic then t.classicHeaderTrim:Show() else t.classicHeaderTrim:Hide() end
  end
  if t.classicCloseBorder then
    if classic then t.classicCloseBorder:Show() else t.classicCloseBorder:Hide() end
  end
  if classic then
    t.title:SetText("PetSkillScout  -  3D Model")
    t.title:ClearAllPoints()
    t.title:SetPoint("TOP",modelFrame,"TOP",13,-17)
    t.title:SetFont("Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf",13,"")
    t.subtitle:Hide()
    -- Match the main-window Classic button: texture provides both fill and rim.
    t.closeBg:SetAlpha(0)
    t.closeText:SetTextColor(1,0.83,0.20)
  else
    t.title:SetText("PetSkillScout")
    t.title:ClearAllPoints()
    t.title:SetPoint("TOPLEFT",modelFrame,"TOPLEFT",16,-11)
    t.title:SetFont("Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf",17,"")
    t.subtitle:Show()
    t.closeBg:SetAlpha(1)
    t.closeBg:SetVertexColor(panel[1],panel[2],panel[3],1)
    t.closeText:SetTextColor(ink[1],ink[2],ink[3])
  end
  if stablePanel then
    Color(stablePanel.bg, journal and {0.085,0.140,0.109} or
      (classic and {0.16,0.115,0.068} or {0.14,0.105,0.067}))
    Color(stableDivider, journal and {0.64,0.52,0.32} or {0.72,0.53,0.24})
    stableHeading:SetTextColor(ink[1],ink[2],ink[3])
    stableDetails:SetTextColor(secondary[1],secondary[2],secondary[3])
    for _,row in ipairs(stableSkillRows) do
      row.label:SetTextColor(ink[1],ink[2],ink[3])
    end
    if classic then
      stableHeading:SetText(PSS:L("stableCompanion"))
    elseif brown then
      stableHeading:SetText(PSS:L("stablePetHeading"))
    else
      stableHeading:SetText(PSS:L("stableRecordHeading"))
    end
  end
  if brown then
    t.viewportBg:SetVertexColor(0.09,0.065,0.038,1)
  end
end
function Preview:ApplyTheme()
  ModelTheme()
end


-- Display IDs for every known beast are in DisplayIDs.lua (PSS.DisplayIDs).

local function SafeCall(obj, method, ...)
  if not obj or type(obj[method]) ~= "function" then return false end
  return pcall(obj[method], obj, ...)
end

local function ClearModel()
  if not modelWidget then return end
  SafeCall(modelWidget, "ClearModel")
  -- SetModel("") can leave an invalid state on older custom clients.
end

-- Let the client's PlayerModel select its initial full-body camera.
-- The old delayed ApplyCamera() called SetCamDistanceScale(2.8/3.3),
-- which zoomed the model in AFTER it initially appeared correctly.
local function ApplyCamera()
  if not modelWidget then return end
  SafeCall(modelWidget, "SetFacing", currentFacing)
end

local function ScheduleCamera()
  -- Deliberately do not overwrite the camera after asynchronous model loading.
  cameraDelay, cameraPasses = 0, 4
end

local function CreateViewer()
  if modelFrame then return end
  -- Match the Hunter's Journal palette instead of using the default Blizzard window.
  modelFrame = CreateFrame("Frame", "PetSkillScoutModelFrame", UIParent)
  modelFrame:SetSize(360, 440)
  modelFrame:SetPoint("LEFT", PetSkillScoutFrame, "RIGHT", 8, 0)
  modelFrame:SetFrameStrata("DIALOG")
  modelFrame:SetMovable(true)
  modelFrame:EnableMouse(true)
  modelFrame:RegisterForDrag("LeftButton")
  modelFrame:SetScript("OnDragStart", function(self) if self.StartMoving then self:StartMoving() end end)
  modelFrame:SetScript("OnDragStop", function(self) if self.StopMovingOrSizing then self:StopMovingOrSizing() end end)

  local function Fill(parent, layer, color)
    local t = parent:CreateTexture(nil, layer)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(color[1], color[2], color[3], 1)
    return t
  end
  local function Stroke(parent, color)
    local edges = {
      {"TOPLEFT", "TOPRIGHT", true}, {"BOTTOMLEFT", "BOTTOMRIGHT", true},
      {"TOPLEFT", "BOTTOMLEFT", false}, {"TOPRIGHT", "BOTTOMRIGHT", false}
    }
    for _, edge in ipairs(edges) do
      local t = Fill(parent, "BORDER", color)
      t:SetPoint(edge[1], parent, edge[1], 0, 0)
      t:SetPoint(edge[2], parent, edge[2], 0, 0)
      if edge[3] then t:SetHeight(1) else t:SetWidth(1) end
      table.insert(themeParts.rims,t)
    end
  end
  local bg = Fill(modelFrame, "BACKGROUND", {0.050, 0.092, 0.074})
  themeParts.bg=bg
  themeParts.rims={}
  themeParts.titles={}
  themeParts.secondary={}
  themeParts.classicTextures={}
  bg:SetAllPoints(modelFrame)
  Stroke(modelFrame, {0.27, 0.34, 0.27})

  local header = Fill(modelFrame, "ARTWORK", {0.102, 0.160, 0.125})
  themeParts.header=header
  header:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", modelFrame, "TOPRIGHT", -1, -1)
  header:SetHeight(53)
  local line = Fill(modelFrame, "ARTWORK", {0.86, 0.70, 0.43})
  themeParts.line=line
  line:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 14, -54)
  line:SetPoint("TOPRIGHT", modelFrame, "TOPRIGHT", -14, -54)
  line:SetHeight(1)

  local font = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
  local title = modelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetFont(font, 17, "")
  title:SetTextColor(0.96, 0.87, 0.68)
  title:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 16, -11)
  title:SetText("PetSkillScout")
  themeParts.title=title
  table.insert(themeParts.titles,title)
  local subtitle = modelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  subtitle:SetFont(font, 10, "")
  subtitle:SetTextColor(0.61, 0.70, 0.62)
  subtitle:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 17, -34)
  subtitle:SetText("HUNTER COMPANION ATLAS  /  3D MODEL")
  themeParts.subtitle=subtitle
  table.insert(themeParts.secondary,subtitle)

  local close = CreateFrame("Button", nil, modelFrame)
  close:SetSize(42, 36)
  close:SetPoint("TOPRIGHT", modelFrame, "TOPRIGHT", -7, -8)
  local closeBg = Fill(close, "BACKGROUND", {0.102, 0.160, 0.125})
  closeBg:SetAllPoints(close)
  themeParts.closeBg=closeBg
  -- Store the flat border so Classic can hide it under the textured button.
  Stroke(close, {0.27, 0.34, 0.27})
  local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  closeText:SetFont(font, 15, "")
  closeText:SetTextColor(0.96, 0.87, 0.68)
  closeText:SetPoint("CENTER")
  closeText:SetText("X")
  themeParts.closeText=closeText
  table.insert(themeParts.titles,closeText)
  close:SetScript("OnClick", function() modelFrame:Hide() end)

  local viewport = CreateFrame("Frame", nil, modelFrame)
  modelViewport = viewport
  viewport:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 13, -68)
  viewport:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", -13, 86)
  local viewportBg = Fill(viewport, "BACKGROUND", {0.035, 0.065, 0.053})
  viewportBg:SetAllPoints(viewport)
  themeParts.viewportBg=viewportBg
  Stroke(viewport, {0.27, 0.34, 0.27})

  local footer = Fill(modelFrame, "ARTWORK", {0.102, 0.160, 0.125})
  footer:SetPoint("BOTTOMLEFT", modelFrame, "BOTTOMLEFT", 13, 12)
  footer:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", -13, 12)
  footer:SetHeight(65)
  themeParts.footer=footer

  modelWidget = CreateFrame("PlayerModel", "PetSkillScoutCreatureModel", modelFrame)
  modelWidget:SetPoint("TOPLEFT", modelFrame, "TOPLEFT", 16, -71)
  modelWidget:SetPoint("BOTTOMRIGHT", modelFrame, "BOTTOMRIGHT", -16, 89)
  modelWidget:EnableMouse(true)
  modelWidget:EnableMouseWheel(true)
  local function BeginRotate(button)
    if button == "LeftButton" and type(GetCursorPosition) == "function" then
      local ok, x = pcall(GetCursorPosition)
      if ok then modelWidget.dragX = x; dragging = true end
    end
  end
  local function EndRotate()
    dragging = false
    if modelWidget then modelWidget.dragX = nil end
  end
  local function ZoomModel(delta)
    -- Small, bounded steps: one wheel notch must never make the model vanish.
    -- Wheel up moves closer; wheel down moves farther away.
    currentZoom = math.max(0.35, math.min(2.0, currentZoom - delta * 0.10))
    SafeCall(modelWidget, "SetCamDistanceScale", currentZoom)
  end
  modelWidget:SetScript("OnMouseDown", function(_, button) BeginRotate(button) end)
  modelWidget:SetScript("OnMouseUp", EndRotate)
  modelWidget:SetScript("OnHide", EndRotate)
  modelWidget:SetScript("OnMouseWheel", function(_, delta) ZoomModel(delta) end)
  modelFrame:EnableMouseWheel(true)
  modelFrame:SetScript("OnMouseWheel", function(_, delta) ZoomModel(delta) end)
  modelFrame:SetScript("OnMouseDown", function(_, button) BeginRotate(button) end)
  modelFrame:SetScript("OnMouseUp", EndRotate)
  modelWidget:SetScript("OnUpdate", function(_, elapsed)
    if not dragging or not modelWidget.dragX or type(GetCursorPosition) ~= "function" then return end
    local ok, x = pcall(GetCursorPosition)
    if not ok or not x then dragging = false; return end
    currentFacing = currentFacing + (x - modelWidget.dragX) * 0.01
    modelWidget.dragX = x
    SafeCall(modelWidget, "SetFacing", currentFacing)
  end)
  modelWidget:SetScript("OnModelLoaded", function()
    modelLoaded = true
    ScheduleCamera()
    if statusText then statusText:SetText(PSS:L("modelControls")) end
  end)
  -- Some legacy clients do not fire OnModelLoaded for NPCs. Check for a
  -- loaded model after each attempt and retry only when it is still blank.
  local priorUpdate = modelWidget:GetScript("OnUpdate")
  modelWidget:SetScript("OnUpdate", function(self, elapsed)
    if priorUpdate then priorUpdate(self, elapsed) end
    -- Run after the model loader's own camera initialization. A single
    -- immediate call during SetDisplayInfo is frequently overwritten.
    if cameraPasses < 4 and modelFrame:IsShown() then
      cameraDelay = cameraDelay + (elapsed or 0)
      if cameraDelay >= 0.18 then
        cameraDelay = 0
        cameraPasses = cameraPasses + 1
        ApplyCamera()
      end
    end
    if not pending then return end
    loadElapsed = loadElapsed + (elapsed or 0)
    if loadElapsed < 1.5 then return end
    loadElapsed = 0
    Preview:CheckLoad()
  end)

  modelTitle = modelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  modelTitle:SetFont(font, 16, "")
  modelTitle:SetTextColor(0.96, 0.87, 0.68)
  modelTitle:SetPoint("BOTTOM", modelFrame, "BOTTOM", 0, 31)
  table.insert(themeParts.titles,modelTitle)
  modelInfo = modelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  modelInfo:SetFont(font, 11, "")
  modelInfo:SetTextColor(0.61, 0.70, 0.62)
  modelInfo:SetPoint("BOTTOM", modelFrame, "BOTTOM", 0, 36)
  table.insert(themeParts.secondary,modelInfo)
  statusText = modelFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusText:SetFont(font, 10, "")
  statusText:SetTextColor(0.61, 0.70, 0.62)
  statusText:SetPoint("BOTTOM", modelFrame, "BOTTOM", 0, 18)
  table.insert(themeParts.secondary,statusText)
  -- Classic Blizzard-inspired stone and metal use bundled textures, not
  -- SetBackdrop (unavailable on this client).
  local function ThemeTexture(parent, path, anchor, offsets)
    local tx=parent:CreateTexture(nil,"ARTWORK")
    tx:SetTexture("Interface\\AddOns\\PetSkillScout\\Textures\\"..path)
    if anchor=="all" then tx:SetAllPoints(parent)
    else
      tx:SetPoint("TOPLEFT",parent,"TOPLEFT",offsets[1],offsets[2])
      tx:SetPoint("TOPRIGHT",parent,"TOPRIGHT",offsets[3],offsets[2])
      tx:SetHeight(offsets[4])
    end
    tx:Hide()
    table.insert(themeParts.classicTextures,tx)
    return tx
  end
  -- Texture behind header and footer text, but not over the 3D widget.
  local stone=ThemeTexture(modelFrame,"ClassicStone","all")
  stone:SetDrawLayer("BACKGROUND",1)
  local headerTex=ThemeTexture(modelFrame,"ClassicModelHeader","top",{1,-1,-1,57})
  headerTex:SetDrawLayer("ARTWORK",1)
  -- WoW Classic character-window style: metal-and-brown title strip,
  -- a round addon medallion on the left, and a red framed close control.
  -- The logo is an existing bundled TGA, not the hunter class icon.
  local classicHeaderTrim=modelFrame:CreateTexture(nil,"OVERLAY")
  classicHeaderTrim:SetTexture("Interface\\AddOns\\PetSkillScout\\Textures\\ClassicMetal")
  classicHeaderTrim:SetPoint("TOPLEFT",modelFrame,"TOPLEFT",2,-53)
  classicHeaderTrim:SetPoint("TOPRIGHT",modelFrame,"TOPRIGHT",-2,-53)
  classicHeaderTrim:SetHeight(4)
  classicHeaderTrim:Hide()
  themeParts.classicHeaderTrim=classicHeaderTrim

  -- Keep the Classic crest fully inside the window frame, including at screen edges.
  -- Crest on its own elevated frame: Classic metal border must remain behind it.
  local crestLayer=CreateFrame("Frame",nil,modelFrame)
  crestLayer:SetAllPoints(modelFrame)
  crestLayer:SetFrameLevel(modelFrame:GetFrameLevel()+30)
  local classicLogo=crestLayer:CreateTexture(nil,"OVERLAY",nil,7)
  classicLogo:SetTexture("Interface\\AddOns\\PetSkillScout\\Textures\\ClassicMedallion")
  classicLogo:SetWidth(70)
  classicLogo:SetHeight(70)
  classicLogo:SetPoint("TOPLEFT",crestLayer,"TOPLEFT",-26,13)
  classicLogo:Hide()
  themeParts.classicLogo=classicLogo

   -- Same full-size Classic button as the main window, with an explicit
   -- complete metal rim on all four sides (no partial/cropped texture).
   local classicCloseBorder=close:CreateTexture(nil,"ARTWORK")
   classicCloseBorder:SetTexture("Interface\\AddOns\\PetSkillScout\\Textures\\ClassicButton")
   classicCloseBorder:SetAllPoints(close)
   classicCloseBorder:Hide()
   themeParts.classicCloseBorder=classicCloseBorder
  local footerTex=ThemeTexture(modelFrame,"ClassicLeather","all")
  footerTex:ClearAllPoints()
  footerTex:SetPoint("BOTTOMLEFT",modelFrame,"BOTTOMLEFT",13,12)
  footerTex:SetPoint("BOTTOMRIGHT",modelFrame,"BOTTOMRIGHT",-13,12)
  footerTex:SetHeight(65)
  footerTex:SetDrawLayer("ARTWORK",1)
  -- The metal edging is outside the 3D model viewport.
  local function MetalEdge(a,b,horizontal)
    local tx=modelFrame:CreateTexture(nil,"OVERLAY")
    tx:SetTexture("Interface\\AddOns\\PetSkillScout\\Textures\\ClassicMetal")
    tx:SetPoint(a,modelFrame,a,0,0)
    tx:SetPoint(b,modelFrame,b,0,0)
    if horizontal then tx:SetHeight(5) else tx:SetWidth(5) end
    tx:Hide()
    table.insert(themeParts.classicTextures,tx)
  end
  MetalEdge("TOPLEFT","TOPRIGHT",true)
  MetalEdge("BOTTOMLEFT","BOTTOMRIGHT",true)
  MetalEdge("TOPLEFT","BOTTOMLEFT",false)
  MetalEdge("TOPRIGHT","BOTTOMRIGHT",false)
  -- A dedicated frame is essential: the model viewport is a child frame and
  -- draws above textures/fontstrings attached directly to modelFrame.
  stablePanel = CreateFrame("Frame",nil,modelFrame)
  stablePanel:SetPoint("BOTTOMLEFT",modelFrame,"BOTTOMLEFT",16,65)
  stablePanel:SetPoint("BOTTOMRIGHT",modelFrame,"BOTTOMRIGHT",-16,65)
  stablePanel:SetHeight(184)
  stablePanel:SetFrameLevel(modelWidget:GetFrameLevel()+3)
  local detailBg=stablePanel:CreateTexture(nil,"BACKGROUND")
  detailBg:SetAllPoints(stablePanel)
  stablePanel.bg=detailBg
  stableDivider = stablePanel:CreateTexture(nil,"ARTWORK")
  stableDivider:SetPoint("TOPLEFT",stablePanel,"TOPLEFT",8,-30)
  stableDivider:SetPoint("TOPRIGHT",stablePanel,"TOPRIGHT",-8,-30)
  stableDivider:SetHeight(1)
  stableHeading = stablePanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
  stableHeading:SetPoint("TOPLEFT",stablePanel,"TOPLEFT",8,-9)
  stableDetails = stablePanel:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  stableDetails:SetPoint("TOPLEFT",stablePanel,"TOPLEFT",8,-44)
  stableDetails:SetHeight(20)
  stableDetails:SetWidth(310)
  stableDetails:SetJustifyH("LEFT")
  stableDetails:SetJustifyV("TOP")
  stableDetails:SetTextColor(0.96,0.87,0.68)
  -- Compact icon + skill name rows, styled with the same theme as the card.
  for i=1,5 do
    local row=CreateFrame("Frame",nil,stablePanel)
    row:SetSize(310,22)
    row:SetPoint("TOPLEFT",stablePanel,"TOPLEFT",8,-70-(i-1)*23)
    local icon=row:CreateTexture(nil,"ARTWORK")
    icon:SetSize(19,19)
    icon:SetPoint("LEFT",row,"LEFT",0,0)
    local label=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    label:SetPoint("LEFT",icon,"RIGHT",8,0)
    label:SetJustifyH("LEFT")
    row.icon=icon
    row.label=label
    row:Hide()
    stableSkillRows[i]=row
  end
  stablePanel:Hide()
  ModelTheme()
  modelFrame:SetScript("OnHide", function() pending = false; modelLoaded = false; cameraPasses = 4 end)
  modelFrame:Hide()
end

function Preview:Show(beast)
  if not beast then return end
  CreateViewer()
  modelFrame:SetHeight(440)
  if modelWidget then
    modelWidget:ClearAllPoints()
    modelWidget:SetPoint("TOPLEFT",modelFrame,"TOPLEFT",16,-71)
    modelWidget:SetPoint("BOTTOMRIGHT",modelFrame,"BOTTOMRIGHT",-16,89)
  end
  if stablePanel then stablePanel:Hide() end
  for _,row in ipairs(stableSkillRows) do row:Hide() end
  if modelViewport then
    modelViewport:ClearAllPoints()
    modelViewport:SetPoint("TOPLEFT",modelFrame,"TOPLEFT",13,-68)
    modelViewport:SetPoint("BOTTOMRIGHT",modelFrame,"BOTTOMRIGHT",-13,86)
  end
  ModelTheme()
  local observed = PetSkillScoutDB and PetSkillScoutDB.observedCreatureIDs
  local creatureID = tonumber(beast.npcID or beast.creatureID or (observed and observed[beast.name]))
  modelTitle:SetText(beast.name or "Creature")
  modelInfo:Show()
  statusText:Show()
  local npcText = creatureID and tostring(creatureID) or PSS:L("unknown")
  if beast.ability then
    modelInfo:SetText(string.format("%s %s %s  |  NPC #%s", PSS:NameAbility(beast.ability), PSS:L("rank"), tostring(beast.rank or "?"), npcText))
  else
    -- Rare-catalogue and stable entries have no teaching skill: show family and level.
    local family = beast.family and PSS:NameFamily(beast.family) or "?"
    local level = beast.minLevel or beast.level
    modelInfo:SetText(string.format("%s  |  %s %s  |  NPC #%s", family, PSS:L("level"), tostring(level or "?"), npcText))
  end
  statusText:SetText(PSS:L("modelControls"))
  modelFrame:Show()
  -- Start zoomed out so larger creatures fit in the preview; wheel still allows adjustment.
  currentFacing = math.rad(-25)
  currentZoom = 1.0 -- client default; do not force a close-up
  if not creatureID and not tonumber(beast.displayID) and not beast.unit then
    pending = false
    ClearModel()
    statusText:SetText(PSS:L("modelNoID"))
    return
  end

  -- Display ID first: it renders without the creature being in the client's
  -- cache. SetCreature(npcID) is the fallback (and covers Forever-only models).
  pendingID, pendingUnit, triedUnit = creatureID, beast.unit, false
  pendingDisplay = tonumber(beast.displayID) or (creatureID and PSS.DisplayIDs and PSS.DisplayIDs[creatureID])
  pending, modelLoaded = true, false
  loadElapsed, loadAttempt, triedDisplay, triedCreature = 0, 0, false, false
  if not self:TryNext() then
    pending = false
    ClearModel()
    statusText:SetText(PSS:L("modelApiFailed"))
    return
  end
  statusText:SetText(PSS:L("modelLoading"))
end

-- Starts the next load attempt. Returns false when nothing is left to try.
function Preview:TryNext()
  if pendingUnit and not triedUnit then
    triedUnit, loadMode = true, "unit"
    ClearModel()
    if SafeCall(modelWidget, "SetUnit", pendingUnit) then ScheduleCamera(); return true end
  end
  if pendingDisplay and not triedDisplay then
    triedDisplay, loadMode = true, "display"
    ClearModel()
    if SafeCall(modelWidget, "SetDisplayInfo", pendingDisplay) then ScheduleCamera(); return true end
  end
  if pendingID and loadAttempt < MAX_CREATURE_TRIES then
    loadAttempt, loadMode, triedCreature = loadAttempt + 1, "creature", true
    -- Clear only on the first creature attempt; later ones just re-request
    -- the creature, which loads once the client has cached it.
    if loadAttempt == 1 then ClearModel() end
    if SafeCall(modelWidget, "SetCreature", pendingID) then ScheduleCamera(); return true end
  end
  return false
end

-- true = a model is loaded, false = still blank, nil = this client cannot tell.
local function HasModel()
  for _, method in ipairs({"GetModelFileID", "GetModel"}) do
    if modelWidget and type(modelWidget[method]) == "function" then
      local ok, value = pcall(modelWidget[method], modelWidget)
      if ok then
        return value ~= nil and value ~= "" and value ~= 0
      end
    end
  end
  return nil
end

function Preview:CheckLoad()
  local loaded = modelLoaded or HasModel()
  -- Without a way to inspect the model, keep a display model rather than
  -- replacing a possibly visible creature with a blank SetCreature attempt.
  if loaded == nil and (loadMode == "display" or loadMode == "unit") then loaded = true end
  if loaded then
    pending = false
    if statusText then statusText:SetText(PSS:L("modelControls")) end
    return
  end
  if not self:TryNext() then
    pending = false
    ClearModel()
    if statusText then statusText:SetText(PSS:L("modelUnavailable")) end
  end
end

-- Stable-pet detail view: model above, cached pet information below.
-- The stable API does not report learned skills; never infer them from family.
function Preview:ShowStable(pet)
  if not pet then return end
  -- The pet that is currently summoned can be rendered straight from its unit,
  -- even when the stable record has no NPC or display ID.
  local view = pet
  if UnitExists and UnitExists("pet") and UnitName and PSS.Plain(UnitName("pet")) == pet.name then
    view = setmetatable({unit="pet"}, {__index=pet})
  end
  self:Show(view)
  if not modelFrame or not stableDetails then return end
  modelFrame:SetHeight(590)
  if modelViewport then
    modelViewport:ClearAllPoints()
    modelViewport:SetPoint("TOPLEFT",modelFrame,"TOPLEFT",13,-68)
    modelViewport:SetPoint("BOTTOMRIGHT",modelFrame,"BOTTOMRIGHT",-13,250)
  end
  -- Preserve the original viewport size when extending the window downward.
  modelWidget:ClearAllPoints()
  modelWidget:SetPoint("TOPLEFT",modelFrame,"TOPLEFT",16,-71)
  modelWidget:SetPoint("BOTTOMRIGHT",modelFrame,"BOTTOMRIGHT",-16,250)
  local spells=pet.spells or {}
  stableDetails:SetText(
    (pet.name or PSS:L("stableUnknownPet")).."  |  "..(pet.family and PSS:NameFamily(pet.family) or PSS:L("stableUnknownFamily"))..
    "  |  "..string.format(PSS:L("stableLevel"),tostring(pet.level or "?"))..
    (#spells==0 and ("  |  "..PSS:L("stableSkillsMissing")) or "")
  )
  for i,row in ipairs(stableSkillRows) do
    row:Hide()
    local spell=spells[i]
    if spell then
      local name=tostring(spell.name or spell.key or "?")
      local texture
      if type(GetSpellTexture)=="function" then
        local ids={bite=17253,claw=16827,growl=2649,dash=23099,prowl=24450,cower=1742}
        local ok,result=pcall(GetSpellTexture,spell.spellID or ids[string.lower(name)] or name)
        if ok then texture=result end
      end
      if type(texture)~="string" and type(texture)~="number" then texture=nil end
      if not texture then
        local fallback={
          bite="Interface\\Icons\\Ability_Racial_Cannibalize",
          claw="Interface\\Icons\\Ability_Druid_Rake",
          growl="Interface\\Icons\\Ability_Physical_Taunt",
          dash="Interface\\Icons\\Ability_Druid_Dash",
          prowl="Interface\\Icons\\Ability_Druid_SupriseAttack",
          cower="Interface\\Icons\\Ability_Druid_Cower"
        }
        texture=fallback[string.lower(name)] or "Interface\\Icons\\INV_Misc_QuestionMark"
      end
      row.icon:SetTexture(texture)
      row.icon:Show()
      row.icon:SetAlpha(1)
      row.icon:SetTexCoord(0.08,0.92,0.08,0.92)
      row.icon:SetVertexColor(1,1,1,1)
      row.label:SetText(PSS:NameAbility(name)..(spell.rank and ("  -  "..string.format(PSS:L("stableRank"),tostring(spell.rank))) or ""))
      row:Show()
    end
  end
  stablePanel:Show()
  ModelTheme()
  -- Stable view footer should show only the pet name.
  modelTitle:SetText(pet.name or pet.family or PSS:L("stablePetFallback"))
  modelInfo:Hide()
  statusText:Hide()
end
