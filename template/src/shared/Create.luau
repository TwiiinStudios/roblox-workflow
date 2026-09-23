--[[
	Tiny helper for building instances (parts, models, UI) in code.

		local part = Create("Part", {
			Name = "Lilypad",
			Size = Vector3.new(6, 0.4, 6),
			CFrame = CFrame.new(10, 1, 0),
			Anchored = true,
			Parent = workspace,
		})

		local gui = Create("ScreenGui", { Name = "ShopGui", ResetOnSpawn = false }, {
			Create("Frame", { Size = UDim2.fromScale(0.3, 0.5), Position = UDim2.fromScale(0.35, 0.25) }, {
				Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Create("TextLabel", { Text = "Shop", Size = UDim2.fromScale(1, 0.15) }),
			}),
		})
		gui.Parent = player.PlayerGui

	Parent is always set last, after all other properties and children (faster, fewer replication events).
]]

local function Create(className: string, properties: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil

	for key, value in properties or {} do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end

	for _, child in children or {} do
		child.Parent = instance
	end

	if parent then
		instance.Parent = parent
	end
	return instance
end

return Create
