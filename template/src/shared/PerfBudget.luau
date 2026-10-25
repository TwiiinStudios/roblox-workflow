--[[
	Performance budget: limits on what a new player downloads and what the server holds. Checked by
	tools/budget.luau (the built place file, part of tools/check.luau and CI) and by
	tests/cloud/Budget.cloud.luau (the world as the server builds it, in the cloud test).

	Every distinct mesh, image and sound is a separate download on a player's first visit; in another of our
	games ~10,500 distinct meshes once stalled loading online (big imports are merged with
	tools/merge_model.py: one mesh per texture). These starting limits are generous for a new game: when the
	game grows near one, look at what grew before raising it. Raise a limit only on purpose, in the same PR
	as the growth, and note today's number beside it. Pure data (no Roblox APIs), so Lune can read it too.
]]

local PerfBudget = {}

-- The built place file (tools/budget.luau).
PerfBudget.FILE = {
	meshes = 3000, -- distinct MeshIds (the template starts at 0)
	images = 1500, -- distinct textures, decals and UI images
	sounds = 200, -- distinct sounds (sounds kept as ids in code don't count here)
	mapParts = 3000, -- parts in Workspace.Map (big generated worlds belong in src/server/World)
	instances = 20000, -- everything in the place file
	scriptKB = 1000, -- our code plus packages
	placeKB = 4000, -- the place file itself
}

-- The running server after start, Workspace + ReplicatedStorage (tests/cloud/Budget.cloud.luau).
PerfBudget.LIVE = {
	meshes = 3000, -- the same meshes as the place file, plus any made at runtime
	parts = 40000, -- every part in the running world, generated ones included
}

PerfBudget.ORDER = { "meshes", "images", "sounds", "mapParts", "parts", "instances", "scriptKB", "placeKB" }

PerfBudget.LABELS = {
	meshes = "distinct meshes (each is a download)",
	images = "distinct images and textures",
	sounds = "distinct sounds",
	mapParts = "parts in Workspace.Map",
	parts = "parts in the running world",
	instances = "instances in the place",
	scriptKB = "script source (KB)",
	placeKB = "place file (KB)",
}

return PerfBudget
