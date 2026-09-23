--[[
	Publishes build/game.rbxl to Roblox using the Open Cloud Place Publishing API.

	    lune run tools/publish.luau test
	    lune run tools/publish.luau live --yes      (live needs --yes, on purpose)

	Place IDs come from deploy.json. The API key comes from the ROBLOX_API_KEY
	environment variable, or from a git-ignored .env file (copy .env.example).
	Always run `lune run tools/build.luau` first.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local PLACE_FILE = "build/game.rbxl"

local function fail(message: string): never
	print(`\n[publish] FAILED: {message}`)
	process.exit(1)
	error(message)
end

local target = process.args[1]
if target ~= "test" and target ~= "live" then
	fail("usage: lune run tools/publish.luau <test|live> [--yes]")
end

if target == "live" and not table.find(process.args, "--yes") then
	fail("publishing to LIVE affects real players. Re-run with --yes if you are sure.")
end

local deploy = serde.decode("json", fs.readFile("deploy.json"))
local ids = deploy[target]
if not ids or (ids.universeId or 0) == 0 or (ids.placeId or 0) == 0 then
	fail(`deploy.json has no universeId/placeId for "{target}" yet`)
end

local function readApiKey(): string?
	local fromEnv = process.env.ROBLOX_API_KEY
	if fromEnv and fromEnv ~= "" then
		return fromEnv
	end
	if fs.isFile(".env") then
		for line in string.gmatch(fs.readFile(".env"), "[^\r\n]+") do
			local value = string.match(line, "^%s*ROBLOX_API_KEY%s*=%s*(.-)%s*$")
			if value and value ~= "" then
				return value
			end
		end
	end
	return nil
end

local apiKey = readApiKey()
if not apiKey then
	fail("no API key. Set ROBLOX_API_KEY or put it in .env (see .env.example)")
end

if not fs.isFile(PLACE_FILE) then
	fail(`{PLACE_FILE} not found. Run: lune run tools/build.luau`)
end

print(`[publish] uploading {PLACE_FILE} to {string.upper(target)} (place {ids.placeId})...`)

local response = net.request({
	url = `https://apis.roblox.com/universes/v1/{ids.universeId}/places/{ids.placeId}/versions?versionType=Published`,
	method = "POST",
	headers = {
		["x-api-key"] = apiKey,
		["Content-Type"] = "application/octet-stream",
	},
	body = fs.readFile(PLACE_FILE),
})

if not response.ok then
	fail(`Roblox answered {response.statusCode} {response.statusMessage}\n{response.body}`)
end

local ok, result = pcall(serde.decode, "json", response.body)
local version = if ok and result then result.versionNumber else "?"
print(`[publish] OK - {string.upper(target)} is now at version {version}`)
