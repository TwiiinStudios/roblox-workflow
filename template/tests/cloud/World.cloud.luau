--[[
	Cloud spec (run by tools/cloudtest.luau on a Roblox cloud server, not by Lune): the server's world
	after it has started. Each test gets ctx = { services, generated }.
	Add a spec file per feature when an engine check helps (tests/cloud/<Name>.cloud.luau, a table of
	["what it should do"] = function(ctx) ... end); stand-in players: tests/cloud/helpers/StandIn.luau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Builders that only shape the terrain and make no parts of their own (e.g. { Hills = true }).
local TERRAIN_ONLY: { [string]: boolean } = {}

-- The builders a player needs to spawn (WorldService's FIRST) together may take this long (seconds):
-- a new server's first player waits for them.
local FIRST_MAX = 3

return {
	["every world builder builds something"] = function(ctx)
		assert(ctx.generated, "Workspace.Generated is missing")
		assert(ctx.services.WorldService:WaitUntilBuilt(25), "the world isn't finished building")
		for _, builder in ServerScriptService.Server.World:GetChildren() do
			local built = ctx.generated:FindFirstChild(builder.Name)
			assert(built, `Generated.{builder.Name} is missing (did the builder fail?)`)
			assert(TERRAIN_ONLY[builder.Name] or #built:GetDescendants() > 0, `Generated.{builder.Name} is empty`)
		end
	end,

	["the world builds quickly"] = function(ctx)
		assert(ctx.services.WorldService:WaitUntilBuilt(25), "the world isn't finished building")
		local times, first = {}, 0
		for _, builder in ServerScriptService.Server.World:GetChildren() do
			local seconds = ctx.generated:GetAttribute(`BuildSeconds{builder.Name}`)
			assert(type(seconds) == "number", `no build time for {builder.Name}`)
			table.insert(times, `{builder.Name} {seconds}s`)
			if ctx.services.WorldService.FIRST[builder.Name] then
				first += seconds
			end
		end
		table.sort(times)
		print(`[World] build times: {table.concat(times, ", ")}`)
		assert(first <= FIRST_MAX, `the spawn builders took {first}s (at most {FIRST_MAX})`)
	end,

	["every remote exists"] = function()
		local Remotes = require(ReplicatedStorage.Shared.Remotes)
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		assert(folder, "no ReplicatedStorage.Remotes")
		for name, remote in Remotes do
			if typeof(remote) == "Instance" then -- (Remotes.serve / simulate are functions)
				assert(remote.Parent == folder, `remote {name} isn't in ReplicatedStorage.Remotes`)
			end
		end
	end,
}
