--[[
	Every RemoteEvent / RemoteFunction in the game is declared here, in one place.

	The server creates them in ReplicatedStorage.Remotes; clients wait for them.
	Usage (both sides):
		local Remotes = require(ReplicatedStorage.Shared.Remotes)
		Remotes.Notify:FireClient(player, "hi")          -- server
		Remotes.Notify.OnClientEvent:Connect(print)      -- client

	SECURITY: never trust arguments that arrive from a client. Validate everything on the server.
	Server handlers connect with Remotes.serve(name, handler), so the cloud test can send events as a
	stand-in player (Remotes.simulate, tests/cloud/helpers/StandIn.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Notify",
	-- Client -> server: "one of the game's scripts errored on my side" (message, stack, script path).
	-- Untrusted: ErrorReportService cleans it (Shared.ErrorReport.fromClient), only takes our own scripts,
	-- rate-limits each player, and only ever counts it.
	"ClientError",
}

local FUNCTIONS = {}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local Remotes = {}
for _, name in EVENTS do
	Remotes[name] = folder:WaitForChild(name) :: RemoteEvent
end
for _, name in FUNCTIONS do
	Remotes[name] = folder:WaitForChild(name) :: RemoteFunction
end

-- Server: answer a client's event. The same as Remotes.<name>.OnServerEvent:Connect(handler), and the
-- cloud test (no real players there) can send the event as a stand-in player with Remotes.simulate.
local handlers: { [string]: { (any, ...any) -> () } } = {}
function Remotes.serve(name: string, handler: (Player, ...any) -> ()): RBXScriptConnection
	local list = handlers[name] or {}
	handlers[name] = list
	table.insert(list, handler)
	return (Remotes[name] :: RemoteEvent).OnServerEvent:Connect(handler)
end

-- Cloud test only: run the server's handlers for `name` as if `player` (a stand-in) had sent `...`.
function Remotes.simulate(name: string, player: any, ...: any)
	assert(RunService:IsServer(), "Remotes.simulate is for the server")
	for _, handler in handlers[name] or {} do
		handler(player, ...)
	end
end

return Remotes
