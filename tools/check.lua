-- Syntax check: lua5.1 tools/check.lua PetSkillScout/*.lua
local bad = 0
for _, f in ipairs(arg) do
  local ok, err = loadfile(f)
  if not ok then print("ERR", err); bad = bad + 1 end
end
print(#arg .. " files, " .. bad .. " errors")
os.exit(bad == 0 and 0 or 1)
