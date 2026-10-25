--[[
	Cloud spec: the performance budget of the running server (src/shared/PerfBudget.luau, LIVE): the world
	after every builder ran, which tools/budget.luau can't see in the place file.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PerfBudget = require(ReplicatedStorage.Shared.PerfBudget)

local function measure()
	local meshes, parts = {}, 0
	local distinct = 0
	local function scan(root: Instance)
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and root == Workspace then
				parts += 1
			end
			local id = if d:IsA("MeshPart") then d.MeshId elseif d:IsA("SpecialMesh") then d.MeshId else nil
			if id and id ~= "" and not meshes[id] then
				meshes[id] = true
				distinct += 1
			end
		end
	end
	scan(Workspace)
	scan(ReplicatedStorage)
	return { meshes = distinct, parts = parts }
end

return {
	["the running world stays within the performance budget"] = function(ctx)
		ctx.services.WorldService:WaitUntilBuilt(25) -- (most builders run just after the server starts)
		local numbers = measure()
		print(`[budget] running world: {numbers.meshes} distinct meshes, {numbers.parts} parts in Workspace`)
		for key, limit in PerfBudget.LIVE do
			assert(
				numbers[key] <= limit,
				`{PerfBudget.LABELS[key]}: {numbers[key]}, over the limit of {limit} (src/shared/PerfBudget.luau)`
			)
		end
	end,
}
