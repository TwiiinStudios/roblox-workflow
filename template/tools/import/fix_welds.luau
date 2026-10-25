--[[
	Marks every WeldConstraint in the given .rbxm files as Studio leaves a working one (State 1).

	A weld made by a Lune tool (tools/import/build_rig.luau) is saved with State 3. Studio fixes that up
	when it loads the model, so it looked right in Studio, but a place published straight from the
	files (tools/publish.luau) kept State 3, and online every character's welded pieces fell apart
	(in another of our games). The version Studio had saved had State 1 on the same welds.

	Usage: lune run tools/import/fix_welds.luau assets/Captured/MyRig.rbxm [...]
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

for _, path in process.args do
	local roots = roblox.deserializeModel(fs.readFile(path))
	local fixed = 0
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if d:IsA("WeldConstraint") and (d :: any).State ~= 1 then
				(d :: any).State = 1
				fixed += 1
			end
		end
	end
	fs.writeFile(path, roblox.serializeModel(roots))
	print(`[fix_welds] {path}: {fixed} welds`)
end
