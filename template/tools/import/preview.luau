--[[
	The visual pass (the import-model skill, step 6): run in Studio (Edit) with the Studio MCP's execute_luau after
	setting the three lines below. It puts a copy of a captured model at the size the game shows it, in empty air
	(PREVIEW_AT), and returns the camera positions to look at it from: each side at an angle, straight down, far
	away, and close up to each part inside it (a door, a lid, a model of its own). Take a screen_capture from every
	one (camera_position + look_at_position) and look at each picture: stretched or squashed pixels, flicker
	(stripes that change between two pictures from almost the same spot), missing or wrong textures, gaps, floating
	or sunken pieces. Then run it with CLEAN = true to remove the copy.

	Edit-mode pictures are drawn even while Studio is in the background (pictures in play mode aren't), but not while
	its window is minimized: an empty dark picture means restore it without taking the human's focus (PowerShell:
	user32 ShowWindow(handle, 4), the import-model skill). Take one picture at a time: several at once time out.
	Not a module: tools/check doesn't run it, and the game never loads it (it isn't under src/).
]]

local NAME = "MyModel" -- the model in ReplicatedStorage.Assets.Captured
local SCALE = 1 -- the size the game shows it at (the scale your builder places it with); 1 for most
local CLEAN = false -- true: remove the preview and stop

local PREVIEW_AT = Vector3.new(0, 400, 0)

local old = workspace:FindFirstChild("_Preview")
if old then
	old:Destroy()
end
if CLEAN then
	return "removed"
end

local captured = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("Captured")
local source = captured:WaitForChild(NAME, 10)
assert(source and source:IsA("Model"), `no Assets.Captured.{NAME}`)
local preview = source:Clone()
preview.Name = "_Preview"
if SCALE ~= 1 then
	preview:ScaleTo(SCALE)
end
preview:PivotTo(CFrame.new(PREVIEW_AT))
preview.Parent = workspace

local cf, size = preview:GetBoundingBox()
local centre = cf.Position
local reach = size.Magnitude
local shots = {}
local function shot(name: string, from: Vector3, at: Vector3)
	table.insert(shots, {
		name = name,
		camera_position = {
			math.round(from.X * 100) / 100,
			math.round(from.Y * 100) / 100,
			math.round(from.Z * 100) / 100,
		},
		look_at_position = { math.round(at.X * 100) / 100, math.round(at.Y * 100) / 100, math.round(at.Z * 100) / 100 },
	})
end

-- each side from above at an angle, then straight down, then far away
for i, side in { "north", "east", "south", "west" } do
	local angle = math.rad((i - 1) * 90 + 45)
	shot(`{side} side`, centre + Vector3.new(math.cos(angle), 0.55, math.sin(angle)) * reach * 0.9, centre)
end
shot("from above", centre + Vector3.new(0.01, reach * 1.1, 0), centre)
shot("far away (as a player sees it coming)", centre + Vector3.new(reach * 3.5, reach * 0.6, reach * 2.5), centre)
-- close up to every part that is a model of its own (doors, lids, ...), from the two best sides with a clear view:
-- a door down a shaft is seen from inside the shaft, not through its wall
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { preview }
local function clearViews(target: Instance, at: Vector3, distance: number): { Vector3 }
	local views = {}
	for _, up in { 0.45, 0.15, 0.8 } do
		for a = 0, 330, 30 do
			local dir = Vector3.new(math.cos(math.rad(a)), up, math.sin(math.rad(a))).Unit
			local hit = workspace:Raycast(at, dir * distance, params)
			-- clear, or the first thing in the way is the part itself
			if not hit or hit.Instance:IsDescendantOf(target) then
				table.insert(views, at + dir * distance)
			end
		end
	end
	return views
end
for _, part in preview:GetChildren() do
	if part:IsA("Model") then
		local pcf, psize = part:GetBoundingBox()
		local views = {}
		for _, d in { math.max(psize.Magnitude * 1.4, 3), math.max(psize.Magnitude * 0.8, 2), 1.5 } do
			views = clearViews(part, pcf.Position, d)
			if #views > 0 then
				break
			end
		end
		for i, from in views do
			if i > 2 then
				break
			end
			shot(`close up: {part.Name}`, from, pcf.Position)
		end
		if #views == 0 then
			shot(
				`close up: {part.Name} (no clear view: look from inside)`,
				pcf.Position + Vector3.new(0, 0.5, 0),
				pcf.Position
			)
		end
	end
end
-- and close to the biggest surfaces (where stretched pixels and flicker show most)
local parts = {}
for _, p in preview:GetDescendants() do
	if p:IsA("BasePart") then
		table.insert(parts, p)
	end
end
table.sort(parts, function(a, b)
	return a.Size.Magnitude > b.Size.Magnitude
end)
for i = 1, math.min(3, #parts) do
	local p = parts[i]
	shot(
		`close up: {p.Name}`,
		p.Position + (p.CFrame.LookVector + Vector3.new(0.4, 0.5, 0.3)).Unit * math.max(p.Size.Magnitude * 0.45, 2.5),
		p.Position
	)
end
return shots
