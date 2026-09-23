--[[
	Builds the generated part of the world when the server starts.

	Every ModuleScript in src/server/World/ is a builder that returns  function(parent: Folder).
	Builders run in name order during Init, before any player spawns, and put what they make
	into Workspace.Generated.

	Where world content lives:
	  - world/Map/*.model.json   static, hand-placed things (baseplate, spawn), visible in Studio edit mode
	  - src/server/World/*.luau   generated things (layouts, terrain, repeated props), built at runtime
	  - world/Map/Captured/       things made inside Studio and saved back with tools/capture.luau
]]

local Workspace = game:GetService("Workspace")

local WorldService = {}

function WorldService:Init(_services)
	local builders = script.Parent.Parent:WaitForChild("World"):GetChildren()
	table.sort(builders, function(a, b)
		return a.Name < b.Name
	end)

	local generated = Instance.new("Folder")
	generated.Name = "Generated"

	for _, module in builders do
		if module:IsA("ModuleScript") then
			local ok, err = pcall(function()
				local folder = Instance.new("Folder")
				folder.Name = module.Name
				require(module)(folder)
				folder.Parent = generated
			end)
			if not ok then
				warn(`[WorldService] builder {module.Name} failed: {err}`)
			end
		end
	end

	generated.Parent = Workspace
end

return WorldService
