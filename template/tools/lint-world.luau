--[==[
	Catches mistakes in hand-written world/asset files that Rojo would silently accept.

	    lune run tools/lint-world.luau

	Rules:
	  - *.model.json / *.meta.json must be valid JSON.
	  - "Position" / "Orientation" / "Rotation" are IGNORED by Rojo (the part ends up at 0,0,0).
	    Use the explicit CFrame form instead:
	      "CFrame": { "CFrame": { "position": [x, y, z], "orientation": [[1,0,0],[0,1,0],[0,0,1]] } }
	  - Nothing hand-written inside Captured/ folders (only tools/capture.luau writes there).
]==]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local IGNORED_PROPERTIES = { "Position", "Orientation", "Rotation" }
local problems = {}

local function checkNode(path: string, node: any)
	if type(node) ~= "table" then
		return
	end
	if type(node.properties) == "table" then
		for _, name in IGNORED_PROPERTIES do
			if node.properties[name] ~= nil then
				table.insert(problems, `{path}: "{name}" is ignored by Rojo - use "CFrame" (see tools/lint-world.luau)`)
			end
		end
	end
	if type(node.children) == "table" then
		for _, child in node.children do
			checkNode(path, child)
		end
	end
end

local function scan(dir: string)
	if not fs.isDir(dir) then
		return
	end
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			scan(path)
		elseif string.match(name, "%.json$") then
			if string.find(path, "/Captured/", 1, true) then
				table.insert(problems, `{path}: JSON inside a Captured folder - only tools/capture.luau writes there`)
				continue
			end
			local ok, decoded = pcall(serde.decode, "json", fs.readFile(path))
			if not ok then
				table.insert(problems, `{path}: invalid JSON - {decoded}`)
			else
				checkNode(path, decoded)
			end
		end
	end
end

scan("world")
scan("assets")

if #problems > 0 then
	for _, problem in problems do
		print(`  FAIL  {problem}`)
	end
	print(`\n[lint-world] {#problems} problem(s)`)
	process.exit(1)
end

print("[lint-world] OK")
