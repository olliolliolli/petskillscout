-- Data policy:
-- "community" means third-party Forever database / guide; see README for limitations.
-- No coordinate has been fabricated. Unknown coordinates are nil and cannot create a map pin.
--
-- Family names are the English client names returned by UnitCreatureFamily()
-- (Scorpid, Tallstrider, Wind Serpent, Crocolisk). Other spellings are mapped
-- through PSS:CanonicalFamily().
--
-- learn = "beast"   taught by taming a wild teaching beast (see Database.lua)
--         "family"  new Forever family ability; no wild teaching beasts are known,
--                   community sources list it per family and pet level only
--         "trainer" learned from the Pet Trainer
local PSS = PetSkillScout
PSS.Abilities = {
  Bite = {label="Bite", kind="shared", learn="beast", note="Direct damage; learnable ranks depend on the pet family."},
  Claw = {label="Claw", kind="shared", learn="beast", note="Direct damage; learnable ranks depend on the pet family."},
  Growl = {label="Growl", kind="trainer", learn="trainer", note="Pet Trainer ability; available to all pets."},
  Cower = {label="Cower", kind="shared", learn="beast", note="Threat reduction / defensive utility."},
  Dash = {label="Dash", kind="shared", learn="beast", note="Ground-pet movement speed."},
  Dive = {label="Dive", kind="shared", learn="beast", note="Flying-pet movement speed."},
  Prowl = {label="Prowl", kind="family", family="Cat", learn="beast", note="Cat family signature ability."},
  Screech = {label="Demoralizing Screech", kind="family", family="Carrion Bird", learn="beast", note="Carrion Bird family signature ability in Forever."},
  ["Furious Howl"] = {label="Furious Howl", kind="family", family="Wolf", learn="beast", note="Wolf family signature ability in Forever."},
  ["Lightning Breath"] = {label="Lightning Breath", kind="family", family="Wind Serpent", learn="beast", note="Wind Serpent family signature ability."},
  ["Scorpid Poison"] = {label="Scorpid Poison", kind="family", family="Scorpid", learn="beast", note="Scorpid family signature ability in Forever."},
  ["Shell Shield"] = {label="Shell Shield", kind="family", family="Turtle", learn="beast", note="Turtle family signature ability in Forever."},
  Charge = {label="Charge", kind="family", family="Boar", learn="beast", note="Boar family signature ability."},
  Thunderstomp = {label="Thunderstomp", kind="family", family="Gorilla", learn="beast", note="Gorilla family signature ability."},
  ["Sonic Blast"] = {label="Sonic Blast", kind="family", family="Bat", learn="family", note="New Bat family ability in Forever."},
  Web = {label="Web", kind="family", family="Spider", learn="family", note="New Spider family ability in Forever."},
  Pinch = {label="Pinch", kind="family", family="Crab", learn="family", note="New Crab family ability in Forever."},
  Dismember = {label="Dismember", kind="family", family="Crocolisk", learn="family", note="New Crocolisk family ability in Forever."},
  ["Savage Rend"] = {label="Savage Rend", kind="family", family="Raptor", learn="family", note="New Raptor family ability in Forever."},
  ["Dust Cloud"] = {label="Dust Cloud", kind="family", family="Tallstrider", learn="family", note="New Tallstrider family ability in Forever."},
  ["Tendon Rip"] = {label="Tendon Rip", kind="family", family="Hyena", learn="family", note="New Hyena family ability in Forever."},
  ["Mine!"] = {label="Mine!", kind="family", family="Bird of Prey", learn="family", note="New Bird of Prey family ability (family renamed from Owl)."},
  ["Trickster's Dance"] = {label="Trickster's Dance", kind="family", family="Fox", learn="family", note="New Fox family ability."},
  Swipe = {label="Swipe", kind="family", family="Bear", learn="family", note="New Bear family ability in Forever."},
  ["Lava Breath"] = {label="Lava Breath", kind="family", family="Core Hound", learn="family", note="Core Hound family ability; no tameable Core Hounds are listed in the beta data."},
}

PSS.Families = {
  "Bat","Bear","Bird of Prey","Boar","Carrion Bird","Cat","Core Hound","Crab","Crocolisk","Fox",
  "Gorilla","Hyena","Raptor","Scorpid","Spider","Tallstrider","Turtle","Wind Serpent","Wolf"
}

-- Shared and signature abilities per family (Warcraft Tavern family guide).
-- Growl comes from the Pet Trainer and is available to every family.
PSS.FamilySkills = {
  Bat={"Sonic Blast","Bite","Dive","Cower","Growl"},
  Bear={"Swipe","Bite","Claw","Dash","Cower","Growl"},
  ["Bird of Prey"]={"Mine!","Claw","Dive","Cower","Growl"},
  Boar={"Charge","Bite","Dash","Cower","Growl"},
  ["Carrion Bird"]={"Screech","Bite","Claw","Dive","Cower","Growl"},
  Cat={"Prowl","Bite","Claw","Dash","Cower","Growl"},
  ["Core Hound"]={"Lava Breath","Bite","Cower","Growl"},
  Crab={"Pinch","Claw","Dash","Cower","Growl"},
  Crocolisk={"Dismember","Bite","Dash","Cower","Growl"},
  Fox={"Trickster's Dance","Bite","Dash","Cower","Growl"},
  Gorilla={"Thunderstomp","Bite","Dash","Cower","Growl"},
  Hyena={"Tendon Rip","Bite","Dash","Cower","Growl"},
  Raptor={"Savage Rend","Bite","Claw","Dash","Cower","Growl"},
  Scorpid={"Scorpid Poison","Claw","Dash","Cower","Growl"},
  Spider={"Web","Bite","Dash","Cower","Growl"},
  Tallstrider={"Dust Cloud","Bite","Dash","Cower","Growl"},
  Turtle={"Shell Shield","Bite","Dash","Cower","Growl"},
  ["Wind Serpent"]={"Lightning Breath","Bite","Dive","Cower","Growl"},
  Wolf={"Furious Howl","Bite","Dash","Cower","Growl"},
}

-- Rank tables: required pet level and training points (tp; nil = not published).
-- Source: mmonster WoW Forever pet ability table (updated 2026-10-03, beta data).
local SRC = "mmonster Forever pet ability table (beta, 2026-10-03)"
local function Ranks(levels, points, extra)
  local out = {}
  for i, level in ipairs(levels) do
    out[i] = {petLevel=level, tp=points and points[i] or nil, source=SRC, confidence="community"}
    if extra and extra[i] then for k, v in pairs(extra[i]) do out[i][k] = v end end
  end
  return out
end
local STD8 = {1,8,16,24,32,40,48,56}
local TP8 = {1,4,7,10,13,17,21,25}
local NEW5 = {12,24,36,48,60}
PSS.Ranks = {
  Bite = Ranks(STD8, TP8, {
    {damage="7–9"},{damage="16–18"},{damage="24–28"},{damage="31–37"},
    {damage="40–48"},{damage="49–59"},{damage="66–80"},{damage="81–99"}}),
  Claw = Ranks(STD8, TP8),
  Charge = Ranks({1,12,24,36,48,60}, {5,9,13,17,21,25}),
  Cower = Ranks({5,15,25,35,45,55}, {8,10,12,14,16,18}),
  Dash = Ranks({30,40,50}, {15,20,25}),
  Dive = Ranks({30,40,50}, {15,20,25}),
  Prowl = Ranks({30,40,50}, {15,20,25}),
  Screech = Ranks({8,24,48,56}, {10,15,20,25}),
  ["Furious Howl"] = Ranks({10,24,40,56}, {10,15,20,25}),
  ["Lightning Breath"] = Ranks({1,12,24,36,48,60}, {1,5,10,15,20,25}),
  ["Scorpid Poison"] = Ranks({8,24,40,56}, {10,15,20,25}),
  ["Shell Shield"] = Ranks({20}, {15}),
  Thunderstomp = Ranks({30,40,50,60}, {15,20,25}),
  Growl = Ranks({1,10,20,30,40,50,60}, {0,0,0,0,0,0,0}),
  ["Sonic Blast"] = Ranks(NEW5),
  Web = Ranks(NEW5, {0,0,0,0,0}),
  Pinch = Ranks(NEW5, {0,0,0,0,0}),
  Dismember = Ranks(NEW5, {1,1,1,1,1}),
  ["Savage Rend"] = Ranks(NEW5, {0,0,0,0,0}),
  ["Dust Cloud"] = Ranks(NEW5, {0,0,0,0,0}),
  ["Tendon Rip"] = Ranks(NEW5, {0,0,0,0,0}),
  Swipe = Ranks(NEW5, {0,0,0,0,0}),
  ["Mine!"] = Ranks({10,20,30,40,50}, {0,0,0,0,0}),
  ["Trickster's Dance"] = Ranks({20}, {10}),
  ["Lava Breath"] = Ranks({48}, {0}),
}

-- Old spellings used by earlier builds, Classic or community data.
local FAMILY_ALIASES = {
  ["scorpion"]="Scorpid", ["tall strider"]="Tallstrider", ["cloud serpent"]="Wind Serpent",
  ["crocilisk"]="Crocolisk", ["owl"]="Bird of Prey", ["serpent"]="Wind Serpent",
}
local familyLookup
-- Maps an English or translated family name (client or saved data) to the
-- canonical key used by the database. Unknown names are returned unchanged.
function PSS:CanonicalFamily(name)
  if type(name) ~= "string" or name == "" then return name end
  if not familyLookup then
    familyLookup = {}
    for _, family in ipairs(self.Families) do familyLookup[family:lower()] = family end
    for alias, family in pairs(FAMILY_ALIASES) do familyLookup[alias] = family end
    for _, dict in pairs(self.Locale or {}) do
      for family, translated in pairs(dict.familyNames or {}) do
        local canonical = familyLookup[family:lower()] or family
        familyLookup[translated:lower()] = canonical
      end
    end
  end
  return familyLookup[name:lower()] or name
end

-- Pet diet per family (Forever client data via mmonster). Food types as in Foods.lua:
-- 1 meat, 2 fish, 3 cheese, 4 bread, 5 fungus, 6 fruit.
PSS.FamilyDiet = {
  Bat={5,6}, Bear={1,2,3,4,5,6}, ["Bird of Prey"]={1}, Boar={1,2,3,4,5,6},
  ["Carrion Bird"]={1,2}, Cat={1,2}, Crab={2,4,5,6}, Crocolisk={1,2}, Fox={1},
  Gorilla={5,6}, Hyena={1,6}, Raptor={1}, Scorpid={1}, Spider={1},
  Tallstrider={3,5,6}, Turtle={2,5,6}, ["Wind Serpent"]={2,3,4}, Wolf={1},
  ["Core Hound"]={1},
}
