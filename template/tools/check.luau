--[[
	Runs everything CI runs. Do this before you push:

	    lune run tools/check.luau          (checks only)
	    lune run tools/check.luau --fix    (auto-format first, then check)
]]

local process = require("@lune/process")

local fix = table.find(process.args, "--fix") ~= nil

local steps = {
	if fix
		then { "Format", "stylua", { "src", "tests", "tools" } }
		else { "Format check", "stylua", { "--check", "src", "tests", "tools" } },
	{ "Lint", "selene", { "src" } },
	{ "World files", "lune", { "run", "tools/lint-world.luau" } },
	{ "Unit tests", "lune", { "run", "tools/test.luau" } },
	{ "Build", "lune", { "run", "tools/build.luau" } },
}

for _, step in steps do
	local label, command, args = step[1], step[2], step[3]
	print(`\n=== {label} ===`)
	local result = process.exec(command, args, { stdio = "inherit" })
	if not result.ok then
		print(`\n[check] FAILED at "{label}".`)
		if label == "Format check" then
			print("Fix it automatically with: lune run tools/check.luau --fix")
		end
		process.exit(1)
	end
end

print("\n[check] All good - safe to push.")
