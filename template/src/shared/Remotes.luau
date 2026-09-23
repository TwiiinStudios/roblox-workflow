--[[
	Every RemoteEvent / RemoteFunction in the game is declared here, in one place.

	The server creates them in ReplicatedStorage.Remotes; clients wait for them.
	Usage (both sides):
		local Remotes = require(ReplicatedStorage.Shared.Remotes)
		Remotes.Notify:FireClient(player, "hi")          -- server
		Remotes.Notify.OnClientEvent:Connect(print)      -- client

	SECURITY: never trust arguments that arrive from a client. Validate everything on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Notify",
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

return Remotes
