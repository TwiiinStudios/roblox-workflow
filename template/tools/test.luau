--[[
	Runs every tests/**/*.spec.luau file.

	    lune run tools/test.luau

	A spec file returns a table of  ["what it should do"] = function() ... end.
	Use assert() inside. Only pure modules (no game:GetService, no Instance) can be
	required from tests - keep game logic/math in such modules so it can be tested.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failed = 0, 0

local function runDir(dir: string)
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			runDir(path)
		elseif string.match(name, "%.spec%.luau$") then
			local modulePath = "../" .. string.gsub(path, "%.luau$", "")
			local loaded, spec = pcall(require, modulePath)
			if not loaded then
				failed += 1
				print(`  FAIL  {path} (could not load)\n        {spec}`)
				continue
			end
			for testName, fn in spec do
				local ok, err = pcall(fn)
				if ok then
					passed += 1
					print(`  pass  {path} > {testName}`)
				else
					failed += 1
					print(`  FAIL  {path} > {testName}\n        {err}`)
				end
			end
		end
	end
end

if fs.isDir("tests") then
	runDir("tests")
end

print(`\n[test] {passed} passed, {failed} failed`)
if failed > 0 then
	process.exit(1)
end
