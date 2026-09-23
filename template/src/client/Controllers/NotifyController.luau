--[[
	Example controller: shows messages the server sends through Remotes.Notify.
]]

local StarterGui = game:GetService("StarterGui")

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)

local NotifyController = {}

function NotifyController:Start()
	Remotes.Notify.OnClientEvent:Connect(function(message: string)
		pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
			Title = "__GAME_NAME__",
			Text = message,
			Duration = 5,
		})
	end)
end

return NotifyController
