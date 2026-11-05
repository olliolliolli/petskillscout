-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- 3.0.3 strings: untrack a beast with a right click on its map pin.
local PSS = PetSkillScout
local NEW = {
  en = {untrackHint = "Right-click: stop tracking", untrackedPin = "No longer tracking %s."},
  uk = {untrackHint = "Правий клік: прибрати мітку", untrackedPin = "Мітку %s прибрано."},
  pl = {untrackHint = "Prawy klik: przestań śledzić", untrackedPin = "Nie śledzisz już: %s."},
  de = {untrackHint = "Rechtsklick: nicht mehr verfolgen", untrackedPin = "%s wird nicht mehr verfolgt."},
  fr = {untrackHint = "Clic droit : ne plus suivre", untrackedPin = "%s n'est plus suivi."},
  it = {untrackHint = "Clic destro: smetti di seguire", untrackedPin = "%s non è più seguito."},
  es = {untrackHint = "Clic derecho: dejar de seguir", untrackedPin = "Ya no sigues a %s."},
  pt = {untrackHint = "Clique direito: parar de seguir", untrackedPin = "Você não segue mais %s."},
  ru = {untrackHint = "Правый клик: убрать метку", untrackedPin = "Метка %s убрана."},
}
for lang, strings in pairs(NEW) do
  PSS.Locale[lang] = PSS.Locale[lang] or {}
  for key, value in pairs(strings) do PSS.Locale[lang][key] = value end
end
