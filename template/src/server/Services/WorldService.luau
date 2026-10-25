--[[
	Builds the generated part of the world when the server starts.

	Every ModuleScript in src/server/World/ is a builder that returns  function(parent: Folder).
	Builders put what they make into Workspace.Generated.<builder name>.

	Two rounds, so the first player on a new server isn't kept waiting for the whole world:
	  - FIRST (during Init, before anyone spawns): the small things you need to spawn - the ground under
	    the spawn, the map's edge. Workspace.Generated appears with these in it.
	  - Then the rest (big or slow builders: scenery, props, terrain), one builder at a time just after
	    the server has started, each added to Generated as it's done. Code that needs one of these waits
	    for it (Generated:WaitForChild("Trees", ...)) rather than assuming it's there.
	When every builder has run, Generated gets the attribute Built = true (WorldService:WaitUntilBuilt).
	How long each builder took is printed and kept as Generated's attribute BuildSeconds<Name>.

	Where world content lives:
	  - world/Map/*.model.json   static, hand-placed things (baseplate, spawn), visible in Studio edit mode
	  - src/server/World/*.luau   generated things (layouts, terrain, repeated props), built at runtime
	  - world/Map/Captured/       things made inside Studio and saved back with tools/capture.luau
]]

local Workspace = game:GetService("Workspace")

-- Builders built FIRST (see above): everything a player needs to spawn. With StreamingEnabled their worlds
-- are also always sent whole (Persistent), so the ground is always under you and the client can look up
-- what's in them by name; the rest streams in around each player.
local FIRST = { Boundary = true }

local WorldService = {}
WorldService.FIRST = FIRST -- (read by tests/cloud/World.cloud.luau)

local generated: Folder? = nil

local function build(module: ModuleScript, into: Instance)
	local started = os.clock()
	local ok, err = pcall(function()
		-- A Model rather than a Folder, so it can say how it streams.
		local folder = Instance.new("Model")
		folder.Name = module.Name
		if FIRST[module.Name] then
			folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end
		require(module)(folder)
		folder.Parent = into
	end)
	if not ok then
		warn(`[WorldService] builder {module.Name} failed: {err}`)
	end
	local seconds = os.clock() - started
	into:SetAttribute(`BuildSeconds{module.Name}`, math.round(seconds * 1000) / 1000)
	return seconds
end

function WorldService:Init(_services)
	local builders = script.Parent.Parent:WaitForChild("World"):GetChildren()
	table.sort(builders, function(a, b)
		return a.Name < b.Name
	end)

	local folder = Instance.new("Folder")
	folder.Name = "Generated"
	generated = folder

	local first, rest = {}, {}
	for _, module in builders do
		if module:IsA("ModuleScript") then
			table.insert(if FIRST[module.Name] then first else rest, module)
		end
	end

	local started = os.clock()
	for _, module in first do
		build(module, folder)
	end
	folder.Parent = Workspace
	print(string.format("[WorldService] first builders done in %.2fs", os.clock() - started))

	-- The rest once the server is up (task.defer: after every service has started), a frame apart, so
	-- players' loading and spawning get a turn between builders.
	task.defer(function()
		local times = {}
		for _, module in rest do
			task.wait()
			table.insert(times, string.format("%s %.2fs", module.Name, build(module, folder)))
		end
		folder:SetAttribute("Built", true)
		print(`[WorldService] the rest built: {table.concat(times, ", ")}`)
	end)
end

-- Waits until every builder has run (at most `timeout` seconds). True when they all have.
function WorldService:WaitUntilBuilt(timeout: number?): boolean
	local limit = os.clock() + (timeout or math.huge)
	while not (generated and generated:GetAttribute("Built")) and os.clock() < limit do
		task.wait(0.1)
	end
	return generated ~= nil and generated:GetAttribute("Built") == true
end

return WorldService
