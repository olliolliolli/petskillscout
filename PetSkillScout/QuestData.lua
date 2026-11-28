-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Hunter quests worth doing in WoW Forever: quest chains whose rewards are
-- strong for a hunter (ranged weapons, quivers / ammo pouches).
-- Quest giver, position, minimum level and faction come from PSS.QuestDB
-- (AllTheThings Forever database, MIT); the values here are only fallbacks.
-- Item IDs: wow-classic-items (MIT) and the ATT Forever item list.
-- Completion is never guessed: it is read from the game (quest flagged as
-- completed, or one of the rewards in your bags / bank).
--
-- Fields:
--   key     unique id (saved variables use it)
--   kind    "ranged" | "quiver"
--   quests  chain in order; the last one gives the reward
--   final   quests that count as "done" (default: the last of quests);
--           with quests of both factions, the one of your faction is used
--   items   reward choices (item IDs); inames: English fallback names
--   lvl, zone, side, npc   fallbacks when the quest is not in QuestDB
--   req     the reward can only be used from this level (optional)
--   tag     "group" | "elite" | "escort" | "dungeon" | "raid"
--   inst    instance for dungeon / raid tags
--   forever "new" (new in Forever) | "changed" (reward changed in Forever)
--   note    locale key of a short how-to line
--   unconfirmed  true when the quest is not (yet) in the Forever database
local PSS = PetSkillScout
PSS.QuestData = {
  -- Levels 6-20 --------------------------------------------------------------
  {key="skorn", kind="ranged", lvl=6, side="H", zone="Mulgore",
    name="The Demon Scarred Cloak", quests={770}, items={3079}, inames={[3079]="Skorn's Rifle"}},
  {key="centaurBracers", kind="ranged", lvl=9, side="H", zone="The Barrens",
    name="Centaur Bracers", quests={855}, items={5346}, inames={[5346]="Orcish Battle Bow"}},
  {key="daryl", kind="ranged", lvl=11, side="A", zone="Loch Modan",
    name="A Hunter's Boast", quests={257}, items={2903, 2904},
    inames={[2903]="Daryl's Hunting Bow", [2904]="Daryl's Hunting Rifle"}},
  {key="northwatch", kind="ranged", lvl=13, side="H", zone="The Barrens",
    name="The Guns of Northwatch", quests={891}, items={5309}, inames={[5309]="Privateer Musket"}},
  {key="vyrin", kind="quiver", lvl=15, side="A", zone="Loch Modan", tag="group",
    name="Vyrin's Revenge", quests={271, 531}, items={3573, 3574},
    inames={[3573]="Hunting Quiver", [3574]="Hunting Ammo Sack"}},
  {key="sleeper", kind="ranged", lvl=17, side="A", zone="Darkshore", tag="escort",
    name="The Sleeper Has Awakened", quests={5321}, items={15205}, inames={[15205]="Owlsight Rifle"}},
  {key="nightWatch", kind="quiver", lvl=18, side="A", zone="Duskwood",
    name="The Night Watch", quests={58}, items={3605, 3604},
    inames={[3605]="Quiver of the Night Watch", [3604]="Bandolier of the Night Watch"}},
  -- Levels 20-30 -------------------------------------------------------------
  {key="sacredFlame", kind="ranged", lvl=20, side="H", zone="Thousand Needles",
    name="The Sacred Flame", quests={1197}, items={6739}, inames={[6739]="Cliffrunner's Aim"}},
  {key="ormer", kind="ranged", lvl=22, side="A", zone="Wetlands",
    name="Ormer's Revenge", quests={296}, items={3493}, inames={[3493]="Raptor's End"}},
  {key="kraul", kind="ranged", lvl=29, zone="The Barrens",
    tag="dungeon", inst="Razorfen Kraul", forever="new",
    name="The Crone of the Kraul", quests={1101}, final={1101, 1102}, items={274084},
    inames={[274084]="Quilboar Blaster"}},
  {key="library", kind="ranged", lvl=30, req=40, zone="Stormwind City", forever="new", note="qNoteBooks", prereq="qBooks", prereqNote="qBooksNote",
    bySide={A={npc="Garion Wendell", zone="Stormwind City", x=49.0, y=86.3},
            H={npc="Owen Thadd", zone="Undercity", x=74.0, y=32.5}},
    name="Greater Friend of the Library", quests={82208}, items={277254}, inames={[277254]="Truthseeker's Bow"}},
  {key="reethe", kind="ranged", lvl=30, side="H", zone="Dustwallow Marsh", tag="escort",
    name="Questioning Reethe", quests={1273}, items={6798}, inames={[6798]="Blasting Hackbut"}},
  {key="kurzen", kind="ranged", lvl=30, side="A", zone="Stranglethorn Vale", tag="elite",
    name="Colonel Kurzen", quests={202}, items={4127}, inames={[4127]="Shrapnel Blaster"}},
  -- Levels 31-50 -------------------------------------------------------------
  {key="gizelton", kind="ranged", lvl=32, zone="Desolace", tag="escort",
    name="Gizelton Caravan", quests={5943}, items={15691}, inames={[15691]="Sidegunner Shottie"}},
  {key="nesingwary", kind="ranged", lvl=28, rec=38, zone="Stranglethorn Vale",
    tag="elite", forever="changed", note="qNoteNesingwary",
    name="Big Game Hunter", quests={208}, items={17686, 17687},
    inames={[17686]="Master Hunter's Bow", [17687]="Master Hunter's Rifle"}},
  {key="highland", kind="ranged", lvl=46, side="H", zone="The Hinterlands",
    name="Return to Primal Torntusk", quests={7847}, items={19114}, inames={[19114]="Highland Bow"}},
  {key="maraudon", kind="ranged", lvl=45, zone="Desolace", tag="dungeon", inst="Maraudon", unconfirmed=true,
    name="Corruption of Earth and Seed", quests={7064}, final={7064, 7065}, items={17753},
    inames={[17753]="Verdant Keeper's Aim"}},
  -- Levels 51-60 -------------------------------------------------------------
  {key="deathclasp", kind="ranged", lvl=54, zone="Silithus", tag="elite",
    name="Wanted - Deathclasp, Terror of the Sands", quests={8283}, items={20646},
    inames={[20646]="Sandstrider's Mark"}},
  {key="gorewood", kind="ranged", lvl=56, zone="Eastern Plaguelands",
    name="The Scarlet Oracle, Demetria", quests={6148}, final={6148, 6187}, items={16996},
    inames={[16996]="Gorewood Bow"}},
  {key="perfectPoison", kind="ranged", lvl=60, zone="Silithus",
    tag="raid", inst="Zul'Gurub, Ruins of Ahn'Qiraj", note="qNotePoison",
    name="The Perfect Poison", quests={9023}, items={22347}, inames={[22347]="Fahrad's Reloading Repeater"}},
  {key="lamina", kind="quiver", lvl=60, zone="Felwood",
    tag="raid", inst="Molten Core", note="qNoteLeaf",
    name="Ancient Sinew Wrapped Lamina", quests={7634}, items={18714},
    inames={[18714]="Ancient Sinew Wrapped Lamina"}},
  {key="rhokdelar", kind="ranged", lvl=60, zone="Felwood",
    tag="raid", inst="Molten Core", note="qNoteLeaf",
    name="Stave of the Ancients", quests={7635, 7636}, items={18713},
    inames={[18713]="Rhok'delar, Longbow of the Ancient Keepers"}},
}

-- uiMapIDs of the quest giver zones not covered by the beast database.
PSS.QuestZoneMaps = {
  ["Stormwind City"] = 1453, ["Undercity"] = 1458, ["Thunder Bluff"] = 1456,
  ["Ironforge"] = 1455, ["Orgrimmar"] = 1454, ["Darnassus"] = 1457,
}
