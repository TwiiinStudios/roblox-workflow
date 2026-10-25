--[[
	Far-away stand-ins for the big captured models (buildings, trees, vehicles, towers...).

	    lune run tools/lod.luau          set LevelOfDetail = StreamingMesh on every model in FAR
	    lune run tools/lod.luau --check  only report the ones that aren't set (exit 1 if any)

	With StreamingEnabled the world streams in round each player; a model with LevelOfDetail StreamingMesh
	is drawn as Roblox's low-detail stand-in beyond the streaming radius instead of not at all, so the
	skyline doesn't pop in as you walk. A game script may not set it (it silently stays Disabled), so it's
	saved on the captured models themselves. Add each big model you'd see from far away to FAR (its name in
	assets/Captured/<Name>.rbxm) and run this again after re-capturing one of them.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Everything you'd see from far away (assets/Captured/<Name>.rbxm). Empty in a new game.
local FAR: { string } = {}

local checkOnly = table.find(process.args, "--check") ~= nil
local wrong = 0
for _, name in FAR do
	local path = `assets/Captured/{name}.rbxm`
	if not fs.isFile(path) then
		print(`[lod] {name}: no {path}`)
		wrong += 1
		continue
	end
	local roots = roblox.deserializeModel(fs.readFile(path))
	local changed = false
	for _, root in roots do
		if root:IsA("Model") and root.LevelOfDetail ~= roblox.Enum.ModelLevelOfDetail.StreamingMesh then
			if checkOnly then
				print(`[lod] {name}: not set`)
				wrong += 1
			else
				root.LevelOfDetail = roblox.Enum.ModelLevelOfDetail.StreamingMesh
				changed = true
			end
		end
	end
	if changed then
		fs.writeFile(path, roblox.serializeModel(roots))
		print(`[lod] {name}: set`)
	end
end
if checkOnly and wrong > 0 then
	process.exit(1)
end
print(`[lod] OK - {#FAR} models keep a far stand-in`)
