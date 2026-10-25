--[[
	Error reports: script errors on real servers (ScriptContext.Error) and on players' devices
	(Remotes.ClientError from ErrorReportController) are grouped and counted (Shared.ErrorReport), and every
	Config.ERROR_REPORTS.EVERY seconds sent as one batch to our Discord bot's bridge, which posts a daily
	summary to the staff. Nothing that names a player is sent: only the error, where, how often, how many players.

	Client reports are untrusted: cleaned, only our own scripts, rate-limited per player, only counted.
	The bridge key is the experience secret Config.ERROR_REPORTS.SECRET (Creator Dashboard -> Secrets).
	Off in Studio, in the cloud test and without the secret; it never prints a warning (a failed send is dropped).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Config = require(ReplicatedStorage.Shared.Config)
local ErrorReport = require(ReplicatedStorage.Shared.ErrorReport)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ErrorReportService = {}

local SETTINGS = Config.ERROR_REPORTS

local batch = ErrorReport.newBatch()
local secret: any = nil
local recent: { [Player]: { number } } = {} -- each player's report times in the last minute
local total: { [Player]: number } = {}

local function enabled(): boolean
	return secret ~= nil
end

local function onServerError(message: string, stack: string, origin: Instance?)
	if not enabled() then
		return
	end
	local where = ErrorReport.clean(origin and origin:GetFullName() or "?", ErrorReport.MAX_WHERE)
	ErrorReport.add(
		batch,
		"server",
		where,
		ErrorReport.clean(message, ErrorReport.MAX_MESSAGE),
		ErrorReport.clean(stack, ErrorReport.MAX_STACK),
		nil
	)
end

local function onClientError(player: Player, message: unknown, stack: unknown, where: unknown)
	if not enabled() then
		return
	end
	local now = os.clock()
	local times = recent[player] or {}
	while times[1] and now - times[1] > 60 do
		table.remove(times, 1)
	end
	if #times >= SETTINGS.CLIENT_PER_MINUTE or (total[player] or 0) >= SETTINGS.CLIENT_PER_SESSION then
		return
	end
	local report = ErrorReport.fromClient(message, stack, where)
	if not report then
		return
	end
	table.insert(times, now)
	recent[player] = times
	total[player] = (total[player] or 0) + 1
	ErrorReport.add(batch, "client", report.where, report.message, report.stack, player.UserId)
end

local function send()
	local errors, dropped = ErrorReport.drain(batch)
	if not enabled() or (#errors == 0 and dropped == 0) then
		return
	end
	local body = HttpService:JSONEncode({
		universeId = game.GameId,
		placeId = game.PlaceId,
		placeVersion = game.PlaceVersion,
		jobId = string.sub(game.JobId, 1, 8),
		players = #Players:GetPlayers(),
		dropped = dropped,
		errors = errors,
	})
	pcall(function()
		HttpService:RequestAsync({
			Url = SETTINGS.URL,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json", Authorization = secret:AddPrefix("Bearer ") },
			Body = body,
		})
	end)
end

function ErrorReportService:Init() end

function ErrorReportService:Start()
	Players.PlayerRemoving:Connect(function(player)
		recent[player] = nil
		total[player] = nil
	end)
	if RunService:IsStudio() or game.GameId == 0 or game:GetAttribute("CloudTest") then
		return
	end
	local ok, value = pcall(function()
		return HttpService:GetSecret(SETTINGS.SECRET)
	end)
	if not ok then
		print(`[ErrorReport] off: the experience has no secret {SETTINGS.SECRET}`)
		return
	end
	secret = value
	ScriptContext.Error:Connect(onServerError)
	Remotes.serve("ClientError", onClientError)
	game:BindToClose(send)
	while true do
		task.wait(SETTINGS.EVERY)
		send()
	end
end

return ErrorReportService
