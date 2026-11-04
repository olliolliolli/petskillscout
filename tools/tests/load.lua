-- Load the addon in .toc order.
local dir = arg[1]
dofile((arg[0]:match("(.*/)") or "") .. "mock.lua")
local ns = {}
local toc = io.open(dir .. "/PetSkillScout.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
  if not line:match("^##") and line:match("%.lua$") then
    local chunk, err = loadfile(dir .. "/" .. line)
    if not chunk then error(err) end
    local ok, e = pcall(chunk, "PetSkillScout", ns)
    if not ok then print("LOAD FAIL " .. line .. ": " .. tostring(e)); os.exit(1) end
  end
end
print("loaded all files")
