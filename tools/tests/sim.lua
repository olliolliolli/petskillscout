-- Offline release check: load the whole addon on the mock client, then drive it
-- the way a session does (login, events, timers, slash commands, every tab), with
-- default options and with every option on, out of and in combat. Any Lua error
-- or a pass slower than LIMIT ms is reported; exit code 1 if anything failed.
-- Usage (from repo root): lua5.1 tools/tests/sim.lua PetSkillScout
MOCK_TRACK_EARLY = true
dofile((arg[0]:match("(.*/)") or "") .. "load.lua")
local PSS = PetSkillScout
local LIMIT = 50
local errors, slow, seen = {}, {}, {}

local function try(what, fn, ...)
  local t = os.clock()
  local ok, e = pcall(fn, ...)
  local ms = (os.clock() - t) * 1000
  if not ok then
    local key = tostring(e)
    if not seen[key] then seen[key] = true; errors[#errors + 1] = what .. ": " .. key end
  elseif ms > LIMIT then
    slow[#slow + 1] = string.format("%s: %.0f ms", what, ms)
  end
end

local function timers() try("timers", MOCK.RunTimers) end
local EVENT_ARGS = {
  UNIT_PET = {"player"}, UNIT_AURA = {"player"}, UNIT_HEALTH = {"pet"}, UNIT_POWER_UPDATE = {"pet"},
  UNIT_HAPPINESS = {"pet"}, UNIT_LEVEL = {"pet"}, UNIT_MAXHEALTH = {"pet"}, ADDON_LOADED = {"PetSkillScout"},
  BAG_UPDATE = {0}, PLAYER_TARGET_CHANGED = {}, NAME_PLATE_UNIT_ADDED = {"nameplate1"},
  NAME_PLATE_UNIT_REMOVED = {"nameplate1"}, CHAT_MSG_ADDON = {"PSSNet1", "", "WHISPER", "Other"},
  QUEST_TURNED_IN = {123, 0, 0}, GET_ITEM_INFO_RECEIVED = {6948, true},
}
local function fireAll(tag)
  local names = {}
  for e in pairs(MOCK.events) do names[#names + 1] = e end
  table.sort(names)
  for _, e in ipairs(names) do
    try(tag .. " event " .. e, MOCK.Fire, e, unpack(EVENT_ARGS[e] or {}))
  end
  timers()
end
local function updates(tag)
  for _, f in ipairs(MOCK.track or {}) do
    local h = f.scripts and f.scripts.OnUpdate
    if h then try(tag .. " OnUpdate " .. tostring(f.name or f.pssKey or "?"), h, f, 0.5) end
  end
end
local CMDS = {"", "settings", "rares", "pet", "route", "ammo", "cdm", "plates", "inv diag", "gp tip",
  "chat diag", "holidays", "netlist", "roles", "cpu", "move", "move"}
local VIEWS = {"beasts", "pet", "rares", "route", "collection", "gear", "quests", "network", "settings"}
local function session(tag)
  try(tag .. " login", MOCK.Fire, "PLAYER_LOGIN")
  try(tag .. " enter", MOCK.Fire, "PLAYER_ENTERING_WORLD", true, false)
  timers()
  fireAll(tag)
  updates(tag)
  for _, c in ipairs(CMDS) do try(tag .. " /pss " .. c, SlashCmdList.PETSKILLSCOUT, c) end
  timers()
  if PSS.UI and PSS.UI.ShowView then
    for _, v in ipairs(VIEWS) do try(tag .. " view " .. v, PSS.UI.ShowView, PSS.UI, v) end
  end
  timers()
end

PetSkillScoutDB = {}
try("init", PSS.InitializeDB, PSS)
session("defaults")
-- Every boolean option on (theme, inventory, plates, ...).
for k, v in pairs(PetSkillScoutDB) do if v == false then PetSkillScoutDB[k] = true end end
for _, k in ipairs({"skinGame", "ownBags", "bagsUI", "plateStack", "skinPlates", "plateExtras"}) do PetSkillScoutDB[k] = true end
session("all-on")
-- Pet out, spells only in the modern spellbook API (as in Forever).
local oldExists = UnitExists
UnitExists = function(u) return u == "pet" or u == "player" end
UnitGUID = function(u) if u == "pet" then return "Pet-0-1-1-1-2042-0000" end end
local PETBOOK = {{"Growl", "Rank 1"}, {"Claw", "Rank 1"}, {"Cower", "Rank 1"}, {"Bite", "Rank 3"}}
C_SpellBook = C_SpellBook or {}
C_SpellBook.HasPetSpells = function() return #PETBOOK, "PET" end
C_SpellBook.GetSpellBookItemName = function(i, bank) local r = PETBOOK[i]; if r and bank == 1 then return r[1], r[2] end end
session("pet")
if PSS.MyPet and PSS.MyPet.Scan then
  try("pet scan", PSS.MyPet.Scan, PSS.MyPet)
  local got = {}
  for _, sp in ipairs(PSS.MyPet.spells or {}) do got[#got + 1] = sp.name .. " " .. tostring(sp.rank) end
  print("pet spells: " .. table.concat(got, ", "))
  local has = table.concat(got, ","):find("Bite 3") and table.concat(got, ","):find("Cower 1")
  if not has then errors[#errors + 1] = "pet scan: Cower 1 / Bite 3 not read from C_SpellBook" end
end
UnitExists = oldExists
MOCK.combat = true
session("combat")
MOCK.combat = false
fireAll("after-combat")

local ne,nu=0,0 for _ in pairs(MOCK.events) do ne=ne+1 end for _,f in ipairs(MOCK.track or {}) do if f.scripts and f.scripts.OnUpdate then nu=nu+1 end end
print(string.format("sim: %d events, %d OnUpdate frames, %d frames", ne, nu, #(MOCK.track or {})))
print(string.format("sim: %d errors, %d slow passes (>%d ms)", #errors, #slow, LIMIT))
for _, e in ipairs(errors) do print("ERROR " .. e) end
for _, s in ipairs(slow) do print("SLOW  " .. s) end
if #errors > 0 then os.exit(1) end
