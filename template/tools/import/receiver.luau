--[[
	A tiny local HTTP drop box: Studio posts JSON dumps here (tools/import/studio_dump.luau, run with
	the Studio MCP's execute_luau), each saved to <dir>/<name>.json. Studio can't write files, so this
	is how a model in Studio reaches the Lune builders (dump2rbxm.luau, assemble.luau).
	    lune run tools/import/receiver.luau <dir>        (port 8765; run it in the background)
]]
local net = require("@lune/net")
local fs = require("@lune/fs")
local process = require("@lune/process")

local dir = process.args[1]
if not fs.isDir(dir) then
	fs.writeDir(dir)
end

net.serve(8765, function(request)
	local name = (request.query.name or "dump"):gsub("[^%w_%-]", "")
	fs.writeFile(`{dir}/{name}.json`, request.body)
	print(`[receiver] saved {name}.json ({#request.body} bytes)`)
	return { status = 200, body = `ok {#request.body}` }
end)
print("[receiver] listening on http://localhost:8765")
