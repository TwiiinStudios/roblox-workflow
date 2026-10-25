--[[
	Run in Studio (Edit) with the Studio MCP's execute_luau, after setting the three lines below: sends
	the MeshParts of an imported model in Workspace to tools/import/receiver.luau (port 8765), one dump
	per model, for tools/import/dump2rbxm.luau (props) or tools/import/assemble.luau (merged buildings).

	Rows: { name, group, cframe12, size, meshId, textureId, colour, material, transparency, meshSize,
	surfaceAppearance? }. Positions are relative to the model's mesh bounding-box centre. `group` is
	"door_N" for a piece inside a door group (tools/merge_model.py --doors), the group's name for one
	inside a group named in KEEP (--keep), else "".

	Not a module: tools/check doesn't run it, and the game never loads it (it isn't under src/).
]]

local SOURCE = "my_props" -- the imported model's name in Workspace
local EACH_CHILD = true -- true: one dump per child model (a batch of props); false: the whole model
local INSIDE = "" -- (EACH_CHILD) the folder inside SOURCE that holds the props, or "" for SOURCE itself
local KEEP = {} -- groups kept whole by tools/merge_model.py --keep (e.g. { lid = true, door = true }): their own models

local HttpService = game:GetService("HttpService")

local function dump(model: Instance, name: string): string
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			table.insert(parts, d)
			local cf, s = d.CFrame, d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = cf * Vector3.new(sx * s.X, sy * s.Y, sz * s.Z)
						lo, hi = lo:Min(p), hi:Max(p)
					end
				end
			end
		end
	end
	local mid = (lo + hi) / 2
	local rows = {}
	for _, d in parts do
		local group = ""
		local a = d.Parent
		while a and a ~= model do
			if a.Name:match("^door_%d+$") or KEEP[a.Name] then
				group = a.Name
				break
			end
			a = a.Parent
		end
		local rel = CFrame.new(-mid) * d.CFrame
		local row: { any } = {
			d.Name,
			group,
			{ rel:GetComponents() },
			{ d.Size.X, d.Size.Y, d.Size.Z },
			d.MeshId,
			d.TextureID,
			{ d.Color.R, d.Color.G, d.Color.B },
			d.Material.Name,
			d.Transparency,
			{ d.MeshSize.X, d.MeshSize.Y, d.MeshSize.Z },
		}
		local sa = d:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			row[11] = {
				sa.ColorMap,
				sa.AlphaMode.Name,
				sa.EmissiveStrength,
				{ sa.EmissiveTint.R, sa.EmissiveTint.G, sa.EmissiveTint.B },
				"",
			}
		end
		table.insert(rows, row)
	end
	local unattached = 0
	for _, d in parts do
		if d.MeshSize.Magnitude == 0 then
			unattached += 1
		end
	end
	local reply = HttpService:PostAsync(`http://localhost:8765/?name={name}_01`, HttpService:JSONEncode(rows))
	return `{name}: {#rows} meshes ({unattached} unattached) -> {reply}`
end

local source = workspace:FindFirstChild(SOURCE)
assert(source, `no {SOURCE} in Workspace`)
local out = {}
if EACH_CHILD then
	local holder = if INSIDE == "" then source else source:FindFirstChild(INSIDE, true)
	assert(holder, `no {INSIDE} inside {SOURCE}`)
	for _, child in holder:GetChildren() do
		if child:IsA("Model") then -- (an uploaded model also holds a PackageLink)
			table.insert(out, dump(child, child.Name))
		end
	end
else
	table.insert(out, dump(source, SOURCE))
end
return table.concat(out, "\n")
