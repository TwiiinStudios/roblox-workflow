---
name: import-model
description: Bring a 3D model (.glb from Claude Design or the humans' Downloads) into the game as assets/Captured/<Name>.rbxm - prepare names and textures, merge (texture repeats baked, squashed pixels re-spread, flush faces separated), the automatic look check, get it into Studio (Open Cloud upload or the human's Import 3D), dump it, build the .rbxm, the visual pass in Studio, clean up. Use whenever a new or changed model, prop, building, character rig or item has to go into the game.
---

# Import a model into the game

The game only uses models saved as `assets/Captured/<Name>.rbxm`. Studio is the only thing that turns a
.glb into mesh assets, so every model goes: file → (Studio) → dump → `.rbxm`. Follow these steps in
order; skip the ones marked for other kinds of model.

## 1. Prepare the file (always)

- `python tools/prepare_import.py <file.glb>` → `~/Downloads/ready/<name>.glb`: safe names, crisp
  (nearest-neighbour) textures, plain colours baked into textures. If it lists words "NOT YET REVIEWED",
  read each word alone and beside its neighbours; add harmless ones to `tools/names/allowed.txt` (the
  line for its first letter, kept sorted) or give risky ones a replacement in `tools/names/renames.json`
  (`"rename"` section), then run it again. Never colour + person/body words.
- Look at every texture before anything is uploaded (a contact sheet with PIL): moderation reads the
  pictures too.
- The file name is uploaded as well: plain words only, ones the names check knows.

## 2. Merge it (every model with textures; it also repairs the looks)

Each distinct mesh is one download for every new player, and `tools/merge_model.py` fixes what Roblox draws
wrong: texture repeats/turns the file asks for (KHR_texture_transform, which Roblox ignores; three.js files in
three's order), faces whose pixels come out squashed or stretched (re-spread to square pixels at the texture's
usual size), and pieces with faces flush at the same depth (moved a hair apart: they'd flicker).
- A building, camp or any multi-piece model: `python tools/merge_model.py <ready.glb>` (`--doors` keeps walk-in
  doors as their own groups with a `.doors.json` plan; `--keep lid:box_lid,door:gate_door+door_wheel` keeps
  pieces the game moves as named groups) → `Downloads/ready/merged/`.
- A character rig (`joint_*` nodes): `python tools/merge_rig.py <ready.glb>` → `Downloads/ready/rig/`.

## 2b. The automatic look check (always, before anything is uploaded)

`python tools/visual_check.py <the file you'll upload>` must say **"looks right"**: no stretched textures, no
settings Roblox ignores, no flicker, no missing textures. If it lists something, fix it (the merge above fixes
most of it by itself; otherwise in the file, or in the game code that places it) and run it again. Never upload
a file it complains about.

Then **look at it**: `python tools/render_model.py <the file you'll upload>` draws it the way Roblox will (crisp
pixels, back faces hidden, texture repeat/clamp) and writes one picture sheet, `build/render/<name>.png`: every
side, straight on, from above, far away, cut open both ways (inside rooms and shafts), and close-ups of the most
detailed pieces from a spot where they show. Read the .png and check every view: smeared or stretched pixels,
wrong, missing (flat grey/white) or turned textures, holes, gaps, floating pieces. Flicker is found while drawing,
circled in pink, and fails the run. This needs no Studio, so agents do it too; the Studio pass (step 6) is then
the last look, in the game's lighting and where the model meets the world.

## 3. Get it into Studio

Preferred: upload it yourself - `python tools/import/upload_asset.py <file.glb> Model "<plain name>"`
(group-owned, needs `ROBLOX_ASSETS_KEY` in `.env`), then put it in Studio Workspace with the Studio MCP
`insert_asset` (assetType Model): every mesh comes in attached and textured. The inserted model is a package: `Workspace.<name>` holds a `PackageLink` and the glb's root
model, which holds the props - so for a batch set `INSIDE` to that root's name.

Fallback (an upload refused, or meshes come in unattached): ask the human for ONE action: "In Studio:
**File → Import 3D** → `Downloads\ready\...\<file>.glb` → Import, leave it where it lands, and say done."

## 4. Dump it from Studio

1. Start the drop box in the background:
   `lune run tools/import/receiver.luau <scratchpad>/<dir>` (port 8765; `curl -X POST localhost:8765/?name=ping -d x`
   answers `ok 1` when it's up).
2. Read `tools/import/studio_dump.luau`, set `SOURCE` (the model's name in Workspace), `EACH_CHILD`
   (true for a batch of props) and `INSIDE`, and run it in Studio **Edit** with `execute_luau`. Check the
   reply: every model listed, `0 unattached`.

## 5. Build the .rbxm

- A prop or a batch of props: `lune run tools/import/dump2rbxm.luau <Name> <dir> assets/Captured/<Name>.rbxm`
  (the dump file must be `<Name>_01.json`).
- A merged building (replacing one already in the game, keeping its marker parts and lights):
  `lune run tools/import/assemble.luau <Name> <dir>/<Name>_01.json <merged>.colliders.json assets/Captured/<Name>.rbxm assets/Captured/<Name>.rbxm <unit> [<merged>.doors.json]`
  Import 3D turns a model 180 degrees; an Open Cloud upload has come in both turned and not, so assemble
  works it out from the door (prints which) and stores `ImportTurned`; without a door, pass `--turned` or
  `--unturned`. A brand-new building has no old .rbxm: build one from the dump with dump2rbxm first and
  pass that. Then check the colliders sit under the meshes (a one-sided piece like the porch: its
  boards and its box on the same side) before anything else.
  (`unit`: the scale the game places it at, e.g. 2.78 for props modelled in metres).
- A character rig: there is no general builder yet; write a one-off Lune script from the dump (keep its
  joints) and record how in the board's Docs.

Then `lune run tools/names.luau` must say OK.

## 6. The visual pass in Studio (always: the human must never be the one to find a look problem)

Look at the captured model at the size the game shows it, from every side, before anything ships:
1. Read `tools/import/preview.luau`, set `NAME` and `SCALE`, run it in Studio **Edit** (`execute_luau`): it puts a
   copy in empty air and returns camera positions (each side, from above, far away, close-ups of every moving
   part from a clear line of sight, close-ups of the biggest surfaces).
2. `screen_capture` from each (`camera_position`, `look_at_position`), **one at a time** (several at once time
   out), and add the views a player gets that it can't guess (inside a shaft or a room, the edges players walk past).
3. Look at every picture for: stretched or squashed pixels, flicker (texture stripes or patches that differ
   between two pictures from nearly the same spot), missing/grey/wrong textures, gaps, floating or sunken
   pieces, wrong size next to a player (5 studs). Compare against the source picture or the old version: the
   look must not change except where it was wrong.
4. An empty dark picture means Studio's window is minimized: restore it without taking the human's focus
   (PowerShell, user32 `ShowWindow(handle, 4)` on the RobloxStudioBeta window) and take it again.
5. Something wrong: fix it (file → merge → check → upload → dump again) and do the pass again. Then run the
   preview with `CLEAN = true`.
6. In the running game too, where the model meets the world (terrain round it, lights, what's inside it): play,
   go there, and measure what pictures can't show (ground poking through walls: rays from inside; pieces floating).

## 7. Clean up Studio (always)

Delete the imported model **and any `AuxScene`** from Workspace (Edit, `execute_luau`). A leftover
`AuxScene` of loose parts once dropped server physics to 1 step a second (the whole game crawled).
Check `workspace:GetChildren()` is just `Map, Terrain, Camera`.

## 8. Check it in the game

Rojo live-syncs the new `.rbxm` (check its MeshParts are attached in `ReplicatedStorage.Assets.Captured`).
Then test it in the running game (CLAUDE.md section 4): look at it (screenshot), and measure what was wrong
(e.g. pieces floating: lowest point vs the ground). Record the decision in the board's Docs, run
`lune run tools/check.luau --fix`, commit.
