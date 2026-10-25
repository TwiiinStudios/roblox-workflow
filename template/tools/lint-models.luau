--[[
	Every captured model must carry its meshes' native sizes. A MeshPart file needs InitialSize next to
	its MeshId: without it Roblox scales each mesh as if it were 1 stud big, and the model shows up as
	giant black/grey planes (it happened to the whole starting city once, 2026-10-10). Models saved by
	Studio always have it; models assembled by a script (e.g. from a dump) must set it.

	    lune run tools/lint-models.luau      (a step in tools/check.luau)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local bad = {}
local function walk(dir: string)
	if not fs.isDir(dir) then
		return
	end
	for _, entry in fs.readDir(dir) do
		local path = dir .. "/" .. entry
		if fs.isDir(path) then
			walk(path)
		elseif entry:sub(-5) == ".rbxm" then
			local data = fs.readFile(path)
			-- The binary format names each property once per class chunk, so a file with mesh parts
			-- lists "MeshContent"; it must list "InitialSize" too.
			if data:find("MeshContent", 1, true) and not data:find("InitialSize", 1, true) then
				table.insert(bad, path)
			end
		end
	end
end
walk("assets")
walk("world")

if #bad > 0 then
	for _, path in bad do
		print("  " .. path .. ": mesh parts without InitialSize (they'll render as giant planes)")
	end
	print(
		`\n[models] FAILED: {#bad} model files lack mesh sizes. Set each MeshPart's InitialSize to its native mesh size.`
	)
	process.exit(1)
end
print("[models] OK - every captured model carries its mesh sizes")
