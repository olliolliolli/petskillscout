#!/bin/sh
# Every offline check before a release: whole-addon simulation, behaviour
# tests of each feature, all unit tests, and the RevUI build + simulation.
# Usage (from repo root): sh tools/prerelease.sh
LUA="python ../scripts/lua51.py"
ADDON="$PWD/PetSkillScout"
fails=0
run() { # name, command...
  name=$1; shift
  out=$("$@" 2>&1)
  last=$(printf '%s\n' "$out" | grep -E "passed|errors" | tail -1)
  bad=$(printf '%s\n' "$out" | grep -E "^FAIL|^ERROR" )
  printf '%-22s %s\n' "$name" "$last"
  if [ -n "$bad" ]; then printf '%s\n' "$bad" | sed 's/^/    /'; fails=$((fails + 1)); fi
}
run "sim (whole addon)" $LUA tools/tests/sim.lua PetSkillScout
run "features" $LUA tools/tests/test_features.lua "$ADDON"
for t in tools/tests/test_*.lua; do
  n=$(basename "$t" .lua)
  [ "$n" = "test_features" ] && continue
  run "$n" $LUA "$t" "$ADDON"
done
PYTHONIOENCODING=utf-8 python tools/revui/build.py ../revui > /dev/null
run "revui sim" $LUA tools/revui/sim.lua ../revui/RevUI
echo "suites with failures: $fails"
