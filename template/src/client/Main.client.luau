--[[
	Client entry point.

	Loads every ModuleScript in Controllers/, calls :Init(controllers) on each, then :Start() on each.
	To add a client system, create a new file in src/client/Controllers/.
]]

local Controllers = script.Parent:WaitForChild("Controllers")

local controllers = {}
for _, module in Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		controllers[module.Name] = require(module)
	end
end

for _, controller in controllers do
	if controller.Init then
		controller:Init(controllers)
	end
end

for _, controller in controllers do
	if controller.Start then
		task.spawn(controller.Start, controller)
	end
end

print("[Client] started")
