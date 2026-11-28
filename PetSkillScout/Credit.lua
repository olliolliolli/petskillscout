-- Copyright (c) 2025-2026 DarthRev1. All rights reserved. See LICENSE.txt.
-- Once per new version: one chat line with the version and the author.
local PSS = PetSkillScout
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self)
  self:UnregisterAllEvents()
  if not PetSkillScoutDB then return end
  if PetSkillScoutDB.creditSeen == PSS.version then return end
  PetSkillScoutDB.creditSeen = PSS.version
  if C_Timer then C_Timer.After(6, function() PSS:Print(PSS:Credit()) end) end
end)
