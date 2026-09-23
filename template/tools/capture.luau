--[[
	Saves things that were made INSIDE Studio back into the repo as files.

	    lune run tools/capture.luau                  (reads build/game.rbxl)
	    lune run tools/capture.luau path/to/place.rbxl

	Only two folders are captured (see capture.project.json):
	    Workspace.Map.Captured          ->  world/Map/Captured/
	    ReplicatedStorage.Assets.Captured -> assets/Captured/
	Everything else in the place is ignored, so hand-written files are never touched.

	Steps:
	  1. In Studio, move the new things into one of the Captured folders.
	  2. Save the place (Ctrl+S) - it is usually build/game.rbxl.
	  3. Run this tool, check `git status`, commit.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local input = process.args[1] or "build/game.rbxl"

if not fs.isFile(input) then
	print(`[capture] FAILED: {input} not found. Save the place in Studio first (Ctrl+S).`)
	process.exit(1)
end

for _, dir in { "world/Map/Captured", "assets/Captured" } do
	if not fs.isDir(dir) then
		fs.writeDir(dir)
	end
end

local result = process.exec(
	"rojo",
	{ "syncback", "capture.project.json", "--input", input, "--non-interactive" },
	{ stdio = "inherit" }
)
if not result.ok then
	print("\n[capture] FAILED: rojo syncback failed (see the error above)")
	process.exit(1)
end

-- syncback removes files it doesn't know about; keep the folders in git
for _, dir in { "world/Map/Captured", "assets/Captured" } do
	if not fs.isFile(`{dir}/.gitkeep`) then
		fs.writeFile(`{dir}/.gitkeep`, "")
	end
end

print("\n[capture] Done. Changes:")
process.exec("git", { "status", "--short", "--", "world/Map/Captured", "assets/Captured" }, { stdio = "inherit" })
