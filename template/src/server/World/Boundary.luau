--[[
	Example world builder: invisible walls around the baseplate so players can't fall off.
	Copy this file to make new builders (e.g. Pond.luau, Trees.luau, Shop.luau).
]]

local Create = require(game:GetService("ReplicatedStorage").Shared.Create)

local SIZE = 512 -- matches world/Map/Baseplate.model.json
local HEIGHT = 60
local THICKNESS = 2

return function(parent: Folder)
	local half = SIZE / 2
	local walls = {
		{ Vector3.new(0, HEIGHT / 2, half), Vector3.new(SIZE, HEIGHT, THICKNESS) },
		{ Vector3.new(0, HEIGHT / 2, -half), Vector3.new(SIZE, HEIGHT, THICKNESS) },
		{ Vector3.new(half, HEIGHT / 2, 0), Vector3.new(THICKNESS, HEIGHT, SIZE) },
		{ Vector3.new(-half, HEIGHT / 2, 0), Vector3.new(THICKNESS, HEIGHT, SIZE) },
	}

	for i, wall in walls do
		Create("Part", {
			Name = `Wall{i}`,
			Anchored = true,
			CanCollide = true,
			Transparency = 1,
			Size = wall[2],
			CFrame = CFrame.new(wall[1]),
			Parent = parent,
		})
	end
end
