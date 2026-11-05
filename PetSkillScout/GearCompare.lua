-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- "Is this an upgrade for me?" for any item link, plus the places that use
-- it: the item tooltip line, quest rewards, group loot rolls and the arrows
-- on bag items. Scores come from PSS.Gear (spec weights, live Forever stats).
local PSS = PetSkillScout
PSS.GearCompare = {}
local GC = PSS.GearCompare

local function Secret(v) return PSS.IsSecret and PSS.IsSecret(v) end
local function Plain(v) if Secret(v) then return nil end return v end
local function Pack(...) return {n = select("#", ...), ...} end
local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = Pack(pcall(fn, ...))
  if not r[1] then return nil end
  return unpack(r, 2, r.n)
end
local function L(k) return PSS:L(k) end
local function G(n) local v = _G[n]; return type(v) == "table" and v or nil end
local function DB() return PetSkillScoutDB or {} end

local function IsHunter()
  local _, class = Call(UnitClass, "player")
  return Plain(class) == "HUNTER"
end
GC.IsHunter = IsHunter

-- Equip location -> inventory slots it can go in.
local EQUIP = {
  INVTYPE_HEAD = {1}, INVTYPE_NECK = {2}, INVTYPE_SHOULDER = {3}, INVTYPE_CLOAK = {15}, INVTYPE_CHEST = {5},
  INVTYPE_ROBE = {5}, INVTYPE_WRIST = {9}, INVTYPE_HAND = {10}, INVTYPE_WAIST = {6}, INVTYPE_LEGS = {7},
  INVTYPE_FEET = {8}, INVTYPE_FINGER = {11, 12}, INVTYPE_TRINKET = {13, 14}, INVTYPE_WEAPON = {16, 17},
  INVTYPE_2HWEAPON = {16}, INVTYPE_WEAPONMAINHAND = {16}, INVTYPE_WEAPONOFFHAND = {17},
  INVTYPE_RANGED = {18}, INVTYPE_RANGEDRIGHT = {18}, INVTYPE_THROWN = {18},
}
GC.EQUIP = EQUIP
-- Weapon subclasses a hunter can use (axes, bows, guns, polearms, swords,
-- staves, fist weapons, daggers, thrown, crossbows).
local HUNTER_WEAPONS = {[0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true, [8] = true,
  [10] = true, [13] = true, [15] = true, [16] = true, [18] = true}
GC.MAIL_LEVEL = 40

-- Can a hunter use it at all, and from which level ("mail at 40").
function GC:Usable(classID, subclassID, equipLoc)
  if classID == 2 then
    return HUNTER_WEAPONS[subclassID] == true
  elseif classID == 4 then
    if equipLoc == "INVTYPE_CLOAK" or subclassID == 0 then return true end
    if subclassID == 1 or subclassID == 2 then return true end -- cloth, leather
    if subclassID == 3 then return true, self.MAIL_LEVEL end    -- mail
    return false                                                -- plate, shields, relics
  end
  return false
end

local cache = {}
function GC:Reset() cache = {} end

-- Compare an item link with what is equipped.
-- Returns a table {delta, new, old, parts, canUse, reqLevel, tooLow} or nil
-- when the item is not wearable gear (or the client has not loaded it yet).
function GC:Compare(link, spec)
  if type(link) ~= "string" then return nil end
  local Gr = PSS.Gear
  if not Gr then return nil end
  spec = spec or Gr:Spec()
  local key = spec .. link
  if cache[key] ~= nil then return cache[key] or nil end
  local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
  local itemID, _, _, equipLoc, _, classID, subclassID = Call(info, link)
  itemID, equipLoc, classID, subclassID = Plain(itemID), Plain(equipLoc), Plain(classID), Plain(subclassID)
  local slots = equipLoc and EQUIP[equipLoc]
  if not (itemID and slots) then cache[key] = false; return nil end
  local canUse, fromLevel = self:Usable(classID, subclassID, equipLoc)
  local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
  local name, _, _, _, reqLevel = Call(getInfo, link)
  if not name then return nil end -- not loaded yet: do not cache
  reqLevel = math.max(Plain(reqLevel) or 0, fromLevel or 0)
  local isRanged = slots[1] == 18
  local st = Gr.RuntimeStats(link)
  local rec = Gr:Get(itemID)
  if rec then
    st = st or {}
    for _, k in ipairs({"crit", "hit", "ap", "rap", "map", "mp5"}) do
      if st[k] == nil and rec.st[k] then st[k] = rec.st[k] end
    end
  end
  local new = Gr:Score(st, isRanged and "ranged" or "other", spec)
  -- What it would replace: the weaker of two rings / trinkets; a two-hander
  -- replaces main hand + off hand; a one-hander the weaker hand once dual
  -- wielding is possible.
  local old, oldSt
  local level = Gr:PlayerLevel()
  local function eq(inv)
    local _, _, sc, est = Gr:Equipped(inv, spec)
    return sc or 0, est
  end
  if equipLoc == "INVTYPE_2HWEAPON" then
    local a, ast = eq(16)
    local b = eq(17)
    old, oldSt = a + b, ast
  elseif equipLoc == "INVTYPE_WEAPON" and level < Gr.DUAL_WIELD_LEVEL then
    old, oldSt = eq(16)
  else
    for _, inv in ipairs(slots) do
      local sc, est = eq(inv)
      if not old or sc < old then old, oldSt = sc, est end
    end
  end
  local res = {
    delta = new - (old or 0), new = new, old = old or 0,
    parts = Gr:DiffParts(st, oldSt, isRanged and "ranged" or "other", 3),
    canUse = canUse, reqLevel = reqLevel, tooLow = reqLevel > level, id = itemID,
  }
  cache[key] = res
  return res
end

-- Short coloured verdict: "+14 attack power (Marksmanship)".
function GC:Verdict(res)
  if not res then return nil end
  if not res.canUse then return "|cff8a8a8a" .. L("gcNotHunter") .. "|r" end
  local d = math.floor(res.delta + 0.5)
  local spec = L("gearSpec" .. PSS.Gear:Spec())
  local text
  if d > 0 then text = string.format("|cff7ee0a3" .. L("gcUpgrade") .. "|r", d, spec)
  elseif d < 0 then text = string.format("|cffff7a7a" .. L("gcDowngrade") .. "|r", d, spec)
  else text = "|cffbbbbbb" .. L("gcSame") .. "|r" end
  if res.tooLow then text = text .. "  |cffffcc55" .. string.format(L("gcFromLevel"), res.reqLevel) .. "|r" end
  return text
end

-- 5. Tooltip line --------------------------------------------------------------
local function TooltipEnabled() return DB().gearTooltip ~= false and IsHunter() end

local function OnItemTooltip(tt)
  if not TooltipEnabled() or type(tt) ~= "table" or tt.pssGearDone then return end
  local _, link = Call(tt.GetItem, tt)
  link = Plain(link)
  local res = link and GC:Compare(link)
  if not res then return end
  tt.pssGearDone = true
  tt:AddLine(PSS:Safe("|cff70d6ffPetSkillScout|r  " .. GC:Verdict(res)))
  if res.canUse and #res.parts > 0 then
    local out = {}
    for _, p in ipairs(res.parts) do table.insert(out, (p.up and "|cff7ee0a3" or "|cffff7a7a") .. p.text .. "|r") end
    tt:AddLine(PSS:Safe(table.concat(out, "   ")))
  end
  tt:Show()
end
GC.OnItemTooltip = OnItemTooltip

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, PSS:Timed("item tooltip (gear)", function(tt)
    if tt == GameTooltip or tt == ItemRefTooltip then pcall(OnItemTooltip, tt) end
  end))
else
  for _, tt in ipairs({GameTooltip, ItemRefTooltip}) do
    if tt and tt.HookScript then pcall(PSS.HookScript, tt, "OnTooltipSetItem", function(t) pcall(OnItemTooltip, t) end) end
  end
end
for _, tt in ipairs({GameTooltip, ItemRefTooltip}) do
  if tt and tt.HookScript then
    pcall(PSS.HookScript, tt, "OnTooltipCleared", function(t) t.pssGearDone = nil end)
    pcall(PSS.HookScript, tt, "OnHide", function(t) t.pssGearDone = nil end)
  end
end

-- Badges (quest rewards, loot rolls, bag items) ------------------------------
local FONT = "Interface\\AddOns\\PetSkillScout\\Fonts\\NotoSans-Regular.ttf"
local badges = setmetatable({}, {__mode = "k"})

local function Badge(button, size)
  local b = badges[button]
  if not b then
    b = button:CreateFontString(nil, "OVERLAY")
    pcall(b.SetFont, b, FONT, size or 11, "OUTLINE")
    badges[button] = b
  end
  return b
end
GC.Badge = Badge

local rings = setmetatable({}, {__mode = "k"})
local function Ring(frame, on, r, g, bl)
  local t = rings[frame]
  if not t and not on then return end
  if not t then
    t = {}
    for i = 1, 4 do
      local x = frame:CreateTexture(nil, "OVERLAY")
      x:SetTexture("Interface\\Buttons\\WHITE8X8")
      t[i] = x
    end
    t[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1); t[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1); t[1]:SetHeight(2)
    t[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1); t[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1); t[2]:SetHeight(2)
    t[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1); t[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -1, -1); t[3]:SetWidth(2)
    t[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 1); t[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1); t[4]:SetWidth(2)
    rings[frame] = t
  end
  for _, x in ipairs(t) do
    x:SetVertexColor(r or 1, g or 0.82, bl or 0.2, 1)
    if on then x:Show() else x:Hide() end
  end
end
GC.Ring = Ring

-- 6. Quest rewards -------------------------------------------------------------
local function QuestButtons()
  local list = {}
  local frame = G("QuestInfoRewardsFrame")
  if frame and type(frame.RewardButtons) == "table" then
    for _, b in ipairs(frame.RewardButtons) do list[#list + 1] = b end
  end
  if #list == 0 then
    for i = 1, 12 do
      local b = G("QuestInfoRewardsFrameQuestInfoItem" .. i) or G("QuestInfoItem" .. i)
      if b then list[#list + 1] = b end
    end
  end
  return list
end

function GC:MarkQuestRewards()
  local enabled = DB().gearQuest ~= false and IsHunter()
  local choices = {}
  for _, b in ipairs(QuestButtons()) do
    local badge = badges[b]
    if badge then badge:SetText("") end
    Ring(b, false)
    if enabled and b.IsShown and b:IsShown() and b.type == "choice" then
      local idx = b.GetID and b:GetID()
      local link = idx and Plain(Call(GetQuestItemLink, "choice", idx))
      if link then
        local res = self:Compare(link)
        local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
        local sell = Plain(select(11, Call(getInfo, link))) or 0
        choices[#choices + 1] = {button = b, res = res, sell = sell}
      end
    end
  end
  if #choices == 0 then return end
  local best, bestDelta
  for _, c in ipairs(choices) do
    local r = c.res
    if r and r.canUse and not r.tooLow and r.delta > 0.5 and (not bestDelta or r.delta > bestDelta) then
      best, bestDelta = c, r.delta
    end
  end
  local richest
  for _, c in ipairs(choices) do
    if not richest or c.sell > richest.sell then richest = c end
  end
  for _, c in ipairs(choices) do
    local badge = Badge(c.button, 11)
    badge:ClearAllPoints()
    badge:SetPoint("TOPRIGHT", c.button, "TOPRIGHT", -4, -3)
    local r = c.res
    if c == best then
      badge:SetText("|cffffd24a" .. L("gcBest") .. "|r  |cff7ee0a3+" .. math.floor(r.delta + 0.5) .. "|r")
      Ring(c.button, true, 1, 0.82, 0.2)
    elseif r and r.canUse and r.delta > 0.5 then
      badge:SetText("|cff7ee0a3+" .. math.floor(r.delta + 0.5) .. "|r")
    elseif not best and c == richest and c.sell > 0 then
      badge:SetText("|cffffd24a" .. L("gcSell") .. "|r")
      Ring(c.button, true, 0.85, 0.7, 0.3)
    else
      badge:SetText("")
    end
  end
end

-- 7. Group loot rolls ----------------------------------------------------------
local function RollFrames()
  local list = {}
  for i = 1, 8 do
    local f = G("GroupLootFrame" .. i)
    if f then list[#list + 1] = f end
  end
  local c = G("GroupLootContainer")
  if c and c.GetChildren then
    for _, f in ipairs({c:GetChildren()}) do
      if rawget(f, "rollID") then list[#list + 1] = f end
    end
  end
  return list
end

function GC:MarkRolls()
  local enabled = DB().gearRolls ~= false and IsHunter()
  for _, f in ipairs(RollFrames()) do
    local badge = badges[f]
    if badge then badge:SetText("") end
    local id = rawget(f, "rollID")
    if enabled and id and f.IsShown and f:IsShown() then
      local link = Plain(Call(GetLootRollItemLink, id))
      local res = link and self:Compare(link)
      if res then
        badge = Badge(f, 12)
        badge:ClearAllPoints()
        badge:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -4, 2)
        if not res.canUse then
          badge:SetText("|cff8a8a8a" .. L("gcNotForYou") .. "|r")
        elseif res.delta > 0.5 then
          badge:SetText("|cff7ee0a3" .. string.format(L("gcRollUp"), math.floor(res.delta + 0.5)) .. "|r" ..
            (res.tooLow and ("  |cffffcc55" .. string.format(L("gcFromLevel"), res.reqLevel) .. "|r") or ""))
        else
          badge:SetText("|cffbbbbbb" .. L("gcRollNo") .. "|r")
        end
      end
    end
  end
end

-- 11. Arrows on bag items --------------------------------------------------
local arrows = setmetatable({}, {__mode = "k"})
local function Arrow(button)
  local a = arrows[button]
  if not a then
    a = button:CreateTexture(nil, "OVERLAY", nil, 7)
    a:SetTexture("Interface\\AddOns\\PetSkillScout\\Textures\\UpgradeArrow")
    a:SetSize(14, 14)
    a:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    arrows[button] = a
  end
  return a
end

local function BagSlotOf(button)
  local bag = button.GetBagID and Call(button.GetBagID, button)
  if bag == nil then
    local parent = button.GetParent and button:GetParent()
    bag = parent and parent.GetID and parent:GetID()
  end
  local slot = button.GetID and button:GetID()
  return Plain(bag), Plain(slot)
end

function GC:MarkBagButton(button)
  if type(button) ~= "table" or not button.CreateFontString then return end
  local on = DB().gearBagArrows ~= false and IsHunter()
  local bag, slot = BagSlotOf(button)
  local link
  if on and bag and slot then
    local get = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    link = Plain(Call(get, bag, slot))
  end
  local res = link and self:Compare(link)
  if res and res.canUse and res.delta > 0.5 then
    local a = Arrow(button)
    -- Green: an upgrade now; yellow: an upgrade once you reach its level.
    if res.tooLow then a:SetVertexColor(1, 0.8, 0.33, 1) else a:SetVertexColor(0.36, 1, 0.54, 1) end
    a:Show()
  elseif arrows[button] then
    arrows[button]:Hide()
  end
end

local function ContainerButtons(frame)
  local list = {}
  if type(frame) ~= "table" then return list end
  if type(frame.EnumerateValidItems) == "function" then
    local ok = pcall(function()
      for _, b in frame:EnumerateValidItems() do list[#list + 1] = b end
    end)
    if ok and #list > 0 then return list end
  end
  if type(frame.Items) == "table" then
    for _, b in ipairs(frame.Items) do list[#list + 1] = b end
    if #list > 0 then return list end
  end
  local name = frame.GetName and frame:GetName()
  if type(name) == "string" then
    for i = 1, 40 do
      local b = G(name .. "Item" .. i)
      if b then list[#list + 1] = b end
    end
  end
  return list
end

function GC:MarkContainer(frame)
  for _, b in ipairs(ContainerButtons(frame)) do pcall(self.MarkBagButton, self, b) end
end

function GC:MarkAllBags()
  local frames = {G("ContainerFrameCombinedBags")}
  for i = 1, 13 do frames[#frames + 1] = G("ContainerFrame" .. i) end
  for _, f in pairs(frames) do
    if f and f.IsShown and f:IsShown() then self:MarkContainer(f) end
  end
end

-- Hooks and events -----------------------------------------------------------
local hooked = false
local function HookAll()
  if hooked or not hooksecurefunc then return end
  hooked = true
  if type(QuestInfo_Display) == "function" then
    PSS.HookSecure("QuestInfo_Display", function() pcall(GC.MarkQuestRewards, GC) end)
  end
  if type(GroupLootFrame_OpenNewFrame) == "function" then
    PSS.HookSecure("GroupLootFrame_OpenNewFrame", function() pcall(GC.MarkRolls, GC) end)
  end
  if type(ContainerFrame_Update) == "function" then
    PSS.HookSecure("ContainerFrame_Update", function(f) PSS:Soon(f, function() GC:MarkContainer(f) end) end)
  end
  local frames = {G("ContainerFrameCombinedBags")}
  for i = 1, 13 do frames[#frames + 1] = G("ContainerFrame" .. i) end
  for _, f in pairs(frames) do
    if f and type(f.UpdateItems) == "function" then
      pcall(PSS.HookSecure, f, "UpdateItems", function(self) PSS:Soon(self, function() GC:MarkContainer(self) end) end)
    end
  end
end

GC.frame = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_LOGIN", "QUEST_COMPLETE", "QUEST_DETAIL", "START_LOOT_ROLL", "BAG_UPDATE_DELAYED",
  "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_LEVEL_UP"}) do
  pcall(GC.frame.RegisterEvent, GC.frame, e)
end
local pending = 0
GC.frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    HookAll()
  elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
    GC:Reset()
    pending = 0.3
  else
    pending = 0.15
  end
end)
GC.frame:SetScript("OnUpdate", function(_, e)
  if pending <= 0 then return end
  pending = pending - (e or 0)
  if pending > 0 then return end
  local qf = G("QuestFrame")
  if qf and qf:IsShown() then pcall(GC.MarkQuestRewards, GC) end
  pcall(GC.MarkRolls, GC)
  pcall(GC.MarkAllBags, GC)
end)
-- Spec change from the Gear tab: drop cached results.
if PSS.Gear then
  local set = PSS.Gear.SetSpec
  PSS.Gear.SetSpec = function(self, s) set(self, s); GC:Reset(); pending = 0.1 end
end
GC.HookAll = HookAll
GC.frame.pssKey = "GearCompare"
PSS:Every(GC.frame, 0.1)
