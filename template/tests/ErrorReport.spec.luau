local ErrorReport = require("../src/shared/ErrorReport")

return {
	["player names never leave the game"] = function()
		local text = ErrorReport.clean("Players.SomeName.PlayerScripts.Client.Gun:12: oops", 300)
		assert(not text:find("SomeName"), text)
		assert(text:find("Players.<player>.PlayerScripts", 1, true), text)
	end,

	["texts are one short line"] = function()
		local text = ErrorReport.clean("a\nb\r\n\tc " .. string.rep("x", 1000), 50)
		assert(not text:find("[%c]"), "no control characters")
		assert(#text <= 50 + 2, `cut short, got {#text}`) -- (+ the ellipsis' bytes)
		assert(ErrorReport.clean(nil, 50) == "" and ErrorReport.clean(42, 50) == "", "not text: nothing")
	end,

	["errors that differ only in numbers are grouped"] = function()
		local a = ErrorReport.key("server", "Server.Gun", "bad position 12, 40")
		local b = ErrorReport.key("server", "Server.Gun", "bad position 7, 3")
		assert(a == b, "same group")
		assert(a ~= ErrorReport.key("client", "Server.Gun", "bad position 7, 3"), "client and server apart")
	end,

	["a client can only report errors from our own scripts"] = function()
		local ok =
			ErrorReport.fromClient("x is nil", "stack", "Players.Bob.PlayerScripts.Client.Controllers.GunController")
		assert(ok and ok.where == "Players.<player>.PlayerScripts.Client.Controllers.GunController", "ours: kept")
		assert(ErrorReport.fromClient("x", "s", "CoreGui.RobloxGui.Modules") == nil, "Roblox's own: ignored")
		assert(ErrorReport.fromClient("x", "s", "Players.Bob.PlayerGui.Injected") == nil, "something else: ignored")
		assert(ErrorReport.fromClient({}, "s", "ReplicatedStorage.Shared.X") == nil, "not text: refused")
		assert(ErrorReport.fromClient("", "s", "ReplicatedStorage.Shared.X") == nil, "empty: refused")
		assert(ErrorReport.fromClient("m", 5, "ReplicatedStorage.Shared.X") == nil, "a stack that isn't text: refused")
	end,

	["a batch counts times and players, and forgets who"] = function()
		local batch = ErrorReport.newBatch()
		for i = 1, 5 do
			ErrorReport.add(batch, "client", "Shared.X", "boom", "", if i <= 3 then "p1" else "p2")
		end
		ErrorReport.add(batch, "server", "Server.Y", "rare", "", nil)
		local list, dropped = ErrorReport.drain(batch)
		assert(#list == 2 and dropped == 0, "two groups")
		assert(
			list[1].message == "boom" and list[1].count == 5 and list[1].players == 2,
			"most frequent first, 2 players"
		)
		assert(list[1].seen == nil, "who had it isn't sent")
		assert(#ErrorReport.drain(batch) == 0, "drained: empty again")
	end,

	["a flood of different errors is capped"] = function()
		local batch = ErrorReport.newBatch()
		for i = 1, ErrorReport.MAX_GROUPS + 25 do
			-- (letters only: messages that differ only in numbers would be one group)
			ErrorReport.add(
				batch,
				"server",
				"S",
				`error {string.char(65 + i % 26)}{string.char(65 + i // 26)}`,
				"",
				nil
			)
		end
		local list, dropped = ErrorReport.drain(batch)
		assert(#list <= ErrorReport.MAX_GROUPS, `capped at {ErrorReport.MAX_GROUPS}, got {#list}`)
		assert(dropped > 0, "the rest counted as dropped")
	end,
}
