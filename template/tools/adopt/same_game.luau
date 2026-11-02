--[[
	Is the game built from the files the same as the place it came from? (after tools/adopt/place_to_files.luau)

	    lune run tools/adopt/same_game.luau <original.rbxl> <built.rbxl>

	Compares every object (by its path and class), every script's source and every setting a script can read.
	Ends with "Same game" and exit 0, or lists what differs and exits 1. Roblox's own empty services, the camera,
	the terrain (place_to_files reports it) and this template's extras (Packages, HttpService) don't count.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

if #process.args < 2 then
	print("Usage: lune run tools/adopt/same_game.luau <original.rbxl> <built.rbxl>")
	process.exit(1)
end
local before = roblox.deserializePlace(fs.readFile(process.args[1]))
local after = roblox.deserializePlace(fs.readFile(process.args[2]))
local db = roblox.getReflectionDatabase()

local IGNORED = {
	["Workspace.Camera"] = true,
	["Workspace.Terrain"] = true,
	InsertService = true, -- (holds only Roblox's own InsertionHash)
	["ReplicatedStorage.Packages"] = true,
	["ServerStorage.ServerPackages"] = true,
}
-- (settings Roblox or Rojo fill in themselves, not the game's)
local SKIPPED_PROPERTIES = {
	UniqueId = true,
	HistoryId = true,
	SourceAssetId = true,
	Capabilities = true,
	ScriptGuid = true,
	SerializedOverrides = true,
	HttpEnabled = true,
}

-- path -> instance, for every object under a service (paths that repeat are compared by count only)
local function index(game)
	local found, count = {}, {}
	for _, d in game:GetDescendants() do
		local path = d:GetFullName()
		local top, second = string.match(path, "^[^.]+"), string.match(path, "^[^.]+%.[^.]+")
		if not (IGNORED[top] or second and IGNORED[second]) then
			local key = `{path} [{d.ClassName}]`
			count[key] = (count[key] or 0) + 1
			found[key] = d
		end
	end
	return found, count
end

local function properties(className: string)
	local names = {}
	local class = db:GetClass(className)
	while class do
		for name, p in class.Properties do
			if p.Scriptability ~= "None" and not table.find(p.Tags, "Deprecated") and not SKIPPED_PROPERTIES[name] then
				names[name] = true
			end
		end
		class = class.Superclass and db:GetClass(class.Superclass)
	end
	return names
end

local a, countA = index(before)
local b, countB = index(after)
local problems = {}
local function problem(text: string)
	table.insert(problems, text)
end

local compared = 0
for key, d in a do
	local other = b[key]
	if not other then
		-- (a service with nothing in it is made by Roblox anyway)
		if d.Parent ~= before or #d:GetChildren() > 0 then
			problem(`missing: {key}`)
		end
	elseif countA[key] ~= countB[key] then
		problem(`{key}: {countA[key]} in the game, {countB[key]} from the files`)
	elseif countA[key] == 1 then
		compared += 1
		for name in properties(d.ClassName) do
			local okA, va = pcall(function()
				return d[name]
			end)
			local okB, vb = pcall(function()
				return other[name]
			end)
			if okA and okB and va ~= vb and tostring(va) ~= tostring(vb) then
				local shown = if name == "Source" then "(the code differs)" else `{tostring(va)} -> {tostring(vb)}`
				problem(`{key}.{name}: {shown}`)
			end
		end
	end
end
for key, d in b do
	if not a[key] and not (d.Parent == after and #d:GetChildren() == 0) then
		problem(`extra: {key}`)
	end
end

table.sort(problems)
for i, text in problems do
	if i > 60 then
		print(`... and {#problems - 60} more`)
		break
	end
	print(text)
end
if #problems > 0 then
	print(`\n[same_game] {#problems} differences ({compared} objects compared)`)
	process.exit(1)
end
print(`[same_game] Same game: {compared} objects, their scripts and settings match`)
