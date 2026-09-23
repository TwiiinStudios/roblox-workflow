--[[
	Example service. Copy this file to make new ones.

	Init(services) runs first on every service (grab references to other services here).
	Start() runs after every service has been initialised (connect events, start loops here).
]]

local Players = game:GetService("Players")

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

local PlayerService = {}

function PlayerService:Init(_services) end

function PlayerService:Start()
	local function onPlayerAdded(player: Player)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		Remotes.Notify:FireClient(player, `Welcome, {player.DisplayName}!`)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerService
