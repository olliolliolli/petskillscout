-- Skill route: the player picks skill ranks to learn ("Bite 6", "Dash 2"), the
-- addon picks a teaching beast for each one (tameable at the player's level,
-- reachable for the faction, with known spawn points) and orders the stops by
-- distance. Only directions are shown: nothing moves the character.
local PSS = PetSkillScout
PSS.Route = {}
local R = PSS.Route

local function DB()
  if not PetSkillScoutDB then return nil end
  PetSkillScoutDB.route = PetSkillScoutDB.route or {goals = {}}
  PetSkillScoutDB.route.goals = PetSkillScoutDB.route.goals or {}
  return PetSkillScoutDB.route
end

function R:Goals()
  local db = DB()
  return db and db.goals or {}
end

local function FindGoal(goals, ability, rank)
  for i, g in ipairs(goals) do
    if g.a == ability and tonumber(g.r) == tonumber(rank) then return i end
  end
end

-- Highest rank the hunter (or the active pet) is known to have for an ability.
function R:KnownRank(ability)
  local best = 0
  local known = PetSkillScoutDB and PetSkillScoutDB.knownRanks
  if known and tonumber(known[ability]) then best = tonumber(known[ability]) end
  local pet = PSS.MyPet
  if pet and pet.active then
    for _, s in ipairs(pet.spells or {}) do
      if s.key == ability and tonumber(s.rank) and s.rank > best then best = s.rank end
    end
  end
  return best
end

function R:IsDone(goal)
  return self:KnownRank(goal.a) >= tonumber(goal.r)
end

local function FactionOK(beast)
  local f = PSS.player and PSS.player.faction
  return not beast.faction or beast.faction == "All" or not f or f == "Unknown" or beast.faction == f
end

local function Located(beast)
  return beast.mapID and ((beast.spawnPoints and #beast.spawnPoints > 0) or beast.x)
end

-- All teaching beasts for ability + rank, best first. canTame: beast level <= player level.
function R:Candidates(ability, rank)
  local level = PSS.player and PSS.player.level or 60
  local here = PSS.Nav and { PSS.Nav:PlayerPos() } or {}
  local out = {}
  for _, b in ipairs(PSS.Beasts or {}) do
    if b.ability == ability and tonumber(b.rank) == tonumber(rank) and FactionOK(b) then
      local c = {beast = b, canTame = (b.minLevel or 1) <= level, located = Located(b) and true or false}
      if c.located and here[1] then
        local p = b.spawnPoints and b.spawnPoints[1] or {b.x, b.y}
        c.dist, c.otherContinent = PSS.Nav:DistanceTo(b.mapID, p[1], p[2], here)
      end
      table.insert(out, c)
    end
  end
  table.sort(out, function(x, y)
    if x.canTame ~= y.canTame then return x.canTame end
    if x.located ~= y.located then return x.located end
    if (x.otherContinent or false) ~= (y.otherContinent or false) then return not x.otherContinent end
    if x.dist and y.dist and x.dist ~= y.dist then return x.dist < y.dist end
    if (x.dist ~= nil) ~= (y.dist ~= nil) then return x.dist ~= nil end
    return (x.beast.minLevel or 0) > (y.beast.minLevel or 0)
  end)
  return out
end

-- Best rank of an ability that some tameable, located beast teaches right now.
function R:BestRank(ability)
  local level = PSS.player and PSS.player.level or 60
  local best
  for _, b in ipairs(PSS.Beasts or {}) do
    local r = tonumber(b.rank)
    if b.ability == ability and r and (b.minLevel or 1) <= level and FactionOK(b) and Located(b) then
      if not best or r > best then best = r end
    end
  end
  return best
end

function R:Add(ability, rank)
  local goals = self:Goals()
  rank = tonumber(rank)
  if not (ability and rank) or FindGoal(goals, ability, rank) then return false end
  -- A higher rank replaces lower ones of the same skill: one beast is enough.
  for i = #goals, 1, -1 do
    if goals[i].a == ability and tonumber(goals[i].r) < rank then table.remove(goals, i) end
  end
  for _, g in ipairs(goals) do
    if g.a == ability and tonumber(g.r) > rank then return false end
  end
  table.insert(goals, {a = ability, r = rank})
  self:Changed()
  return true
end

function R:Remove(index)
  local goals = self:Goals()
  if goals[index] then table.remove(goals, index) end
  self:Changed()
end

function R:Clear()
  local db = DB()
  if db then db.goals = {} end
  self:Changed()
end

-- Picks a different teaching beast for one goal (cycles through the candidates).
function R:NextChoice(goal)
  local list = self:Candidates(goal.a, goal.r)
  if #list < 2 then return end
  local idx = 1
  for i, c in ipairs(list) do if c.beast.id == goal.pick then idx = i break end end
  goal.pick = list[idx % #list + 1].beast.id
  self:Changed()
end

-- Adds the best available rank of every beast-taught skill the active pet's
-- family can use and does not know yet at that rank. Returns how many were added.
function R:FillFromPet()
  local pet = PSS.MyPet
  if pet and pet.Scan then pcall(pet.Scan, pet) end
  if not (pet and pet.active and pet.family) then return nil end
  local added = 0
  for _, key in ipairs(PSS.FamilySkills and PSS.FamilySkills[pet.family] or {}) do
    local info = PSS.Abilities and PSS.Abilities[key]
    if info and info.learn == "beast" then
      local best = self:BestRank(key)
      if best and best > self:KnownRank(key) and self:Add(key, best) then added = added + 1 end
    end
  end
  return added
end

-- Stops ---------------------------------------------------------------------
-- { goals = {goal,...}, beast, choices = n, dist, otherContinent, done, noBeast }
function R:Stops()
  local stops, byBeast = {}, {}
  for _, goal in ipairs(self:Goals()) do
    local done = self:IsDone(goal)
    local list = self:Candidates(goal.a, goal.r)
    local chosen
    for _, c in ipairs(list) do if c.beast.id == goal.pick then chosen = c break end end
    chosen = chosen or list[1]
    if chosen and chosen.located then
      local stop = byBeast[chosen.beast.npcID or chosen.beast.id]
      if not stop then
        stop = {goals = {}, beast = chosen.beast, choices = #list, dist = chosen.dist,
          otherContinent = chosen.otherContinent, canTame = chosen.canTame, done = true}
        byBeast[chosen.beast.npcID or chosen.beast.id] = stop
        table.insert(stops, stop)
      end
      table.insert(stop.goals, goal)
      stop.done = stop.done and done
    else
      table.insert(stops, {goals = {goal}, choices = #list, done = done, noBeast = true})
    end
  end
  return self:Order(stops)
end

local function StopPoint(stop)
  local b = stop.beast
  local p = b.spawnPoints and b.spawnPoints[1] or {b.x, b.y}
  return b.mapID, p[1], p[2]
end

-- Nearest-neighbour order from the player over the stops you can do now; beasts
-- above your level follow, finished and unreachable stops go to the end.
-- Other continents come after this one.
function R:Order(stops)
  local open, later, rest = {}, {}, {}
  for _, s in ipairs(stops) do
    if s.done or s.noBeast then table.insert(rest, s)
    elseif s.canTame then table.insert(open, s)
    else table.insert(later, s) end
  end
  table.sort(later, function(a, b) return (a.beast.minLevel or 0) < (b.beast.minLevel or 0) end)
  local ordered = {}
  local from = PSS.Nav and { PSS.Nav:PlayerPos() } or {}
  if not from[1] then from = nil end
  while #open > 0 do
    local bestI, bestScore
    for i, s in ipairs(open) do
      local score
      if from then
        local mapID, x, y = StopPoint(s)
        local d, other = PSS.Nav:DistanceTo(mapID, x, y, from)
        if d then score = d elseif other then score = 1e7 else score = 1e6 end
      else
        score = (s.beast.minLevel or 0)
      end
      if not bestScore or score < bestScore then bestI, bestScore = i, score end
    end
    local s = table.remove(open, bestI)
    table.insert(ordered, s)
    local mapID, x, y = StopPoint(s)
    from = {mapID, x / 100, y / 100}
  end
  for _, s in ipairs(later) do table.insert(ordered, s) end
  for _, s in ipairs(rest) do table.insert(ordered, s) end
  return ordered
end

function R:Target(stop)
  if not (stop and stop.beast and PSS.Nav) then return nil end
  local t = PSS.Nav:TargetFromBeast(stop.beast)
  if t then
    local parts = {}
    for _, g in ipairs(stop.goals) do table.insert(parts, PSS:NameAbility(g.a) .. " " .. g.r) end
    t.name = stop.beast.name .. " (" .. table.concat(parts, ", ") .. ")"
    t.route = true
  end
  return t
end

-- Arrow to the first unfinished stop. Returns the stop or nil.
function R:Go()
  for _, stop in ipairs(self:Stops()) do
    if not stop.done and not stop.noBeast then
      local t = self:Target(stop)
      if t and PSS.Nav then PSS.Nav:SetTarget(t) end
      self.active = true
      return stop
    end
  end
  self.active = false
  return nil
end

function R:Changed()
  -- Records the open goals (so a later rank-up is announced) and redraws the tab.
  if R.CheckProgress then pcall(R.CheckProgress) end
  if PSS.Minimap then PSS.Minimap:Refresh() end
end

-- Learned ranks ---------------------------------------------------------------
-- The Beast Training window lists every rank the hunter knows. Read it when it
-- opens (client permitting) so finished goals complete without an active pet.
local function ParseRank(text)
  if type(text) ~= "string" then return nil end
  local n = text:match("(%d+)")
  return n and tonumber(n)
end

local function LookupAbility(name)
  if type(name) ~= "string" then return nil end
  local n = name:lower():gsub("%s*%(.-%)", ""):gsub("^%s+", ""):gsub("%s+$", "")
  for key, info in pairs(PSS.Abilities or {}) do
    if key:lower() == n or (info.label and info.label:lower() == n) or PSS:NameAbility(key):lower() == n then return key end
  end
end

function R:ScanTraining()
  if type(GetNumCrafts) ~= "function" or type(GetCraftInfo) ~= "function" then return end
  local ok, count = pcall(GetNumCrafts)
  if not ok or type(count) ~= "number" or count == 0 then return end
  PetSkillScoutDB.knownRanks = PetSkillScoutDB.knownRanks or {}
  local known, changed = PetSkillScoutDB.knownRanks, false
  for i = 1, count do
    local ok2, name, sub, kind = pcall(GetCraftInfo, i)
    if ok2 and kind ~= "header" then
      local key, rank = LookupAbility(name), ParseRank(sub)
      if key and rank and rank > (tonumber(known[key]) or 0) then known[key] = rank; changed = true end
    end
  end
  if changed then self:Changed() end
end

local lastOpen
local function CheckProgress()
  if not (PetSkillScoutDB and PetSkillScoutDB.route) then return end
  local goals = R:Goals()
  local open, remaining, finished = {}, 0, false
  for _, g in ipairs(goals) do
    local key = g.a .. "#" .. g.r
    if R:IsDone(g) then
      if lastOpen and lastOpen[key] then
        finished = true
        PetSkillScoutDB.routeLearned = (PetSkillScoutDB.routeLearned or 0) + 1
      end
    else
      open[key] = true
      remaining = remaining + 1
    end
  end
  if finished then
    PSS:Print(string.format(PSS:L("routeStepDone"), #goals - remaining, #goals))
    -- Point the arrow at the next stop when the route arrow was in use.
    if R.active and PSS.Nav and (not PSS.Nav.target or PSS.Nav.target.route) then
      if not R:Go() then PSS.Nav:ClearTarget(); PSS:Print(PSS:L("routeFinished")) end
    end
  end
  lastOpen = open
  if PSS.UI and PSS.UI.view == "route" and PSS.UI.UpdateRoute then PSS.UI:UpdateRoute() end
end
R.CheckProgress = CheckProgress

R.frame = CreateFrame("Frame")
for _, e in ipairs({"CRAFT_SHOW", "CRAFT_UPDATE", "UNIT_PET", "PET_BAR_UPDATE", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD"}) do
  pcall(R.frame.RegisterEvent, R.frame, e)
end
local pending = 0
R.frame:Hide()
R.frame:SetScript("OnUpdate", function(self, elapsed)
  pending = pending - (elapsed or 0)
  if pending > 0 then return end
  self:Hide()
  pcall(CheckProgress)
end)
R.frame:SetScript("OnEvent", function(self, event)
  if event == "CRAFT_SHOW" or event == "CRAFT_UPDATE" then pcall(R.ScanTraining, R) end
  -- MyPet rescans 0.2 s after pet events; check after that.
  pending = 0.6
  self:Show()
end)
R.frame.pssKey = "Route"
PSS:Every(R.frame, 0.2)
