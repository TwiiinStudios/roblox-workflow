--[[
	Adopt a game made in Studio: its place file becomes files, so it's built like every other game here.

	    lune run tools/adopt/place_to_files.luau <place.rbxl>

	Writes default.project.json (every service the game uses, each at its own place: src/<Service>) and src/ through
	Rojo's syncback: scripts become .luau files where they were (the game's require paths keep working), other things
	model files beside them, and the services' settings go into the project file. This template's extras (Packages,
	ServerPackages, HttpService) are kept. Then prove it's the same game:

	    lune run tools/build.luau
	    lune run tools/adopt/same_game.luau <place.rbxl> build/game.rbxl

	It says what it couldn't bring over (terrain, scripts left inside model files), so a person or agent can look.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local placePath = process.args[1]
if not placePath or not fs.isFile(placePath) then
	print("Usage: lune run tools/adopt/place_to_files.luau <place.rbxl>")
	process.exit(1)
end
local game = roblox.deserializePlace(fs.readFile(placePath))

-- The services a game keeps things or settings in, in the order Studio shows them.
local SERVICES = {
	"Workspace",
	"Players",
	"Lighting",
	"MaterialService",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"TextChatService",
	"Chat",
	"AvatarSettings",
}

local template = serde.decode("json", fs.readFile("default.project.json"))
local tree: { [string]: any } = { ["$className"] = "DataModel" }
for _, name in SERVICES do
	if game:FindFirstChildOfClass(name) then
		tree[name] = { ["$path"] = `src/{name}` }
	end
end
-- (the player's script folders are services' children of their own class: their scripts must become files too)
if tree.StarterPlayer then
	tree.StarterPlayer.StarterPlayerScripts = { ["$path"] = "src/StarterPlayerScripts" }
	tree.StarterPlayer.StarterCharacterScripts = { ["$path"] = "src/StarterCharacterScripts" }
end

local function mkdirs(node: { [string]: any })
	for key, child in node do
		if key == "$path" then
			fs.writeDir(child)
		elseif typeof(child) == "table" and string.sub(key, 1, 1) ~= "$" then
			mkdirs(child)
		end
	end
end
if fs.isDir("src") then
	fs.removeDir("src")
end
mkdirs(tree)

local project = {
	name = template.name,
	tree = tree,
	-- (Roblox makes these itself; Rojo can't write terrain, it's reported below)
	syncbackRules = { ignoreTrees = { "Workspace/Camera", "Workspace/Terrain" } },
}
fs.writeFile("default.project.json", serde.encode("json", project, true))

local synced = process.exec("rojo", { "syncback", "-y", "--input", placePath, "default.project.json" }, { stdio = "inherit" })
if not synced.ok then
	print("\n[adopt] FAILED: rojo syncback failed (see the error above)")
	process.exit(1)
end

-- This template's extras, beside what syncback wrote (it rewrites the project with the services' settings).
project = serde.decode("json", fs.readFile("default.project.json"))
local notes = {}
local function extra(service: string, name: string, node: any)
	project.tree[service] = project.tree[service] or { ["$className"] = service }
	if project.tree[service][name] or game:FindFirstChildOfClass(service) and game:FindFirstChildOfClass(service):FindFirstChild(name) then
		table.insert(notes, `{service}.{name} already exists in the game: the template's {name} wasn't added`)
		return
	end
	project.tree[service][name] = node
end
local t = template.tree
if t.ReplicatedStorage and t.ReplicatedStorage.Packages then
	extra("ReplicatedStorage", "Packages", t.ReplicatedStorage.Packages)
end
if t.ServerStorage and t.ServerStorage.ServerPackages then
	extra("ServerStorage", "ServerPackages", t.ServerStorage.ServerPackages)
end
if t.HttpService and not project.tree.HttpService then
	-- (the game's own setting wins; the template turns it on for its error reports)
	local http = game:FindFirstChildOfClass("HttpService")
	project.tree.HttpService = { ["$className"] = "HttpService", ["$properties"] = { HttpEnabled = if http then http.HttpEnabled else true } }
end
fs.writeFile("default.project.json", serde.encode("json", project, true))

-- What couldn't come over as plain files
local terrain = game:FindFirstChildOfClass("Workspace"):FindFirstChildOfClass("Terrain")
local ok, grid = pcall(function()
	return terrain and terrain.SmoothGrid
end)
if ok and grid and #tostring(grid) > 200 then
	table.insert(notes, `the game has terrain ({#tostring(grid)} bytes): Rojo can't keep it in files. Rebuild it in code (a World builder) or capture it`)
end
local function scan(dir: string)
	for _, entry in fs.readDir(dir) do
		local path = `{dir}/{entry}`
		if fs.isDir(path) then
			scan(path)
		elseif string.match(entry, "%.rbxm$") then
			local model = roblox.deserializeModel(fs.readFile(path))
			for _, root in model do
				for _, d in { root, table.unpack(root:GetDescendants()) } do
					if d:IsA("LuaSourceContainer") then
						table.insert(notes, `{path} has a script inside ({d:GetFullName()}): split it out so it's a .luau file`)
						break
					end
				end
			end
		end
	end
end
scan("src")

local scripts = 0
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		scripts += 1
	end
end
print(`\n[adopt] {scripts} scripts brought over into src/ (default.project.json lists where each service's things are)`)
for _, note in notes do
	print(`[adopt] NOTE: {note}`)
end
print("[adopt] Next: lune run tools/build.luau, then lune run tools/adopt/same_game.luau " .. placePath .. " build/game.rbxl")
