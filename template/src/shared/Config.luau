--[[
	Every number someone might want to tweak (prices, speeds, timers, limits) and every asset ID lives here.
	Balancing the game = a small, easy-to-review change to this file.

	TEST and LIVE are different experiences, so game passes / products / badges have different IDs.
	Pick them with IS_LIVE (fill in the LIVE universe ID from deploy.json).
]]

local LIVE_UNIVERSE_ID = 0 -- from deploy.json "live.universeId"
local IS_LIVE = game.GameId ~= 0 and game.GameId == LIVE_UNIVERSE_ID

return {
	IS_LIVE = IS_LIVE,

	-- Gameplay
	-- STARTING_COINS = 0,

	-- Asset IDs (images, sounds, meshes): "rbxassetid://123"
	ASSETS = {},

	-- Monetization: { live = id, test = id }, use with Config.pick()
	GAME_PASSES = {},
	PRODUCTS = {},

	pick = function(ids: { live: number, test: number }): number
		return if IS_LIVE then ids.live else ids.test
	end,
}
