-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Pet care: happiness, diet, best food in your bags, a Feed button and a
-- reminder when the pet stops being happy. The Feed button is a secure macro
-- button that YOU click ("/cast Feed Pet" + "/use bag slot"); nothing is automated.
local PSS = PetSkillScout
PSS.PetCare = {}
local PC = PSS.PetCare
local FEED_PET = 6991
local ENGLISH_TYPES = {meat=1, fish=2, cheese=3, bread=4, fungus=5, fruit=6, ["raw meat"]=1, ["raw fish"]=2}

local function safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

local function HasPet()
  return UnitExists and UnitExists("pet") and not (UnitIsDead and UnitIsDead("pet"))
end

-- 1 unhappy, 2 content, 3 happy (nil when not available), plus the exact
-- happiness fraction 0..1 when the client exposes it as a pet power.
local HAPPINESS_POWER = (Enum and Enum.PowerType and Enum.PowerType.Happiness) or 4
-- Forever moved the pet APIs into C_PetInfo. Secret values are never compared.
local function Plain(v) if PSS.IsSecret(v) then return nil end return v end
function PC:Happiness()
  if not HasPet() then return nil end
  local fn = (C_PetInfo and C_PetInfo.GetPetHappiness) or GetPetHappiness
  local h, damage, loyaltyRate = safe(fn)
  h, damage, loyaltyRate = Plain(h), Plain(damage), Plain(loyaltyRate)
  local frac
  if type(h) ~= "number" or h < 1 or h > 3 then
    local cur = Plain(safe(UnitPower, "pet", HAPPINESS_POWER))
    local max = Plain(safe(UnitPowerMax, "pet", HAPPINESS_POWER))
    frac = (type(cur) == "number" and type(max) == "number" and max > 0) and cur / max or nil
    h = frac and (frac < 1/3 and 1 or (frac < 2/3 and 2 or 3)) or nil
  end
  return h, damage, loyaltyRate, frac
end

-- Diet as a set of food type codes. Client list first, family data as fallback.
function PC:Diet()
  local diet, known = {}, false
  local types
  if C_PetInfo and C_PetInfo.GetPetFoodTypes then
    types = safe(C_PetInfo.GetPetFoodTypes)
    if type(types) ~= "table" then types = {types} end
  else
    types = {safe(GetPetFoodTypes)}
  end
  for _, name in ipairs(types) do
    local code = type(name) == "string" and ENGLISH_TYPES[name:lower()]
    if code then diet[code] = true; known = true end
  end
  if not known then
    local family = PSS.MyPet and PSS.MyPet.family
    for _, code in ipairs(PSS.FamilyDiet and PSS.FamilyDiet[family] or {}) do diet[code] = true; known = true end
  end
  return known and diet or nil
end

function PC:DietText()
  local diet = self:Diet()
  if not diet then return nil end
  local names = {}
  for code = 1, 6 do if diet[code] then table.insert(names, PSS:L("food" .. code)) end end
  return table.concat(names, ", ")
end

local function NumSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
  return safe(GetContainerNumSlots, bag) or 0
end

local function ItemAt(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then return info.itemID, info.stackCount, info.iconFileID, info.hyperlink end
    return nil
  end
  local icon, count = safe(GetContainerItemInfo, bag, slot)
  local link = safe(GetContainerItemLink, bag, slot)
  local id = link and tonumber(link:match("item:(%d+)"))
  return id, count, icon, link
end

-- Item name: from the bag link (always available), then the item cache.
local function ItemName(id, link)
  local name = type(link) == "string" and link:match("|h%[(.-)%]|h")
  if name and name ~= "" then return name end
  name = (C_Item and C_Item.GetItemNameByID and safe(C_Item.GetItemNameByID, id)) or safe(GetItemInfo, id)
  return name
end

-- Best food: the lowest item level that still gives full happiness (within
-- 10 levels of the pet), otherwise the highest the pet will still eat (30).
function PC:BestFood()
  local diet = self:Diet()
  if not (diet and PSS.Foods) then return nil end
  local petLevel = (UnitLevel and UnitLevel("pet")) or 1
  local full, partial, total = nil, nil, {}
  for bag = 0, 4 do
    for slot = 1, NumSlots(bag) do
      local id, count, icon, link = ItemAt(bag, slot)
      local food = id and PSS.Foods[id]
      if food and diet[food[1]] and food[2] > petLevel - 30 then
        total[id] = (total[id] or 0) + (count or 1)
        local cand = {id = id, bag = bag, slot = slot, level = food[2], icon = icon, link = link}
        if food[2] >= petLevel - 10 then
          if not full or cand.level < full.level then full = cand end
        elseif not partial or cand.level > partial.level then
          partial = cand
        end
      end
    end
  end
  local best = full or partial
  if best then
    best.count = total[best.id]
    best.name = ItemName(best.id, best.link)
    if not best.name then
      -- Not cached yet: ask the client and refresh when it arrives.
      if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, best.id) end
      self.waitingItem = best.id
      best.name = "item " .. best.id
    end
    best.full = full ~= nil
  end
  return best
end

-- Feed button --------------------------------------------------------------
local button
local function FeedSpellName()
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(FEED_PET)
    if info then return info.name end
  end
  return (GetSpellInfo and GetSpellInfo(FEED_PET)) or "Feed Pet"
end

local function CreateButton()
  if button then return button end
  button = CreateFrame("Button", "PetSkillScoutFeedButton", UIParent, "SecureActionButtonTemplate")
  button:SetSize(40, 40)
  button:SetFrameStrata("MEDIUM")
  button:SetClampedToScreen(true)
  button:SetMovable(true)
  button:RegisterForClicks("AnyUp", "AnyDown") -- the action runs once, on the phase the client uses
  button:RegisterForDrag("LeftButton")
  local pos = PetSkillScoutDB and PetSkillScoutDB.feedPos
  if pos and pos.x then button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos.x, pos.y)
  else button:SetPoint("CENTER", UIParent, "CENTER", 0, -220) end
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints(button)
  button.border = button:CreateTexture(nil, "OVERLAY")
  button.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  button.border:SetBlendMode("ADD")
  button.border:SetPoint("CENTER")
  button.border:SetSize(72, 72)
  button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  button.count:SetPoint("BOTTOMRIGHT", -2, 2)
  button.mood = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  button.mood:SetPoint("TOP", button, "BOTTOM", 0, -2)
  button:SetAttribute("type", "macro")
  button:SetScript("OnDragStart", function(self)
    if not (InCombatLockdown and InCombatLockdown()) and IsShiftKeyDown and IsShiftKeyDown() then self:StartMoving() end
  end)
  button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetCenter()
    if PetSkillScoutDB and x then PetSkillScoutDB.feedPos = {x = x, y = y} end
  end)
  button:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(PSS:Safe("PetSkillScout"), 0.44, 0.84, 1)
    if self.food then
      GameTooltip:AddLine(PSS:Safe(string.format(PSS:L("feedButtonTip"), UnitName("pet") or "?", self.food.name)), 1, 1, 1, true)
    end
    GameTooltip:AddLine(PSS:Safe(PSS:L("feedButtonDrag")), 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  button:Hide()
  return button
end

local function ButtonWanted(h)
  local mode = PetSkillScoutDB and PetSkillScoutDB.feedButton
  if mode == false then return false end
  if mode == "always" then return HasPet() end
  return HasPet() and h and h < 3
end

-- Secure attributes and visibility can only change out of combat.
function PC:UpdateButton()
  if InCombatLockdown and InCombatLockdown() then self.pending = true return end
  self.pending = false
  local h = self:Happiness()
  local food = HasPet() and self:BestFood() or nil
  if not (ButtonWanted(h) and food) then
    if button then button:Hide() end
    return
  end
  CreateButton()
  button.food = food
  button:SetAttribute("macrotext", "/cast " .. FeedSpellName() .. "\n/use " .. food.bag .. " " .. food.slot)
  button.icon:SetTexture(food.icon or "Interface\\Icons\\INV_Misc_Food_14")
  button.count:SetText(food.count and food.count > 1 and food.count or "")
  button.mood:SetText(h and PSS:L("happy" .. h) or "")
  local color = h == 1 and {1, 0.3, 0.3} or h == 2 and {1, 0.82, 0.2} or {0.4, 1, 0.4}
  button.mood:SetTextColor(color[1], color[2], color[3])
  button.border:SetVertexColor(color[1], color[2], color[3], 0.9)
  button:Show()
end

-- Reminder -----------------------------------------------------------------
local lastHappiness, lastReminder = nil, -1e9
function PC:CheckReminder()
  local h = self:Happiness()
  if h and lastHappiness and h < lastHappiness and h < 3
     and (not PetSkillScoutDB or PetSkillScoutDB.petCareReminder ~= false) then
    local now = GetTime and GetTime() or 0
    if now - lastReminder > 60 then
      lastReminder = now
      local msg = string.format(PSS:L("feedReminder"), UnitName("pet") or "?", PSS:L("happy" .. h))
      PSS:Print(msg)
      if RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, PSS:Safe(msg), ChatTypeInfo and ChatTypeInfo.RAID_WARNING)
      end
    end
  end
  lastHappiness = h
end

function PC:Summary()
  if not HasPet() then return nil end
  local parts = {}
  local h = self:Happiness()
  if h then table.insert(parts, PSS:L("happy" .. h)) end
  local diet = self:DietText()
  if diet then table.insert(parts, string.format(PSS:L("petDiet"), diet)) end
  local food = self:BestFood()
  if food then table.insert(parts, string.format(PSS:L("petFood"), food.name, food.count or 1))
  elseif diet then table.insert(parts, PSS:L("petNoFood")) end
  return table.concat(parts, "  ·  ")
end

local events = CreateFrame("Frame")
for _, e in ipairs({"PLAYER_ENTERING_WORLD", "UNIT_PET", "PET_UI_UPDATE", "PLAYER_REGEN_ENABLED",
                    "BAG_UPDATE_DELAYED", "UNIT_HAPPINESS", "UNIT_POWER_UPDATE", "UNIT_LEVEL",
                    "GET_ITEM_INFO_RECEIVED", "UNIT_PET_EXPERIENCE", "UNIT_HEALTH", "UNIT_MAXHEALTH"}) do
  pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, unit, powerType)
  if event == "GET_ITEM_INFO_RECEIVED" then
    if PC.waitingItem and tonumber(unit) == PC.waitingItem then
      PC.waitingItem = nil
      if PSS.UI and PSS.UI.view == "pet" and PSS.UI.RefreshPet then PSS.UI:RefreshPet(true) end
    end
    return
  end
  if event == "UNIT_PET_EXPERIENCE" or ((event == "UNIT_POWER_UPDATE" or event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and unit == "pet") then
    if PSS.UI and PSS.UI.view == "pet" and PSS.UI.RefreshPetStats and PetSkillScoutFrame and PetSkillScoutFrame:IsShown() then
      if PSS.UI.Guard then PSS.UI.Guard("pet stats", PSS.UI.RefreshPetStats, PSS.UI) else PSS.UI:RefreshPetStats() end
    end
    if event ~= "UNIT_POWER_UPDATE" then return end
  end
  if event == "UNIT_POWER_UPDATE" and (unit ~= "pet" or powerType ~= "HAPPINESS") then return end
  if (event == "UNIT_HAPPINESS" or event == "UNIT_LEVEL") and unit ~= "pet" then return end
  if event == "UNIT_PET" and unit ~= "player" then return end
  PC:CheckReminder()
  PC:UpdateButton()
end)
-- Happiness also decays without events on some clients: poll gently.
local poll = 0
events:SetScript("OnUpdate", function(_, elapsed)
  poll = poll + (elapsed or 0)
  if poll < 5 then return end
  poll = 0
  PC:CheckReminder()
  if PC.pending or (button and button:IsShown()) or HasPet() then PC:UpdateButton() end
end)
events.pssKey = "PetCare"
PSS:Every(events, 1)
