--[[
	Runs INSIDE a Roblox cloud server (Open Cloud Luau Execution), sent there by tools/cloudtest.luau.
	Not run by Lune.

	The cloud server loads the TEST place, but its own scripts don't run and nothing it changes is
	saved. This script swaps in our build (the binary input: an .rbxm of Shared, Server, Client, Assets,
	Map, Packages and the tests/cloud specs), starts the server the way Main.server.luau does, lets it
	settle, then runs every spec. It returns a report; warnings and errors printed meanwhile count too.

	tools/cloudtest.luau puts `local SETTLE_SECONDS = n` and `local SPEC_TIMEOUT = n` above this text.
]]

local SETTLE_SECONDS: number = SETTLE_SECONDS or 15
local SPEC_TIMEOUT: number = SPEC_TIMEOUT or 30

local LogService = game:GetService("LogService")
local SerializationService = game:GetService("SerializationService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local input = ({ ... })[1]

-- DataService sees this and keeps saves in memory: a test must never touch real player data.
game:SetAttribute("CloudTest", true)

local lines = {}
local passed, failed = 0, 0
local function result(name: string, ok: boolean, err: any?)
	if ok then
		passed += 1
		table.insert(lines, `pass  {name}`)
	else
		failed += 1
		table.insert(lines, `FAIL  {name}\n      {tostring(err)}`)
	end
end

local problems = {}
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError then
		table.insert(problems, `ERROR {message}`)
	elseif kind == Enum.MessageType.MessageWarning then
		table.insert(problems, `WARN  {message}`)
	end
end)

-- 1. Our build in place of the place's own copy.
local roots = SerializationService:DeserializeInstancesAsync(input.BinaryInput)
for _, root in roots do
	local where = root:GetAttribute("CloudTestParent")
	local parent: Instance = game
	for name in string.gmatch(where, "[^/]+") do
		parent = if parent == game then game:GetService(name) else parent:WaitForChild(name)
	end
	local old = parent:FindFirstChild(root.Name)
	if old then
		old:Destroy()
	end
	root.Parent = parent
end

-- 2. Start the server like Main.server.luau: require every service, Init each, then Start each.
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local services = {}
for _, module in Server:WaitForChild("Services"):GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, loaded = pcall(require, module)
		if ok then
			services[module.Name] = loaded
		else
			result(`server: load {module.Name}`, false, loaded)
		end
	end
end
for name, service in services do
	if service.Init then
		local ok, err = xpcall(service.Init, debug.traceback, service, services)
		if not ok then
			result(`server: {name}:Init`, false, err)
		end
	end
end
local startErrors = {}
for name, service in services do
	if service.Start then
		task.spawn(function()
			local ok, err = xpcall(service.Start, debug.traceback, service)
			if not ok then
				startErrors[name] = err
			end
		end)
	end
end

task.wait(SETTLE_SECONDS)

for name in services do
	if startErrors[name] then
		result(`server: {name}:Start`, false, startErrors[name])
	end
end
result("server: every service started", next(startErrors) == nil, "see the failures above")

-- 3. The specs: tests/cloud/*.cloud.luau, each a table of  ["what it should do"] = function(ctx) end.
local ctx = {
	services = services,
	generated = Workspace:FindFirstChild("Generated"),
}
local specs = ServerStorage:FindFirstChild("CloudTests")
local specModules = if specs then specs:GetChildren() else {}
table.sort(specModules, function(a, b)
	return a.Name < b.Name
end)
for _, module in specModules do
	local ok, spec = pcall(require, module)
	if not ok or type(spec) ~= "table" then
		result(`{module.Name} (could not load)`, false, spec)
		continue
	end
	local names = {}
	for testName in spec do
		table.insert(names, testName)
	end
	table.sort(names)
	for _, testName in names do
		local done, testOk, testErr = false, false, nil
		local thread = task.spawn(function()
			testOk, testErr = xpcall(spec[testName], debug.traceback, ctx)
			done = true
		end)
		local started = os.clock()
		while not done and os.clock() - started < SPEC_TIMEOUT do
			task.wait(0.1)
		end
		if not done then
			task.cancel(thread)
			testErr = `took longer than {SPEC_TIMEOUT} s`
		end
		result(`{module.Name} > {testName}`, done and testOk, testErr)
	end
end

return {
	passed = passed,
	failed = failed,
	lines = lines,
	problems = problems,
}
