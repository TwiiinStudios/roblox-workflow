--[[
	A stand-in player for the cloud test, where no real player can join. It goes where the server's code takes a
	Player: Character, UserId (below 0, never a real account), Name, and every Instance method (attributes,
	children such as a Backpack) on a Folder behind it. Remotes.simulate(name, standIn, ...) sends a client event
	as it, through the very handlers a real client's event reaches.

	Its body is a plain humanoid (root, torso, head), anchored: there is no physics in the cloud test, and a
	test wants it to stand exactly where it was put.

		local StandIn = require(game:GetService("ServerStorage").CloudHelpers.StandIn)
		local player = StandIn.new(Vector3.new(0, 120, 0))
		local tool = player:hold("Sword", { Damage = 10 })
		Remotes.simulate("UseTool", player, player:aim(target)) -- (a remote the server answers with Remotes.serve)
		player:Destroy()
]]

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local StandIn = {}

local count = 0
local everyone = {}

local function part(name: string, size: Vector3, cf: CFrame, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Parent = parent
	return p
end

-- A stand-in standing (feet on `at`'s height minus 3: its root is at `at`), facing `facing` if given.
function StandIn.new(at: Vector3, facing: Vector3?): any
	count += 1
	local name = `StandIn{count}`
	local behind = Instance.new("Folder") -- what the Instance methods act on
	behind.Name = name
	behind.Parent = ServerStorage -- (not a real player: Players:GetPlayers() never lists it)

	local body = Instance.new("Model")
	body.Name = name
	local look = if facing then CFrame.lookAt(at, Vector3.new(facing.X, at.Y, facing.Z)) else CFrame.new(at)
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), look, body)
	root.Transparency = 1
	part("Torso", Vector3.new(2, 2, 1), look, body)
	part("Head", Vector3.new(2, 1, 1), look * CFrame.new(0, 1.5, 0), body)
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = body
	body.PrimaryPart = root
	body.Parent = Workspace

	local self = { Name = name, DisplayName = name, UserId = -count, Character = body, StandIn = true }
	local methods = {}
	-- a Tool named `toolName` in its hands (in its character, as an equipped tool is), with these attributes
	function methods.hold(_, toolName: string, attributes: { [string]: any }?): Tool
		local tool = Instance.new("Tool")
		tool.Name = toolName
		tool.RequiresHandle = false
		tool.CanBeDropped = false
		for key, value in attributes or {} do
			tool:SetAttribute(key, value)
		end
		tool.Parent = body
		return tool
	end
	-- the unit direction from its eyes (the head) to a point
	function methods.aim(_, point: Vector3): Vector3
		return (point - (body :: any).Head.Position).Unit
	end
	function methods.moveTo(_, to: Vector3, faceTo: Vector3?)
		body:PivotTo(if faceTo then CFrame.lookAt(to, Vector3.new(faceTo.X, to.Y, faceTo.Z)) else CFrame.new(to))
	end
	function methods.Destroy()
		body:Destroy()
		behind:Destroy()
		everyone[self] = nil
	end
	setmetatable(self, {
		__index = function(_, key)
			if methods[key] then
				return methods[key]
			end
			local value = (behind :: any)[key]
			if type(value) == "function" then
				return function(_, ...)
					return value(behind, ...)
				end
			end
			return value
		end,
		__tostring = function()
			return name
		end,
	})
	everyone[self] = true
	return self
end

-- Remove every stand-in still around (call at the end of a test).
function StandIn.clear()
	for standIn in everyone do
		standIn:Destroy()
	end
end

return StandIn
