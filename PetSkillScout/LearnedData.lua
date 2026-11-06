-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Data learned in game by PetSkillScout users (own observations), built by tools/learned.lua.
-- Quests: giver and rewards; vendors: ammo vendors; rares: places rares were seen.
PetSkillScout.LearnedData = {
quests = {
  [2159] = {n = "Dolanaar Delivery", g = nil, gn = nil, f = "A", m = nil, x = nil, y = nil, i = {2070, 159}},
  [4161] = {n = "Recipe of the Kaldorei", g = nil, gn = nil, f = "A", m = nil, x = nil, y = nil, i = {5482, 5472}},
  [918] = {n = "Timberling Seeds", g = nil, gn = nil, f = "A", m = nil, x = nil, y = nil, i = {4604}},
  [947] = {n = "Cave Mushrooms", g = 3583, gn = "Barithras Moonshade", f = "A", m = 1439, x = 37.4, y = 43.6, i = {5610, 4605}},
},
vendors = {
  [1686] = {n = "Irene Sureshot", m = 1432, x = 83, y = 63.2, k = "b", z = "Loch Modan"},
  [1687] = {n = "Cliff Hadin", m = 1432, x = 83, y = 63.1, k = "a", z = "Loch Modan"},
  [3587] = {n = "Lyrai", m = 1438, x = 59.5, y = 41, k = "ab", z = "Teldrassil"},
  [3589] = {n = "Keina", m = 1438, x = 59.3, y = 41.1, k = "a", z = "Teldrassil"},
  [3610] = {n = "Jeena Featherbow", m = 1438, x = 55.9, y = 59.1, k = "a", z = "Teldrassil"},
  [4182] = {n = "Dalmond", m = 1439, x = 37.4, y = 40.5, k = "ab", z = "Darkshore"},
  [491] = {n = "Quartermaster Lewis", m = 1436, x = 56.9, y = 47.1, k = "ab", z = nil},
},
rares = {
  ["Duskstalker"] = {npc = 0, {m = 1439, x = 37.5, y = 43.4}},
  ["Ghostfang"] = {npc = 0, {m = 1426, x = 80.5, y = 42.9}},
  ["Nightscreech"] = {npc = 0, {m = 1438, x = 51.5, y = 49.7}},
},
}
