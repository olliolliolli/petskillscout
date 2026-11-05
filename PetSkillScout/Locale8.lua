-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- 3.0.3 strings: untrack a beast with a right click on its map pin.
local PSS = PetSkillScout
local NEW = {
  en = {netVerUnknown = "no data yet (older version?)", untrackHint = "Right-click: stop tracking", untrackedPin = "No longer tracking %s."},
  uk = {netVerUnknown = "ще без даних (стара версія?)", untrackHint = "Правий клік: прибрати мітку", untrackedPin = "Мітку %s прибрано."},
  pl = {netVerUnknown = "brak danych (starsza wersja?)", untrackHint = "Prawy klik: przestań śledzić", untrackedPin = "Nie śledzisz już: %s."},
  de = {netVerUnknown = "noch keine Daten (ältere Version?)", untrackHint = "Rechtsklick: nicht mehr verfolgen", untrackedPin = "%s wird nicht mehr verfolgt."},
  fr = {netVerUnknown = "pas encore de données (ancienne version ?)", untrackHint = "Clic droit : ne plus suivre", untrackedPin = "%s n'est plus suivi."},
  it = {netVerUnknown = "nessun dato (versione vecchia?)", untrackHint = "Clic destro: smetti di seguire", untrackedPin = "%s non è più seguito."},
  es = {netVerUnknown = "sin datos aún (¿versión antigua?)", untrackHint = "Clic derecho: dejar de seguir", untrackedPin = "Ya no sigues a %s."},
  pt = {netVerUnknown = "sem dados ainda (versão antiga?)", untrackHint = "Clique direito: parar de seguir", untrackedPin = "Você não segue mais %s."},
  ru = {netVerUnknown = "пока нет данных (старая версия?)", untrackHint = "Правый клик: убрать метку", untrackedPin = "Метка %s убрана."},
}
for lang, strings in pairs(NEW) do
  PSS.Locale[lang] = PSS.Locale[lang] or {}
  for key, value in pairs(strings) do PSS.Locale[lang][key] = value end
end
