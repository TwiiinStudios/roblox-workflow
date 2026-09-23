--[[
	Builds the complete game from the files in this repo:   build/game.rbxl

	    lune run tools/build.luau

	Everything (code, map, lighting, assets) comes from files, so the result is always
	exactly what's committed. Open it in Studio, or publish it with tools/publish.luau.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local OUTPUT_FILE = "build/game.rbxl"

if not fs.isDir("build") then
	fs.writeDir("build")
end

local rojo = process.exec("rojo", { "build", "default.project.json", "--output", OUTPUT_FILE }, { stdio = "inherit" })
if not rojo.ok then
	print("\n[build] FAILED: rojo build failed (see the error above)")
	process.exit(1)
end

print(`[build] OK -> {OUTPUT_FILE}`)
