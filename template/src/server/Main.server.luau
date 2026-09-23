--[[
	Server entry point.

	Loads every ModuleScript in Services/, calls :Init(services) on each, then :Start() on each.
	To add a system, create a new file in src/server/Services/ -- nothing to register here.
]]

local Services = script.Parent:WaitForChild("Services")

local services = {}
for _, module in Services:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = require(module)
	end
end

for _, service in services do
	if service.Init then
		service:Init(services)
	end
end

for _, service in services do
	if service.Start then
		task.spawn(service.Start, service)
	end
end

print("[Server] started")
