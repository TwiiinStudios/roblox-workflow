--[[
	Cloud test: runs the game's server for real on a Roblox cloud server, without Studio and without
	publishing anything.

	    lune run tools/cloudtest.luau                 (builds first)
	    lune run tools/cloudtest.luau --no-build      (uses the build/game.rbxl you already have)
	    lune run tools/cloudtest.luau --settle 30     (seconds the server gets to start before the specs)

	It sends our build to the TEST place through Open Cloud Luau Execution: a cloud server loads TEST,
	tools/cloudtest/session.luau swaps in our code, starts every service, waits, then runs the specs in
	tests/cloud/*.cloud.luau. Nothing is saved: TEST and its players are not touched, and player data
	stays in memory (DataService sees the CloudTest attribute). Physics doesn't run there and there are no
	players, so it tests the server's code and the world it builds, not how the game plays.

	It fails on a failed spec, a service that errors while starting, or any warning or error printed
	by our code. Needs the luau-execution-session permission on ROBLOX_API_KEY (see tools/lib/ApiKey.luau).
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local readApiKey = require("./lib/ApiKey")

local PLACE_FILE = "build/game.rbxl"
local SPEC_DIR = "tests/cloud"
local SPEC_TIMEOUT = 30
local POLL_SECONDS = 3
local GIVE_UP_SECONDS = 420 -- a task may run 5 minutes, plus time in the queue
local API = "https://apis.roblox.com/cloud/v2"

-- What we send: these parts of the built place replace the cloud server's copy.
local SENT = {
	{ "ReplicatedStorage", "Shared" },
	{ "ReplicatedStorage", "Assets" },
	{ "ReplicatedStorage", "Packages" },
	{ "ServerScriptService", "Server" },
	{ "ServerStorage", "ServerPackages" },
	{ "StarterPlayer/StarterPlayerScripts", "Client" },
	{ "Workspace", "Map" },
}

-- Printed by our code on purpose, not a sign of a bug: lines that contain one of these are ignored.
local EXPECTED = {}

local function fail(message: string): never
	print(`\n[cloudtest] FAILED: {message}`)
	process.exit(1)
	error(message)
end

local function argValue(name: string): string?
	local at = table.find(process.args, name)
	return at and process.args[at + 1]
end

local settle = tonumber(argValue("--settle")) or 15

-- 1. Build and pack.
if not table.find(process.args, "--no-build") then
	local built = process.exec("lune", { "run", "tools/build.luau" }, { stdio = "inherit" })
	if not built.ok then
		fail("the build failed")
	end
end
if not fs.isFile(PLACE_FILE) then
	fail(`{PLACE_FILE} not found. Run: lune run tools/build.luau`)
end

local place = roblox.deserializePlace(fs.readFile(PLACE_FILE))
local roots = {}
for _, sent in SENT do
	local path, name = sent[1], sent[2]
	local parent: any = place
	for part in string.gmatch(path, "[^/]+") do
		parent = if parent == place then parent:GetService(part) else parent:FindFirstChild(part)
		if not parent then
			break
		end
	end
	local root = parent and parent:FindFirstChild(name)
	if root then
		root:SetAttribute("CloudTestParent", path)
		table.insert(roots, root)
	end
end

local specs = roblox.Instance.new("Folder")
specs.Name = "CloudTests"
specs:SetAttribute("CloudTestParent", "ServerStorage")
if fs.isDir(SPEC_DIR) then
	for _, file in fs.readDir(SPEC_DIR) do
		local name = string.match(file, "^(.+)%.cloud%.luau$")
		if name then
			local module = roblox.Instance.new("ModuleScript")
			module.Name = name
			module.Source = fs.readFile(`{SPEC_DIR}/{file}`)
			module.Parent = specs
		end
	end
end
specs.Parent = place:GetService("ServerStorage") -- inside the place: Lune packs only one place's instances together
table.insert(roots, specs)
-- Code the specs share (tests/cloud/helpers/*.luau, e.g. StandIn): ServerStorage.CloudHelpers.<name>.
local HELPER_DIR = `{SPEC_DIR}/helpers`
if fs.isDir(HELPER_DIR) then
	local helpers = roblox.Instance.new("Folder")
	helpers.Name = "CloudHelpers"
	helpers:SetAttribute("CloudTestParent", "ServerStorage")
	for _, file in fs.readDir(HELPER_DIR) do
		local name = string.match(file, "^(.+)%.luau$")
		if name then
			local module = roblox.Instance.new("ModuleScript")
			module.Name = name
			module.Source = fs.readFile(`{HELPER_DIR}/{file}`)
			module.Parent = helpers
		end
	end
	helpers.Parent = place:GetService("ServerStorage")
	table.insert(roots, helpers)
end
local packed = roblox.serializeModel(roots)
print(`[cloudtest] packed {#roots} parts of the game ({math.floor(#packed / 1024)} KB)`)

-- 2. Open Cloud.
local deploy = serde.decode("json", fs.readFile("deploy.json"))
local ids = deploy.test
local apiKey = readApiKey() or fail("no API key. Put ROBLOX_API_KEY in .env (see .env.example)")

local function call(method: string, url: string, body: any?): any
	for attempt = 1, 6 do
		local response = net.request({
			url = url,
			method = method,
			headers = { ["x-api-key"] = apiKey, ["Content-Type"] = "application/json" },
			body = if body then serde.encode("json", body) else nil,
		})
		if response.ok then
			return serde.decode("json", response.body)
		end
		if response.statusCode == 429 and attempt < 6 then
			print("[cloudtest] Roblox says wait (only 5 cloud tests a minute); trying again in 15 s")
			task.wait(15)
		elseif response.statusCode == 401 or response.statusCode == 403 then
			fail(
				`Roblox refused the key ({response.statusCode}). It needs the permission "luau-execution-sessions"`
					.. ` (read + write) for the TEST experience: Creator Dashboard -> Credentials -> the key -> Edit.\n{response.body}`
			)
		else
			fail(`Roblox answered {response.statusCode} {response.statusMessage}\n{response.body}`)
		end
	end
	return fail("Roblox kept saying wait")
end

local universe = `{API}/universes/{ids.universeId}`
local input = call("POST", `{universe}/luau-execution-session-task-binary-inputs`, { size = #packed })
local upload = net.request({
	url = input.uploadUri,
	method = "PUT",
	headers = { ["Content-Type"] = "application/octet-stream" },
	body = packed,
})
if not upload.ok then
	fail(`uploading the build failed: {upload.statusCode} {upload.body}`)
end

local script = `local SETTLE_SECONDS = {settle}\nlocal SPEC_TIMEOUT = {SPEC_TIMEOUT}\n`
	.. fs.readFile("tools/cloudtest/session.luau")
local created = call("POST", `{universe}/places/{ids.placeId}/luau-execution-session-tasks`, {
	script = script,
	binaryInput = input.path,
	timeout = "300s",
})
print(`[cloudtest] running on a Roblox cloud server (TEST place, nothing is saved)...`)

-- 3. Wait for it, then report.
local taskInfo = created
local waited = 0
while taskInfo.state ~= "COMPLETE" and taskInfo.state ~= "FAILED" and taskInfo.state ~= "CANCELLED" do
	if waited > GIVE_UP_SECONDS then
		fail(`gave up after {GIVE_UP_SECONDS} s (still {taskInfo.state})`)
	end
	task.wait(POLL_SECONDS)
	waited += POLL_SECONDS
	taskInfo = call("GET", `{API}/{created.path}`)
end

local logs = call("GET", `{API}/{taskInfo.path}/logs`)
local printed = {}
for _, chunk in logs.luauExecutionSessionTaskLogs or {} do
	for _, message in chunk.messages or {} do
		table.insert(printed, message)
	end
end
if #printed > 0 then
	print("\n--- printed on the cloud server ---")
	for _, message in printed do
		print(message)
	end
end

if taskInfo.state ~= "COMPLETE" then
	local err = taskInfo.error
	fail(`the cloud run {taskInfo.state}: {if err then serde.encode("json", err) else "no details"}`)
end

local report = taskInfo.output and taskInfo.output.results and taskInfo.output.results[1]
if type(report) ~= "table" then
	fail("the cloud server sent no report")
end

print("\n--- results ---")
for _, line in report.lines do
	print(line)
end

local function expected(line: string): boolean
	for _, pattern in EXPECTED do
		if string.find(line, pattern, 1, true) then
			return true
		end
	end
	return false
end
local problems = {}
for _, line in report.problems or {} do
	if not expected(line) then
		table.insert(problems, line)
	end
end
if #problems > 0 then
	print("\n--- warnings and errors printed while it ran ---")
	for _, line in problems do
		print(line)
	end
end

print(`\n[cloudtest] {report.passed} passed, {report.failed} failed, {#problems} warnings/errors`)
if report.failed > 0 or #problems > 0 then
	process.exit(1)
end
print("[cloudtest] All good.")
