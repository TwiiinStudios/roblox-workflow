--[[
	Keeps other people's code out of the game. Models captured from Studio or taken from the board's Library
	(assets/Captured, world/Map/Captured) can carry scripts, and free models and downloaded games often hide a
	backdoor in one: code that loads more code from Roblox or the web while the game runs, so a stranger can
	take over our servers. All our code lives in src/, so a model holds no scripts at all: any Script,
	LocalScript or ModuleScript in a model file fails, and so does a PackageLink (a model that updates itself
	from someone else's copy). Each finding says what the script does that's dangerous, when it does:
	  - loading code: require(<number>) or require(<sum>), loadstring, getfenv/setfenv, :GetObjects(),
	    InsertService:LoadAsset / LoadAssetVersion
	  - a script that copies itself (script:Clone(), how "virus" free-model scripts spread)
	  - code hidden after a long run of blanks on one line (a backdoor trick: the line looks empty)
	  - a Discord webhook (player data sent outside the game)

	    lune run tools/model-scripts.luau            check (part of tools/check.luau and CI); exits 1 on a finding
	    lune run tools/model-scripts.luau <folder>   check other model files (.rbxm/.rbxmx/.rbxl) instead

	Fix: delete the script or the link (in Studio and re-capture, or from the model file with Lune). Something a
	model really needs to do is written in src/ like the rest of our code.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local DIRS = if #process.args > 0 then process.args else { "assets/Captured", "world/Map/Captured" }
local HIDDEN_BLANKS = 200 -- blanks in a row on one line, followed by code

local RISKY = {
	{ "loads code by number: require(<number>)", "require%s*%(%s*%d" },
	{ "loads code by a sum: require(a + b)", "require%s*%(%s*[%w_%.]+%s*[%+%-%*/%%]" },
	{ "runs text as code: loadstring", "loadstring" },
	{ "reaches into other code: getfenv/setfenv", "[gs]etfenv" },
	{ "loads models from Roblox: GetObjects", ":%s*GetObjects%s*%(" },
	{ "loads models from Roblox: LoadAsset", "LoadAsset" },
	{ "copies itself (virus): script:Clone()", "script%s*:%s*[Cc]lone%s*%(" },
	{ "sends data to Discord: a webhook", "discord[%w]*%.com/api/webhooks" },
}

local function hiddenCode(source: string): boolean
	for line in source:gmatch("[^\n]+") do
		for blanks in line:gmatch("([ \t]+)%S") do
			if #blanks >= HIDDEN_BLANKS then
				return true
			end
		end
	end
	return false
end

local function lineOf(source: string, at: number): number
	local _, n = source:sub(1, at):gsub("\n", "")
	return n + 1
end

local function pathOf(inst: any): string
	local parts = {}
	while inst do
		table.insert(parts, 1, inst.Name)
		inst = inst.Parent
	end
	return table.concat(parts, ".")
end

local findings, scripts, files = {}, 0, 0
local function check(file: string)
	files += 1
	local ok, roots = pcall(function()
		local bytes = fs.readFile(file)
		return if file:match("%.rbxlx?$")
			then roblox.deserializePlace(bytes):GetChildren()
			else roblox.deserializeModel(bytes)
	end)
	if not ok then
		table.insert(findings, `{file}: can't be read ({roots})`)
		return
	end
	for _, root in roots do
		for _, inst in { root, table.unpack(root:GetDescendants()) } do
			if inst.ClassName == "PackageLink" then
				table.insert(
					findings,
					`{file}: {pathOf(inst)}: a PackageLink (updates itself from someone else's copy)`
				)
			elseif inst:IsA("LuaSourceContainer") then
				scripts += 1
				local source = inst.Source or ""
				local why = {}
				for _, rule in RISKY do
					local at = source:find(rule[2])
					if at then
						table.insert(why, `{rule[1]} (line {lineOf(source, at)})`)
					end
				end
				if hiddenCode(source) then
					table.insert(why, `code hidden after {HIDDEN_BLANKS}+ blanks on one line`)
				end
				table.insert(
					findings,
					`{file}: {pathOf(inst)} ({inst.ClassName}){if #why > 0
						then ": DANGEROUS, " .. table.concat(why, "; ")
						else ": a script in a model (our code goes in src/)"}`
				)
			end
		end
	end
end

local function walk(dir: string)
	if not fs.isDir(dir) then
		return
	end
	for _, entry in fs.readDir(dir) do
		local path = `{dir}/{entry}`
		if fs.isDir(path) then
			walk(path)
		elseif entry:match("%.rbx[ml]x?$") then
			check(path)
		end
	end
end

for _, dir in DIRS do
	walk(dir)
end

if #findings > 0 then
	print(
		`[model-scripts] {#findings} script(s) or link(s) in the models (other people's code must not reach the game):`
	)
	for i, f in findings do
		if i > 40 then
			print(`  ... and {#findings - 40} more`)
			break
		end
		print(`  - {f}`)
	end
	process.exit(1)
end
print(`[model-scripts] {files} model files, no scripts or package links in them.`)
