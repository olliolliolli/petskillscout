-- Offline release check for RevUI (same idea as tools/tests/sim.lua for PSS):
-- load RevUI on the mock client in .toc order, then login, all events, timers,
-- OnUpdate, /revui commands; defaults, all options on, pet out, in combat.
-- Usage (repo root): lua5.1 tools/revui/sim.lua <dir with RevUI.toc>
MOCK_TRACK_EARLY = true
local here = arg[0]:match("(.*/)") or ""
dofile(here .. "../tests/mock.lua")
local dir = arg[1]
local ns = {}
local toc = io.open(dir .. "/RevUI.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
  if not line:match("^##") and line:match("%.lua$") then
    local chunk, err = loadfile(dir .. "/" .. line)
    if not chunk then print("LOAD FAIL " .. line .. ": " .. err); os.exit(1) end
    local ok, e = pcall(chunk, "RevUI", ns)
    if not ok then print("LOAD FAIL " .. line .. ": " .. tostring(e)); os.exit(1) end
  end
end
print("loaded all files")
local LIMIT, errors, slow, seen = 50, {}, {}, {}
local function try(what, fn, ...)
  local t = os.clock()
  local ok, e = pcall(fn, ...)
  local ms = (os.clock() - t) * 1000
  if not ok then
    local key = tostring(e)
    if not seen[key] then seen[key] = true; errors[#errors + 1] = what .. ": " .. key end
  elseif ms > LIMIT then slow[#slow + 1] = string.format("%s: %.0f ms", what, ms) end
end
local ARGS = {UNIT_PET = {"player"}, UNIT_AURA = {"player"}, UNIT_HEALTH = {"player"}, UNIT_POWER_UPDATE = {"player"},
  ADDON_LOADED = {"RevUI"}, NAME_PLATE_UNIT_ADDED = {"nameplate1"}, NAME_PLATE_UNIT_REMOVED = {"nameplate1"}, BAG_UPDATE = {0}}
local function session(tag)
  try(tag .. " addon", MOCK.Fire, "ADDON_LOADED", "RevUI")
  try(tag .. " login", MOCK.Fire, "PLAYER_LOGIN")
  try(tag .. " enter", MOCK.Fire, "PLAYER_ENTERING_WORLD", true, false)
  try(tag .. " timers", MOCK.RunTimers)
  local names = {}
  for e in pairs(MOCK.events) do names[#names + 1] = e end
  table.sort(names)
  for _, e in ipairs(names) do try(tag .. " event " .. e, MOCK.Fire, e, unpack(ARGS[e] or {})) end
  try(tag .. " timers", MOCK.RunTimers)
  for _, f in ipairs(MOCK.track or {}) do
    local h = f.scripts and f.scripts.OnUpdate
    if h then try(tag .. " OnUpdate " .. tostring(f.name or f.pssKey or "?"), h, f, 0.5) end
  end
  for _, c in ipairs({"", "move", "move", "cpu"}) do try(tag .. " /revui " .. c, SlashCmdList.REVUI, c) end
  try(tag .. " timers", MOCK.RunTimers)
end
RevUIDB = {}
session("defaults")
for k, v in pairs(RevUIDB) do if v == false then RevUIDB[k] = true end end
RevUIDB.ownBags, RevUIDB.bagsUI, RevUIDB.plateStack = true, true, true
RevUIDB.layoutScale = {minimap = 1.5, chat = 1.2}; RevUIDB.chatW, RevUIDB.chatH, RevUIDB.skinMinimapSize = 600, 300, 250
session("all-on")
UnitExists = function(u) return u == "pet" or u == "player" end
for _, cls in ipairs({"ROGUE", "DRUID", "WARLOCK", "MAGE"}) do
  UnitClass = function() return cls, cls, 1 end
  session("class " .. cls)
end
MOCK.combat = true
session("combat")
print("skin active:", tostring(RevUI.Skin and RevUI.Skin.active), "layout:", tostring(RevUI.Layout and RevUI.Layout.applied))
local ne, nu = 0, 0
for _ in pairs(MOCK.events) do ne = ne + 1 end
for _, f in ipairs(MOCK.track or {}) do if f.scripts and f.scripts.OnUpdate then nu = nu + 1 end end
print(string.format("sim: %d events, %d OnUpdate frames, %d frames", ne, nu, #(MOCK.track or {})))
print(string.format("sim: %d errors, %d slow passes (>%d ms)", #errors, #slow, LIMIT))
for _, e in ipairs(errors) do print("ERROR " .. e) end
for _, s in ipairs(slow) do print("SLOW  " .. s) end
if #errors > 0 then os.exit(1) end
