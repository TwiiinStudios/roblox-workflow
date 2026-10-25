--[[
	Downloads one Library item's file (an icon, a model, a UI kit…) from the task board, by the two-hour link the
	board's get_library_item gives (agents can't use curl):
	    lune run tools/library/get.luau "<link>" <path in this repo> [--force]

	Only links of the board's Library (https://tasks.twiiinstudio.cloud/dl/library/…), only into this repository
	(a relative path, no "..", not into .git or a hidden folder), never over an existing file unless --force.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local link, dest = process.args[1], process.args[2]
local force = table.find(process.args, "--force") ~= nil
local function fail(message: string): never
	print(`get.luau: {message}`)
	return process.exit(1)
end
if not link or not dest then
	fail('usage: lune run tools/library/get.luau "<link from get_library_item>" <path in the repo> [--force]')
end
if not string.match(link, "^https://tasks%.twiiinstudio%.cloud/dl/library/%d+%?exp=%d+&sig=%x+$") then
	fail("only a Library link from the task board (get_library_item) can be downloaded")
end
local clean = string.gsub(dest, "\\", "/")
if
	string.match(clean, "^/")
	or string.match(clean, "^%a:")
	or string.find(clean, "%.%.")
	or string.match(clean, "^%.")
	or string.find(clean, "/%.")
then
	fail("the path must be inside this repository (relative, no '..', no hidden folders)")
end
if fs.isFile(clean) and not force then
	fail(`{clean} is already there (add --force to replace it)`)
end

local response = net.request({ url = link, method = "GET" })
if not response.ok then
	fail(`the board said {response.statusCode}: {response.body}`)
end
if #response.body > 60 * 1024 * 1024 then
	fail("that file is bigger than 60 MB")
end
local folder = string.match(clean, "^(.*)/[^/]+$")
if folder and not fs.isDir(folder) then
	fs.writeDir(folder)
end
fs.writeFile(clean, response.body)
print(`{clean}: {#response.body} bytes`)
