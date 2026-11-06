#!/bin/sh
# Run all checks and package dist/PetSkillScout-<version>.zip (only the addon folder).
set -e
cd "$(dirname "$0")/.."
LUA=${LUA:-lua5.1}
$LUA tools/check.lua PetSkillScout/*.lua
for t in test_smoke test_quests test_worth test_learn test_nettext test_holiday test_craft test_nav; do $LUA tools/tests/$t.lua "$PWD/PetSkillScout" | tail -1; done
VER=$(sed -n 's/^## Version: //p' PetSkillScout/PetSkillScout.toc | tr -d '\r')
mkdir -p dist
rm -f "dist/PetSkillScout-$VER.zip"
zip -qr -X "dist/PetSkillScout-$VER.zip" PetSkillScout
echo "dist/PetSkillScout-$VER.zip"
