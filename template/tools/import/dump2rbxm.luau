--[[
	Builds assets/Captured/<Name>.rbxm from JSON dumps of a model's MeshParts taken in Studio
	(rows of {name, modelPath, cframe12, size3, meshId, textureId, color3, material, transparency}).
	    lune run tools/import/dump2rbxm.luau <Name> <dumpDir> <out.rbxm>
	Every dump file named <Name>_*.json in dumpDir is read, in order.
]]
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local name, dir, out = process.args[1], process.args[2], process.args[3]
local files = {}
for _, f in fs.readDir(dir) do
	if f:sub(1, #name + 1) == name .. "_" and f:sub(-5) == ".json" then
		table.insert(files, f)
	end
end
table.sort(files)
assert(#files > 0, "no dumps for " .. name)

local root = roblox.Instance.new("Model")
root.Name = name
local folders: { [string]: any } = { [""] = root }
local function modelAt(path: string)
	if folders[path] then
		return folders[path]
	end
	local parentPath, leaf = path:match("^(.*)/([^/]+)$")
	if not parentPath then
		parentPath, leaf = "", path
	end
	local m = roblox.Instance.new("Model")
	m.Name = leaf
	m.Parent = modelAt(parentPath)
	folders[path] = m
	return m
end

local count = 0
for _, f in files do
	local rows = serde.decode("json", fs.readFile(`{dir}/{f}`))
	for _, row in rows do
		local part = roblox.Instance.new("MeshPart")
		part.Name = row[1]
		local c = row[3]
		part.CFrame = roblox.CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
		part.Size = roblox.Vector3.new(row[4][1], row[4][2], row[4][3])
		part.MeshId = row[5]
		part.TextureID = row[6]
		part.Color = roblox.Color3.new(row[7][1], row[7][2], row[7][3])
		part.Material = roblox.Enum.Material[row[8]]
		part.Transparency = row[9]
		-- The mesh's native size: without it Roblox draws the mesh as if it were 1 stud (giant planes).
		local native = row[10]
		part.InitialSize = if native then roblox.Vector3.new(native[1], native[2], native[3]) else part.Size
		part.Anchored = true
		part.CanCollide = true
		part.Parent = modelAt(row[2])
		count += 1
	end
end
fs.writeFile(out, roblox.serializeModel({ root }))
print(`[dump2rbxm] {out}: {count} mesh parts in {#files} dumps`)
