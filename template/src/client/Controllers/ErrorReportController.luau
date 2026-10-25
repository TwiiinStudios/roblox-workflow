--[[
	Error reports, the player's side: when one of the game's own scripts errors on this device, tell the
	server (Remotes.ClientError), which groups and counts it for the staff's daily summary
	(ErrorReportService). The same error goes once a minute at most, and a few dozen a session in all.
	Errors from Roblox's own scripts are ignored (the server checks that too).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local ErrorReport = require(ReplicatedStorage.Shared.ErrorReport)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ErrorReportController = {}

local SAME_ERROR_GAP = 60 -- seconds before the same error is reported again
local MAX_PER_SESSION = 30

local lastSent: { [string]: number } = {}
local sent = 0

local function onError(message: string, stack: string, origin: Instance?)
	if sent >= MAX_PER_SESSION or not origin then
		return
	end
	local where = origin:GetFullName()
	if not ErrorReport.fromClient(message, stack, where) then
		return -- (not one of ours)
	end
	local key = ErrorReport.key("client", where, message)
	local now = os.clock()
	if lastSent[key] and now - lastSent[key] < SAME_ERROR_GAP then
		return
	end
	lastSent[key] = now
	sent += 1
	Remotes.ClientError:FireServer(
		message:sub(1, ErrorReport.MAX_MESSAGE),
		stack:sub(1, ErrorReport.MAX_STACK),
		where:sub(1, ErrorReport.MAX_WHERE * 2)
	)
end

function ErrorReportController:Init() end

function ErrorReportController:Start()
	if RunService:IsStudio() then
		return -- (in Studio you see your errors in the output)
	end
	ScriptContext.Error:Connect(onError)
end

return ErrorReportController
