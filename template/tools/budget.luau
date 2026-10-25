--[[
	Performance budget: what a new player has to download and what the server has to hold, counted from
	build/game.rbxl (run tools/build.luau first; tools/check.luau does). Fails when a number goes over its
	limit in src/shared/PerfBudget.luau, so a change that would make the game load slowly is caught before TEST.

	    lune run tools/budget.luau

	Every distinct mesh, image and sound is a separate download on a player's first visit (~10,500 meshes
	once stalled loading). Raising a limit is fine when the growth is on purpose: change PerfBudget.luau in
	the same PR, so it's visible. The world built at runtime (src/server/World) is counted by the cloud test
	(tests/cloud/Budget.cloud.luau) against the same limits.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local PerfBudget = require("../src/shared/PerfBudget")

local PLACE_FILE = "build/game.rbxl"

-- Properties that point at something a player downloads, by kind.
local ASSET_PROPS = {
	mesh = {
		MeshPart = { "MeshId" },
		SpecialMesh = { "MeshId" },
		FileMesh = { "MeshId" },
	},
	image = {
		MeshPart = { "TextureID" },
		SpecialMesh = { "TextureId" },
		FileMesh = { "TextureId" },
		SurfaceAppearance = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
		MaterialVariant = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" },
		Decal = { "Texture" },
		Texture = { "Texture" },
		ImageLabel = { "Image" },
		ImageButton = { "Image" },
		ParticleEmitter = { "Texture" },
		Beam = { "Texture" },
		Trail = { "Texture" },
		Sky = {
			"SkyboxBk",
			"SkyboxDn",
			"SkyboxFt",
			"SkyboxLf",
			"SkyboxRt",
			"SkyboxUp",
			"SunTextureId",
			"MoonTextureId",
		},
	},
	sound = {
		Sound = { "SoundId" },
	},
}

local function read(instance: any, prop: string): any
	local ok, value = pcall(function()
		return instance[prop]
	end)
	return if ok then value else nil
end

-- The asset a property points at ("rbxassetid://123", "rbxasset://…", "http…"), whichever way the file
-- stores it: newer files keep MeshId as MeshContent, TextureID as TextureContent, Image as ImageContent….
local function assetOf(instance: any, prop: string): string?
	local names = { prop, (prop:gsub("Id$", "Content"):gsub("ID$", "Content")), `{prop}Content` }
	for _, name in names do
		local value = read(instance, name)
		if value ~= nil then
			local text = tostring(value)
			local id = text:match("rbxassetid://%d+")
				or text:match("rbxasset://[^%)%s]+")
				or text:match("https?://[^%)%s]+")
			if id then
				return id
			end
		end
	end
	return nil
end

local function count(): { [string]: number }
	if not fs.isFile(PLACE_FILE) then
		print(`[budget] {PLACE_FILE} is missing: run lune run tools/build.luau first`)
		process.exit(1)
	end
	local bytes = fs.readFile(PLACE_FILE)
	local game = roblox.deserializePlace(bytes)
	local seen = { mesh = {}, image = {}, sound = {} }
	local n = { instances = 0, mapParts = 0, scripts = 0, scriptKB = 0 }
	for _, instance in game:GetDescendants() do
		n.instances += 1
		for kind, byClass in ASSET_PROPS do
			local props = byClass[instance.ClassName]
			if props then
				for _, prop in props do
					local id = assetOf(instance, prop)
					if id then
						seen[kind][id] = true
					end
				end
			end
		end
		if instance:IsA("LuaSourceContainer") then
			n.scripts += 1
			n.scriptKB += #tostring(read(instance, "Source") or "") / 1024
		end
	end
	local map = game:GetService("Workspace"):FindFirstChild("Map")
	if map then
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") then
				n.mapParts += 1
			end
		end
	end
	local distinct = function(set)
		local c = 0
		for _ in set do
			c += 1
		end
		return c
	end
	return {
		meshes = distinct(seen.mesh),
		images = distinct(seen.image),
		sounds = distinct(seen.sound),
		mapParts = n.mapParts,
		instances = n.instances,
		scripts = n.scripts,
		scriptKB = math.floor(n.scriptKB + 0.5),
		placeKB = math.floor(#bytes / 1024 + 0.5),
	}
end

local numbers = count()
local over = {}
print("\n  what                                     now     limit    used")
for _, key in PerfBudget.ORDER do
	local limit = PerfBudget.FILE[key]
	if limit then
		local value = numbers[key]
		local share = math.floor(100 * value / limit + 0.5)
		local mark = if value > limit then "  << OVER" elseif share >= 85 then "  (close)" else ""
		print(string.format("  %-38s %7d  %8d  %4d%%%s", PerfBudget.LABELS[key], value, limit, share, mark))
		if value > limit then
			table.insert(over, `{PerfBudget.LABELS[key]}: {value} (limit {limit})`)
		end
	end
end

if #over > 0 then
	print("\n[budget] OVER BUDGET:")
	for _, line in over do
		print(`  - {line}`)
	end
	print("Make it smaller (merge meshes: tools/merge_model.py; reuse images), or raise the limit in")
	print("src/shared/PerfBudget.luau in this PR if the growth is on purpose.")
	process.exit(1)
end
print("\n[budget] Within budget.")
