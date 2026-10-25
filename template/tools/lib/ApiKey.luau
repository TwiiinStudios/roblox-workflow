--[[
	Finds the Roblox Open Cloud key for the tools (publish, cloud tests). Never prints it.

	Order: the git-ignored .env here, then the .env of the main checkout (an agent works in its own
	worktree, which has no .env of its own), then the ROBLOX_API_KEY environment variable (GitHub
	Actions). .env comes first: on a PC an old ROBLOX_API_KEY left in the system's environment quietly
	won over it once.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local function fromFile(path: string): string?
	if not fs.isFile(path) then
		return nil
	end
	for line in string.gmatch(fs.readFile(path), "[^\r\n]+") do
		local value = string.match(line, "^%s*ROBLOX_API_KEY%s*=%s*(.-)%s*$")
		if value and value ~= "" then
			return value
		end
	end
	return nil
end

-- The main checkout's folder when this is a git worktree (its shared .git lives there), else nil.
local function mainCheckout(): string?
	local result = process.exec("git", { "rev-parse", "--path-format=absolute", "--git-common-dir" })
	if not result.ok then
		return nil
	end
	local common = string.gsub(result.stdout, "%s+$", "")
	return string.match(common, "^(.*)[/\\]%.git$")
end

return function(): string?
	local here = fromFile(".env")
	if here then
		return here
	end
	local main = mainCheckout()
	local there = main and fromFile(`{main}/.env`)
	if there then
		return there
	end
	local fromEnv = process.env.ROBLOX_API_KEY
	if fromEnv and fromEnv ~= "" then
		return fromEnv
	end
	return nil
end
