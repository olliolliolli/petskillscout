-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Quest ratings where you meet quests, and optional auto-accept.
-- * NPC dialogs (gossip and greeting lists): the "!" of quests worth doing
--   turns purple, quests not worth the time turn grey with a short mark.
-- * Quest window: a line with the rating under the window.
-- * Quest log: worth-it titles purple, not-worth titles grey.
-- * Auto-accept (Settings > Quests, off by default): "worth" takes only the
--   quests worth doing, "all" every quest. Hold Shift at the NPC to skip.
-- Only Blizzard functions meant for addons are used (hooksecurefunc, the
-- gossip / quest API); nothing is replaced and nothing runs in combat that
-- the game protects.
local PSS = PetSkillScout
PSS.QuestAuto = {}
local QA = PSS.QuestAuto

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
local function DB() return PetSkillScoutDB or {} end
local function Now() return (GetTime and GetTime()) or 0 end

function QA:Mode()
  local m = DB().questAuto
  if m == "worth" or m == "all" then return m end
  return "off"
end
function QA:MarksOn() return DB().questWorth ~= false end

-- Verdict of a quest; unknown quests (not in the database) are "ok" unless trivial.
function QA:Verdict(id, trivial)
  local W = PSS.QuestWorth
  if not (W and id) then return trivial and "skip" or "ok" end
  if W:Record(id) then return W:Verdict(id) end
  if trivial then return "skip" end
  -- Not in the database: rate it from the game's numbers when we have them.
  local saved = DB().questXP and DB().questXP[id]
  if saved then return W:Rate(id).verdict end
  return "ok"
end

function QA:Wanted(id, trivial)
  local mode = self:Mode()
  if mode == "all" then return true end
  if mode == "worth" then return self:Verdict(id, trivial) ~= "skip" end
  return false
end

-- Auto-accept -------------------------------------------------------------
-- Each quest is tried once per 20 s (a full log must not make a loop).
local tried = {}
local function Try(id)
  if not id then return false end
  local t = tried[id]
  if t and Now() - t < 20 then return false end
  tried[id] = Now()
  return true
end
local function Skip()
  return QA:Mode() == "off" or (IsShiftKeyDown and IsShiftKeyDown()) or false
end

-- Every quest an NPC offers you is remembered as available (map pins).
function QA:NoteOffered()
  local W = PSS.QuestWorth
  if not (W and W.Offered) then return end
  local npc
  local guid = Plain(Call(UnitGUID, "npc"))
  if type(guid) == "string" then npc = tonumber((select(6, strsplit("-", guid)))) end
  local G = C_GossipInfo
  if G and G.GetAvailableQuests then
    for _, q in ipairs(Call(G.GetAvailableQuests) or {}) do W:Offered(Plain(q.questID), npc) end
  end
  local n = tonumber(Plain(Call(GetNumAvailableQuests))) or 0
  for i = 1, n do
    local id = Plain(select(5, Call(GetAvailableQuestInfo, i)))
    if id then W:Offered(id, npc) end
  end
end

function QA:OnGossip()
  pcall(self.NoteOffered, self)
  if Skip() then return end
  local G = C_GossipInfo
  if not (G and G.GetAvailableQuests and G.SelectAvailableQuest) then return end
  for _, q in ipairs(Call(G.GetAvailableQuests) or {}) do
    local id = Plain(q.questID)
    if id and self:Wanted(id, Plain(q.isTrivial)) and Try(id) then
      Call(G.SelectAvailableQuest, id)
      return id
    end
  end
end

function QA:OnGreeting()
  pcall(self.NoteOffered, self)
  if Skip() then return end
  local n = tonumber(Plain(Call(GetNumAvailableQuests))) or 0
  for i = 1, n do
    local trivial, _, _, _, id = Call(GetAvailableQuestInfo, i)
    id = Plain(id)
    if self:Wanted(id, Plain(trivial)) and Try(id or ("i" .. i)) then
      Call(SelectAvailableQuest, i)
      return id or true
    end
  end
end

function QA:OnDetail()
  local id = tonumber(Plain(Call(GetQuestID)))
  if id and PSS.QuestWorth and PSS.QuestWorth.Offered then
    local guid = Plain(Call(UnitGUID, "npc"))
    pcall(PSS.QuestWorth.Offered, PSS.QuestWorth, id, type(guid) == "string" and tonumber((select(6, strsplit("-", guid)))) or nil)
  end
  self:ShowRating(id)
  if Skip() or not id then return end
  if Plain(Call(QuestGetAutoAccept)) then return end
  if self:Wanted(id, false) then
    Call(AcceptQuest)
    return true
  end
end

-- Auto turn-in (own option, off by default) ----------------------------------
-- Finished quests are handed in at the NPC. When the quest offers a choice of
-- rewards the window stays open: the reward is always picked by the player.
-- Hold Shift at the NPC to skip.
function QA:TurnInOn() return DB().questTurnIn == true end
local function SkipTurnIn() return not QA:TurnInOn() or (IsShiftKeyDown and IsShiftKeyDown()) or false end

function QA:TurnInGossip()
  if SkipTurnIn() then return end
  local G = C_GossipInfo
  if not (G and G.GetActiveQuests and G.SelectActiveQuest) then return end
  for _, q in ipairs(Call(G.GetActiveQuests) or {}) do
    local id = Plain(q.questID)
    if id and Plain(q.isComplete) and Try("t" .. id) then
      Call(G.SelectActiveQuest, id)
      return id
    end
  end
end

function QA:TurnInGreeting()
  if SkipTurnIn() then return end
  local n = tonumber(Plain(Call(GetNumActiveQuests))) or 0
  for i = 1, n do
    local _, complete = Call(GetActiveTitle, i)
    local id = Plain(Call(GetActiveQuestID, i))
    if Plain(complete) and Try("t" .. tostring(id or i)) then
      Call(SelectActiveQuest, i)
      return id or true
    end
  end
end

function QA:OnProgress()
  if SkipTurnIn() then return end
  if Plain(Call(IsQuestCompletable)) then Call(CompleteQuest); return true end
end

function QA:OnComplete()
  if SkipTurnIn() then return end
  local choices = tonumber(Plain(Call(GetNumQuestChoices))) or 0
  if choices > 1 then return end -- you choose the reward
  Call(GetQuestReward, choices == 1 and 1 or nil)
  return true
end

-- Rating line under the quest window ----------------------------------------
function QA:ShowRating(id)
  if not (QuestFrame and self:MarksOn()) then return end
  local W = PSS.QuestWorth
  if not self.line then
    local f = CreateFrame("Frame", nil, QuestFrame)
    f:SetSize(340, 34)
    f:SetPoint("TOPLEFT", QuestFrame, "BOTTOMLEFT", 0, -2)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    f.bg:SetColorTexture(0, 0, 0, 0.75)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 8, 0)
    f.text:SetPoint("RIGHT", f, "RIGHT", -8, 0)
    f.text:SetJustifyH("LEFT")
    self.line = f
  end
  if not (id and W) then self.line:Hide(); return end
  local rate = W:Rate(id)
  self.line.text:SetText(PSS:Safe(W.HEX[rate.verdict] .. L("qw_" .. rate.verdict) .. "|r  " .. W:Summary(rate)))
  self.line:Show()
end

-- Marks in lists ----------------------------------------------------------------
local function MarkIcon(tex, verdict)
  if not (tex and tex.SetVertexColor) then return end
  local c = PSS.QuestWorth.COLORS[verdict]
  if verdict == "ok" then
    if tex.SetDesaturated then tex:SetDesaturated(false) end
    tex:SetVertexColor(1, 1, 1)
  else
    if tex.SetDesaturated then tex:SetDesaturated(true) end
    tex:SetVertexColor(c[1] * 1.2, c[2] * 1.2, c[3] * 1.2)
  end
end

local function MarkText(fs, title, verdict)
  if not (fs and fs.SetText and title) then return end
  if verdict == "skip" then fs:SetText("|cff8c8c8c" .. title .. "  (" .. L("qwSkipShort") .. ")|r")
  elseif verdict == "great" then fs:SetText(PSS.QuestWorth.HEX.great .. title .. "|r")
  end
end

-- Gossip list (modern ScrollBox and the classic GossipTitleButtonN buttons).
function QA:MarkGossip()
  if not self:MarksOn() then return end
  local panel = GossipFrame and GossipFrame.GreetingPanel
  local box = panel and panel.ScrollBox
  if box and box.ForEachFrame then
    pcall(box.ForEachFrame, box, function(btn)
      local d = btn.GetElementData and btn:GetElementData()
      local info = d and d.info
      local id = info and Plain(info.questID)
      if id and info.title and d.buttonType ~= nil and not Plain(info.isComplete) then
        local active = Plain(info.isOnQuest) or (PSS.QuestWorth and PSS.QuestWorth:InLog(id))
        if not active then
          local v = self:Verdict(id, Plain(info.isTrivial))
          MarkText(btn.GetFontString and btn:GetFontString() or btn.Text, info.title, v)
          MarkIcon(btn.Icon or btn.GossipQuestButtonIcon, v)
        end
      end
    end)
    return
  end
  local G = C_GossipInfo
  local avail = G and G.GetAvailableQuests and Call(G.GetAvailableQuests) or {}
  local n = 0
  for i = 1, 32 do
    local btn = _G["GossipTitleButton" .. i]
    if not btn then break end
    if btn:IsShown() and btn.type == "Available" then
      n = n + 1
      local q = avail[n]
      if q and q.questID then
        local v = self:Verdict(Plain(q.questID), Plain(q.isTrivial))
        MarkText(btn, Plain(q.title), v)
        MarkIcon(_G["GossipTitleButton" .. i .. "GossipIcon"] or btn.Icon, v)
      end
    end
  end
end

-- Greeting list (NPCs with several quests and no gossip).
function QA:MarkGreeting()
  if not self:MarksOn() then return end
  for i = 1, 32 do
    local btn = _G["QuestTitleButton" .. i]
    if not btn then break end
    if btn:IsShown() and btn.isActive == 0 then
      local index = btn:GetID()
      local trivial, _, _, _, id = Call(GetAvailableQuestInfo, index)
      id = Plain(id)
      if id then
        local title = Plain(Call(GetAvailableTitle, index))
        local v = self:Verdict(id, Plain(trivial))
        MarkText(btn, title, v)
        MarkIcon(btn.Icon or _G["QuestTitleButton" .. i .. "QuestIcon"], v)
      end
    end
  end
end

-- Quest log: titles in the modern log (QuestScrollFrame) and the classic one.
function QA:MarkLog()
  if not self:MarksOn() then return end
  local W = PSS.QuestWorth
  local pool = QuestScrollFrame and (QuestScrollFrame.titleFramePool or QuestScrollFrame.QuestTitlePool)
  if pool and pool.EnumerateActive then
    for btn in pool:EnumerateActive() do
      local id = Plain(btn.questID)
      local fs = btn.Text or btn.ButtonText
      if id and fs and fs.GetText then
        local v = W:Verdict(id)
        if v ~= "ok" then
          local c = W.COLORS[v]
          fs:SetTextColor(c[1], c[2], c[3])
        end
      end
    end
  end
  if GetQuestLogTitle then
    for i = 1, 40 do
      local btn = _G["QuestLogTitle" .. i]
      if not btn then break end
      local index = btn.GetID and btn:GetID()
      if index and btn:IsShown() then
        local r = Pack(pcall(GetQuestLogTitle, index))
        local title, isHeader, id = r[2], r[6], r[10]
        id = Plain(id)
        if r[1] and not isHeader and id and title then
          local v = W:Verdict(id)
          if v ~= "ok" then
            local c = W.COLORS[v]
            local fs = btn.GetFontString and btn:GetFontString() or btn.Text
            if fs and fs.SetTextColor then fs:SetTextColor(c[1], c[2], c[3]) end
          end
        end
      end
    end
  end
end

-- Hooks and events ------------------------------------------------------------------
local hooked = {}
local function Hook(owner, name, fn)
  local key = tostring(owner) .. name
  if hooked[key] then return end
  if owner == _G then
    if type(_G[name]) == "function" then PSS.HookSecure(name, fn); hooked[key] = true end
  elseif owner and type(owner[name]) == "function" then
    PSS.HookSecure(owner, name, fn); hooked[key] = true
  end
end

function QA:HookUI()
  Hook(GossipFrame, "Update", function() pcall(QA.MarkGossip, QA) end)
  Hook(_G, "GossipFrameUpdate", function() pcall(QA.MarkGossip, QA) end)
  Hook(_G, "QuestFrameGreetingPanel_OnShow", function() pcall(QA.MarkGreeting, QA) end)
  Hook(_G, "QuestLogQuests_Update", function() pcall(QA.MarkLog, QA) end)
  Hook(_G, "QuestLog_Update", function() pcall(QA.MarkLog, QA) end)
  if QuestFrame and QuestFrame.HookScript and not hooked.questHide then
    PSS.HookScript(QuestFrame, "OnHide", function() if QA.line then QA.line:Hide() end end)
    hooked.questHide = true
  end
end

local function After(fn)
  if C_Timer and C_Timer.After then C_Timer.After(0, fn) else fn() end
end

local ev = CreateFrame("Frame")
QA.frame = ev
for _, e in ipairs({"PLAYER_LOGIN", "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_LOG_UPDATE",
    "QUEST_PROGRESS", "QUEST_COMPLETE"}) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    QA:HookUI()
  elseif event == "GOSSIP_SHOW" then
    QA:HookUI()
    After(function() pcall(QA.MarkGossip, QA) end)
    if not QA:TurnInGossip() then QA:OnGossip() end
  elseif event == "QUEST_GREETING" then
    After(function() pcall(QA.MarkGreeting, QA) end)
    if not QA:TurnInGreeting() then QA:OnGreeting() end
  elseif event == "QUEST_PROGRESS" then
    QA:OnProgress()
  elseif event == "QUEST_COMPLETE" then
    QA:OnComplete()
  elseif event == "QUEST_DETAIL" then
    QA:OnDetail()
  elseif event == "QUEST_LOG_UPDATE" then
    After(function() pcall(QA.MarkLog, QA) end)
  end
end)
