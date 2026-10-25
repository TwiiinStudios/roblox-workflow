--[[
	Error reports (pure logic, no Roblox APIs; ErrorReportService and ErrorReportController use it).
	Script errors from real games are grouped by what went wrong and where, counted, and sent in a batch
	every few minutes to our Discord bot, which posts a daily summary for the staff.

	Privacy and safety: nothing that names a player leaves the game. Player names in paths become
	"<player>", only counts are kept (how many times, how many players), and every text is cut short.
	Client errors arrive through a remote, so anything in them is untrusted: they're cleaned here, must
	come from our own scripts, and the bot only lists one once several players had it.
]]

local ErrorReport = {}

ErrorReport.MAX_MESSAGE = 300
ErrorReport.MAX_STACK = 600
ErrorReport.MAX_WHERE = 160
ErrorReport.MAX_GROUPS = 60 -- distinct errors kept per batch; more are counted as "dropped"

-- Client scripts that are ours: errors from anything else (Roblox's own UI, injected scripts) are ignored.
local OUR_CLIENT_PATHS = { "%.PlayerScripts%.Client", "^ReplicatedStorage%.Shared", "^ReplicatedStorage%.Packages" }

--- One line of text: no control characters, no player names in paths, short.
function ErrorReport.clean(text: unknown, max: number): string
	if type(text) ~= "string" then
		return ""
	end
	local out = text:sub(1, max * 4) -- (cut early: a huge string from a client shouldn't cost much)
	out = out:gsub("[%c]+", " ")
	out = out:gsub("Players%.[^%.%s:]+", "Players.<player>")
	out = out:gsub("%s+", " ")
	out = out:match("^%s*(.-)%s*$") or ""
	if #out > max then
		out = out:sub(1, max - 1) .. "…"
	end
	return out
end

--- Errors that differ only in numbers (a position, an id, a line count) belong together.
function ErrorReport.key(side: string, where: string, message: string): string
	return `{side}|{where}|{(message:gsub("%d+", "#"))}`
end

--- A client's report, cleaned; nil when it isn't one of ours or isn't text.
function ErrorReport.fromClient(
	message: unknown,
	stack: unknown,
	where: unknown
): { message: string, stack: string, where: string }?
	if type(message) ~= "string" or type(where) ~= "string" or (stack ~= nil and type(stack) ~= "string") then
		return nil
	end
	local cleanWhere = ErrorReport.clean(where, ErrorReport.MAX_WHERE)
	local ours = false
	for _, pattern in OUR_CLIENT_PATHS do
		if cleanWhere:find(pattern) then
			ours = true
			break
		end
	end
	local cleanMessage = ErrorReport.clean(message, ErrorReport.MAX_MESSAGE)
	if not ours or cleanMessage == "" then
		return nil
	end
	return { message = cleanMessage, stack = ErrorReport.clean(stack, ErrorReport.MAX_STACK), where = cleanWhere }
end

export type Group = {
	side: string,
	where: string,
	message: string,
	stack: string,
	count: number,
	players: number,
}

export type Batch = {
	groups: { [string]: Group & { seen: { [any]: boolean } } },
	size: number,
	dropped: number,
}

function ErrorReport.newBatch(): Batch
	return { groups = {}, size = 0, dropped = 0 }
end

--- Count one error. `who` tells players apart (any value; it never leaves the game).
function ErrorReport.add(batch: Batch, side: string, where: string, message: string, stack: string, who: any?)
	local key = ErrorReport.key(side, where, message)
	local group = batch.groups[key]
	if not group then
		if batch.size >= ErrorReport.MAX_GROUPS then
			batch.dropped += 1
			return
		end
		group = { side = side, where = where, message = message, stack = stack, count = 0, players = 0, seen = {} }
		batch.groups[key] = group
		batch.size += 1
	end
	group.count += 1
	if who ~= nil and not group.seen[who] then
		group.seen[who] = true
		group.players += 1
	end
end

--- What gets sent: the groups (most frequent first), without who had them.
function ErrorReport.drain(batch: Batch): ({ Group }, number)
	local list = {}
	for _, g in batch.groups do
		table.insert(list, {
			side = g.side,
			where = g.where,
			message = g.message,
			stack = g.stack,
			count = g.count,
			players = g.players,
		})
	end
	table.sort(list, function(a, b)
		return a.count > b.count
	end)
	local dropped = batch.dropped
	batch.groups, batch.size, batch.dropped = {}, 0, 0
	return list, dropped
end

return ErrorReport
