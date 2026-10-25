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

	-- Script errors on real servers and players' devices, counted and sent in batches to the studio's
	-- Discord bot (ErrorReportService). Off until the experience has the secret below (Creator Dashboard ->
	-- the experience -> Secrets), and always off in Studio and in the cloud test.
	ERROR_REPORTS = {
		URL = "https://tasks.twiiinstudio.cloud/bridge/v1/errors",
		SECRET = "DISCORD_BRIDGE_SECRET",
		EVERY = 300, -- seconds between batches (and one when the server closes)
		CLIENT_PER_MINUTE = 6, -- reports one player may send a minute; more are ignored
		CLIENT_PER_SESSION = 40,
	},

	-- Monetization: { live = id, test = id }, use with Config.pick()
	GAME_PASSES = {},
	PRODUCTS = {},

	pick = function(ids: { live: number, test: number }): number
		return if IS_LIVE then ids.live else ids.test
	end,
}
