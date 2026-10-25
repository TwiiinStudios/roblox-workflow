--[[
	Builds assets/Captured/<Name>.rbxm for a merged model:
	  - the merged MeshParts from a Studio dump (positions relative to the mesh bounding-box centre),
	    visual only (no collision, no queries, no touch);
	  - a "Colliders" model of box Parts from <file>.colliders.json (file space: x and z flip into
	    Roblox space, as Import 3D turns models 180 degrees); boxes that line up are joined;
	  - kept from the old .rbxm: its position, pivot and scale, and its lights and effects (fire,
	    smoke, particles) on small invisible parts where they were.
	  - its doors (<file>.doors.json, from tools/merge_model.py --doors): each door's meshes stay in
	    their own model, which gets a Hinge marker, a Slab (the invisible box you bump into) and the
	    turns that shut and open it (attributes Door, ShutTurn, OpenTurn, StartsOpen, for the game's door code);
	  - the old model's LootSpots (invisible marker parts a game may place things on), where they were.
	    lune run tools/import/assemble.luau <Name> <dump.json> <colliders.json> <old.rbxm> <out.rbxm> <unit> [doors.json]
	`unit`: how many studs one stud of the captured model becomes in the game (the scale your builder
	places it with, e.g. 2.78 for a prop modelled in metres); the size rules below are in game studs.
]]
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3
local name, dumpPath, colliderPath, oldPath, outPath, unitArg, doorsPath = table.unpack(process.args)
local unit = tonumber(unitArg) or 1

local INSET = 0.12 -- a drawn box sits half this far inside its piece's faces (never shows, never flickers)
local THIN = 0.4 -- (game studs) an odd-shaped piece thinner than this gets no box (ropes, poles)
local CLUTTER = 1.5 -- (game studs) a piece no longer than this gets no box (it never collided)
local DRAWN = 4 -- (game studs) a closed box at least this long is drawn (walls: the camera stops
-- at it); shorter ones (furniture, bits) are invisible, so they cost nothing to draw
local EFFECTS = {
	PointLight = true,
	SpotLight = true,
	SurfaceLight = true,
	Fire = true,
	Smoke = true,
	Sparkles = true,
	ParticleEmitter = true,
}

local old = roblox.deserializeModel(fs.readFile(oldPath))[1]
local data = serde.decode("json", fs.readFile(colliderPath))

-- the old model's mesh bounding box (the same measure the dump used)
local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
local effects = {}
for _, d in old:GetDescendants() do
	if d:IsA("MeshPart") then
		local cf, s = d.CFrame, d.Size / 2
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = cf * Vector3.new(sx * s.X, sy * s.Y, sz * s.Z)
					lo = Vector3.new(math.min(lo.X, p.X), math.min(lo.Y, p.Y), math.min(lo.Z, p.Z))
					hi = Vector3.new(math.max(hi.X, p.X), math.max(hi.Y, p.Y), math.max(hi.Z, p.Z))
				end
			end
		end
	elseif EFFECTS[d.ClassName] then
		table.insert(effects, d)
	end
end
local centre = (lo + hi) / 2
local oldSize = hi - lo
-- the old model may have been scaled up in Studio after its import (a stack of pallets at 3x)
local k = (oldSize.X / data.size[1] + oldSize.Y / data.size[2] + oldSize.Z / data.size[3]) / 3
if math.abs(k - 1) < 0.01 then
	k = 1
end
local game = k * unit -- game studs per file unit
local function at(rel: any): any
	return CFrame.new(centre.X, centre.Y, centre.Z) * rel
end

local root = roblox.Instance.new("Model")
root.Name = name
local ok, pivot = pcall(function()
	return old.WorldPivotData
end)
if ok and pivot then
	root.WorldPivotData = pivot
end

local models: { [string]: any } = { [""] = root }
local function modelAt(path: string)
	if models[path] then
		return models[path]
	end
	local parentPath, leaf = path:match("^(.*)/([^/]+)$")
	if not parentPath then
		parentPath, leaf = "", path
	end
	local m = roblox.Instance.new("Model")
	m.Name = leaf
	m.Parent = modelAt(parentPath)
	models[path] = m
	return m
end

local meshes = 0
for _, row in serde.decode("json", fs.readFile(dumpPath)) do
	local part = roblox.Instance.new("MeshPart")
	part.Name = row[1]
	local c = row[3]
	part.CFrame = at(CFrame.new(c[1] * k, c[2] * k, c[3] * k, c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12]))
	part.Size = Vector3.new(row[4][1], row[4][2], row[4][3]) * k
	part.MeshId = row[5]
	if row[6] ~= "" then
		part.TextureID = row[6]
		part.TextureContent = roblox.Content.fromUri(row[6])
	end
	part.Color = Color3.new(row[7][1], row[7][2], row[7][3])
	part.Material = roblox.Enum.Material[row[8]]
	part.Transparency = row[9]
	part.InitialSize = Vector3.new(row[10][1], row[10][2], row[10][3])
	part.Anchored = true
	-- the look only: the Colliders below are what you walk on and shoot at
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	-- a small prop's shadow is a smudge nobody sees, and a shadow doubles the drawing
	part.CastShadow = math.max(part.Size.X, part.Size.Y, part.Size.Z) * unit >= DRAWN
	local sa = row[11]
	if sa then
		local look = roblox.Instance.new("SurfaceAppearance")
		look.ColorMap = sa[1]
		look.AlphaMode = roblox.Enum.AlphaMode[sa[2]]
		look.EmissiveStrength = sa[3]
		look.EmissiveTint = Color3.new(sa[4][1], sa[4][2], sa[4][3])
		if sa[5] ~= "" then
			look.EmissiveMaskContent = roblox.Content.fromUri(sa[5])
		end
		look.Parent = part
	end
	part.Parent = modelAt(row[2])
	meshes += 1
end

-- Which boxes become colliders, in file space.
local boxes = {}
local skipped = 0
for _, box in data.boxes do
	local size = { box.size[1] * game, box.size[2] * game, box.size[3] * game }
	local thinnest, longest = math.min(table.unpack(size)), math.max(table.unpack(size))
	local glass = box.name:find("glass") ~= nil and box.name:find("shard") == nil
	if longest <= CLUTTER or (not box.solid and (box.name:find("gable") or (thinnest < THIN and not glass))) then
		skipped += 1
	else
		table.insert(boxes, box)
	end
end

-- Join boxes that line up (a wall in five segments is one box): two axis-aligned boxes of the same
-- kind whose extents match on two axes and touch or overlap on the third are exactly one box.
local function aligned(box): boolean
	for _, axis in box.axes do
		local big = 0
		for _, v in axis do
			if math.abs(v) > 0.999 then
				big += 1
			elseif math.abs(v) > 0.001 then
				return false
			end
		end
		if big ~= 1 then
			return false
		end
	end
	return true
end
local EPS = 0.002
local flat, others = {}, {}
for _, box in boxes do
	if aligned(box) then
		-- its world-axis extents: each box axis lies along one world axis
		local ext = { 0, 0, 0 }
		for i, axis in box.axes do
			for w = 1, 3 do
				if math.abs(axis[w]) > 0.999 then
					ext[w] = box.size[i]
				end
			end
		end
		table.insert(flat, {
			lo = { box.centre[1] - ext[1] / 2, box.centre[2] - ext[2] / 2, box.centre[3] - ext[3] / 2 },
			hi = { box.centre[1] + ext[1] / 2, box.centre[2] + ext[2] / 2, box.centre[3] + ext[3] / 2 },
			solid = box.solid,
		})
	else
		table.insert(others, box)
	end
end
local before = #flat
local joined = true
while joined do
	joined = false
	local i = 1
	while i <= #flat do
		local a = flat[i]
		local j = i + 1
		while j <= #flat do
			local b = flat[j]
			if a.solid == b.solid then
				local same, touch = 0, 0
				for w = 1, 3 do
					if math.abs(a.lo[w] - b.lo[w]) < EPS and math.abs(a.hi[w] - b.hi[w]) < EPS then
						same += 1
					elseif b.lo[w] <= a.hi[w] + EPS and a.lo[w] <= b.hi[w] + EPS then
						touch += 1
					end
				end
				if same == 3 or (same == 2 and touch == 1) then
					for w = 1, 3 do
						a.lo[w] = math.min(a.lo[w], b.lo[w])
						a.hi[w] = math.max(a.hi[w], b.hi[w])
					end
					table.remove(flat, j)
					joined = true
					continue
				end
			end
			j += 1
		end
		i += 1
	end
end

local colliders = roblox.Instance.new("Model")
colliders.Name = "Colliders"
colliders.Parent = root
local drawn, hidden = 0, 0
-- Studio's File > Import 3D turns a model 180 degrees (x and z flip from the file's space); a model
-- uploaded through Open Cloud has come in both ways (the Claude Design houses turned, house G from
-- tools/propgen/house.py not - its colliders came out mirrored). So it's measured: with a door, its
-- own meshes in the dump are compared with where doors.json puts it, turned and not; "--turned" or
-- "--unturned" says it outright. The answer is kept on the model (ImportTurned) for
-- tools/add_loot_spots.luau.
local turned = true
if table.find(process.args, "--unturned") then
	turned = false
elseif not table.find(process.args, "--turned") and doorsPath and fs.isFile(doorsPath) then
	local plan = serde.decode("json", fs.readFile(doorsPath))[1]
	local sum, n = Vector3.zero, 0
	for _, row in serde.decode("json", fs.readFile(dumpPath)) do
		if plan and row[2] == plan.group then
			sum += Vector3.new(row[3][1], row[3][2], row[3][3]) * k
			n += 1
		end
	end
	if plan and n > 0 then
		local seen = sum / n
		local c = plan.leaf.centre
		local asIs = Vector3.new(c[1], c[2], c[3]) * k
		local flipped = Vector3.new(-c[1], c[2], -c[3]) * k
		turned = (seen - flipped).Magnitude <= (seen - asIs).Magnitude
		print(
			`[assemble] {name}: the import {if turned then "turned the model round" else "kept the file's facing"} (by its door)`
		)
	end
end
root:SetAttribute("ImportTurned", turned)
local function flip(v: { number }): any
	if not turned then
		return Vector3.new(v[1], v[2], v[3])
	end
	return Vector3.new(-v[1], v[2], -v[3])
end
local function place(rel: any, size: any, solid: boolean)
	local part = roblox.Instance.new("Part")
	part.Name = "Collider"
	part.Anchored = true
	part.CanTouch = false
	part.CastShadow = false
	part.Material = roblox.Enum.Material.SmoothPlastic
	part.Color = Color3.new(0.1, 0.1, 0.1)
	part.CFrame = at(rel)
	local longest = math.max(size.X, size.Y, size.Z) * unit
	if solid and longest >= DRAWN then
		-- opaque, so the camera stops at it as at a wall; just inside the piece's faces, so it never shows
		part.Size =
			Vector3.new(math.max(size.X - INSET, 0.02), math.max(size.Y - INSET, 0.02), math.max(size.Z - INSET, 0.02))
		drawn += 1
	else
		part.Size = size
		part.Transparency = 1
		hidden += 1
	end
	part.Parent = colliders
end
for _, b in flat do
	local c = { (b.lo[1] + b.hi[1]) / 2 * k, (b.lo[2] + b.hi[2]) / 2 * k, (b.lo[3] + b.hi[3]) / 2 * k }
	local pos = flip(c)
	place(
		CFrame.new(pos.X, pos.Y, pos.Z),
		Vector3.new(b.hi[1] - b.lo[1], b.hi[2] - b.lo[2], b.hi[3] - b.lo[3]) * k,
		b.solid
	)
end
for _, box in others do
	local c = { box.centre[1] * k, box.centre[2] * k, box.centre[3] * k }
	local rel = CFrame.fromMatrix(flip(c), flip(box.axes[1]), flip(box.axes[2]), flip(box.axes[3]))
	place(rel, Vector3.new(box.size[1], box.size[2], box.size[3]) * k, box.solid)
end

-- lights and effects (the bunker's lamps, a barrel's fire): each on a small invisible part where it was
for _, effect in effects do
	local host = effect.Parent
	local position
	if host:IsA("Attachment") then
		local holder = host.Parent
		position = (holder.CFrame * host.CFrame).Position
	elseif host:IsA("BasePart") then
		position = host.CFrame.Position
	end
	if position then
		local holder = roblox.Instance.new("Part")
		holder.Name = "effect_point"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CastShadow = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(position.X, position.Y, position.Z)
		effect:Clone().Parent = holder
		holder.Parent = root
	end
end

-- the doors: hinge, slab and turns (file space: x and z flip, a turn about Y stays the same)
local doorCount = 0
if doorsPath then
	for _, d in serde.decode("json", fs.readFile(doorsPath)) do
		local door = models[d.group]
		if door then
			doorCount += 1
			door.Name = "Door"
			door:SetAttribute("Door", true)
			door:SetAttribute("ShutTurn", d.shutTurn)
			door:SetAttribute("OpenTurn", d.openTurn)
			door:SetAttribute("StartsOpen", d.startsOpen)
			local function marker(partName: string)
				local p = roblox.Instance.new("Part")
				p.Name = partName
				p.Anchored = true
				p.CanTouch = false
				p.CastShadow = false
				p.Transparency = 1
				p.Material = roblox.Enum.Material.SmoothPlastic
				p.Parent = door
				return p
			end
			local hinge = marker("Hinge")
			hinge.Size = Vector3.new(0.2, 0.2, 0.2)
			hinge.CanCollide = false
			hinge.CanQuery = false
			local hp = flip(d.hinge) * k
			hinge.CFrame = at(CFrame.new(hp.X, hp.Y, hp.Z))
			local slab = marker("Slab")
			local c = flip(d.leaf.centre) * k
			local along = flip(d.leaf.along)
			local across = Vector3.new(0, 1, 0):Cross(along)
			slab.CFrame = at(CFrame.fromMatrix(c, along, Vector3.new(0, 1, 0), across))
			slab.Size = Vector3.new(d.leaf.size[1], d.leaf.size[2], d.leaf.size[3]) * k
			slab.CanCollide = true
			slab.CanQuery = true
		end
	end
end

-- the loot spots (LootService's), where they were in the old model
local loot = 0
for _, d in old:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "LootSpot" then
		d:Clone().Parent = root
		loot += 1
	end
end

fs.writeFile(outPath, roblox.serializeModel({ root }))
print(`[assemble] {name}: {doorCount} doors, {loot} loot spots`)
print(
	`[assemble] {name}: {meshes} meshes (x{string.format("%.2f", k)}), {drawn} drawn + {hidden} hidden colliders ({before + #others} before joining, {skipped} skipped), {#effects} effects`
)
