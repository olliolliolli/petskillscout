# Tools

- `build.sh` — syntax check, tests, then `dist/PetSkillScout-<version>.zip` (only the addon folder).
- `check.lua` — syntax check of Lua files.
- `tests/` — lua5.1 tests with a fake WoW client (`mock.lua`, `load.lua` loads the addon in `.toc` order).
  Run: `lua5.1 tools/tests/test_quests.lua "$PWD/PetSkillScout"`.
- `att/` — builds `PetSkillScout/QuestDB.lua` from the AllTheThings Forever database (MIT):

  ```
  git clone --depth 1 --filter=blob:none --sparse https://github.com/ATTWoWAddon/allthethings att-src
  git -C att-src sparse-checkout set --no-cone '/LICENSE*' '/.contrib/.db/forever/' '/.contrib/.db/shared/'
  cd tools/att && lua5.1 gen.lua ../../att-src/.contrib/.db ../../PetSkillScout/QuestDB.lua $(git -C ../../att-src rev-parse --short HEAD)
  ```

  Update the commit in `PetSkillScout/QuestDB-LICENSE.txt` afterwards.

- `att/genpets.lua` — builds `PetSkillScout/PetDataATT.lua` (teaching beasts, positions) from the same checkout:
  `cd tools/att && lua5.1 genpets.lua ../../att-src/.contrib/.db ../../PetSkillScout/PetDataATT.lua <commit>`.
  Positions are merged with the existing file, never dropped.
- `release.py` — uploads a built zip to CurseForge (token read from a local file).

Lua 5.1 without a package manager: `git clone --depth 1 --branch v5.1 https://github.com/lua/lua.git`,
then `gcc -O2 -DLUA_USE_POSIX -o lua5.1 lua.c $(ls *.c | grep -v -e '^lua.c$' -e '^luac.c$' -e print.c) -lm`.
