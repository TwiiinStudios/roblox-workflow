--[[
	Keeps every name Roblox sees family-friendly. Roblox's automated moderation reads asset names
	(meshes, images, models and the parts inside them) and banned the owner's account once for
	names that were ordinary in context but read as something else out of it (2026-10-09).

	    lune run tools/names.luau            check (part of tools/check.luau and CI)
	    lune run tools/names.luau --fix      also rewrite risky words in the captured models
	    lune run tools/names.luau --words    list every word in use (to review new ones)

	A name passes when every word in it is on tools/names/allowed.txt (reviewed words), none is in
	tools/names/renames.json's rename table (with its safe replacement), and it doesn't put a
	person/body word next to a shade word. Unknown words fail until someone reviews them and adds
	them to allowed.txt - so a new import can never slip an unreviewed word into the game.

	Checked: every instance name in assets/**/*.rbxm and the files' own names, every "Name" in
	world/**/*.json, and the names players read that you list at the end of this file (items, pets, shop
	entries...: add your game's lists there as they appear).
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local fix = table.find(process.args, "--fix") ~= nil
local listWords = table.find(process.args, "--words") ~= nil

local config = serde.decode("json", fs.readFile("tools/names/renames.json"))
local renames: { [string]: string } = config.rename
local body: { [string]: boolean } = {}
for _, w in config.bodyWords do
	body[w] = true
end
local shade: { [string]: boolean } = {}
for _, w in config.shadeWords do
	shade[w] = true
end
local allowed: { [string]: boolean } = {}
for line in fs.readFile("tools/names/allowed.txt"):gmatch("[^\r\n]+") do
	for w in line:gmatch("%a+") do
		if line:sub(1, 1) ~= "#" then
			allowed[w:lower()] = true
		end
	end
end

-- The words in a name: letter runs, with camelCase split ("PharmacyDriveThru" -> 3 words).
local function words(name: string): { string }
	local list = {}
	for run in name:gmatch("%a+") do
		for part in run:gsub("(%l)(%u)", "%1 %2"):gmatch("%a+") do
			table.insert(list, part:lower())
		end
	end
	return list
end

local function problems(name: string): { string }
	local found = {}
	local hasBody, hasShade = false, false
	for _, w in words(name) do
		if renames[w] then
			table.insert(found, `"{w}" (use "{renames[w]}")`)
		elseif not allowed[w] and #w > 1 then
			table.insert(found, `"{w}" isn't a reviewed word (check it, then add it to tools/names/allowed.txt)`)
		end
		hasBody = hasBody or body[w] == true
		hasShade = hasShade or shade[w] == true
	end
	if hasBody and hasShade then
		table.insert(found, "a shade word next to a person/body word")
	end
	return found
end

-- The safe version of a name: renamed words swapped (keeping their capitalisation), and shade
-- words dropped from a name that also names a person or body part.
local function clean(name: string): string
	local out = name:gsub("%a+", function(run: string)
		return (
			run:gsub("%u?%l*", function(part: string)
				if part == "" then
					return part
				end
				local swap = renames[part:lower()]
				if not swap then
					return part
				end
				if part:sub(1, 1):match("%u") then
					return swap:sub(1, 1):upper() .. swap:sub(2)
				end
				return swap
			end)
		)
	end)
	local hasBody = false
	for _, w in words(out) do
		hasBody = hasBody or body[w] == true
	end
	if hasBody then
		out = out:gsub("%a+", function(run: string)
			return if shade[run:lower()] then "" else run
		end)
		out = out:gsub("__+", "_"):gsub("^_", ""):gsub("_$", "")
	end
	return out
end

local failures = {}
local seenWords: { [string]: boolean } = {}
local renamed = 0
local function visit(where: string, name: string)
	for _, w in words(name) do
		seenWords[w] = true
	end
	for _, p in problems(name) do
		table.insert(failures, `{where}: "{name}" - {p}`)
	end
end

local function walk(dir: string, each: (string, string) -> ())
	if not fs.isDir(dir) then
		return
	end
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			walk(path, each)
		else
			each(path, entry)
		end
	end
end

-- The captured models: file names and every instance inside.
walk("assets", function(path, entry)
	if entry:sub(-5) ~= ".rbxm" then
		return
	end
	visit(path, entry:sub(1, -6))
	local roots = roblox.deserializeModel(fs.readFile(path))
	local changed = false
	for _, root in roots do
		local all = root:GetDescendants()
		table.insert(all, 1, root)
		for _, inst in all do
			local name = inst.Name
			if fix then
				local safe = clean(name)
				if safe ~= name and safe ~= "" then
					inst.Name = safe
					name = safe
					changed = true
					renamed += 1
				end
			end
			visit(path, name)
		end
	end
	if changed then
		fs.writeFile(path, roblox.serializeModel(roots))
	end
end)

-- Hand-written world files.
walk("world", function(path, entry)
	if entry:sub(-5) ~= ".json" then
		return
	end
	visit(path, entry:gsub("%.model%.json$", ""):gsub("%.meta%.json$", ""):gsub("%.json$", ""))
	for name in fs.readFile(path):gmatch('"Name"%s*:%s*"([^"]+)"') do
		visit(path, name)
	end
end)

-- What players read (item, pet, shop or level names...): add your game's lists here as they appear, e.g.
--	local Items = require("../src/shared/Items")
--	for id, def in Items.DEFS do
--		visit("Items", id)
--		visit("Items", def.name)
--	end
-- (A list that names shades of skin on purpose can be left out, with a comment saying why.)

if listWords then
	local list = {}
	for w in seenWords do
		table.insert(list, w)
	end
	table.sort(list)
	print(table.concat(list, "\n"))
	return
end

if fix and renamed > 0 then
	print(`[names] renamed {renamed} risky names in the captured models`)
end
if #failures > 0 then
	table.sort(failures)
	for _, f in failures do
		print("  " .. f)
	end
	print(`\n[names] FAILED: {#failures} name problems. Risky words: run "lune run tools/names.luau --fix".`)
	process.exit(1)
end
print("[names] OK - every name is on the reviewed list")
