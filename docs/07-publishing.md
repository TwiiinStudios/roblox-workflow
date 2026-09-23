# 07 · Publishing: TEST, LIVE, releases and rollbacks

## How a change reaches players

```
PR merged to main
   └─► GitHub Action "Deploy" (automatic)
         check + build (all files) → publish → GrowAFrog [TEST]      you play-test it

You decide to release
   └─► Actions → Deploy → Run workflow → target: live   (or tell Claude "release to LIVE")
         same build → publish → GrowAFrog (LIVE)                        players get it
```

Nobody publishes from Studio, ever. What's on TEST/LIVE is always exactly a commit on `main`.

## TEST

Automatic on every merge to `main`. Re-run by hand: **Actions → Deploy → Run workflow → test**.
Try a branch before merging: *"Publish this branch to TEST."* Claude runs
`lune run tools/build.luau` + `lune run tools/publish.luau test` (needs `.env` on that PC).
The next merge to `main` replaces it again.

## Releasing to LIVE

1. `main` is on TEST and passed the [release checklist](06-testing.md#before-releasing-to-live-human-checklist).
2. You both agree.
3. Tell Claude: **"Release main to LIVE as v0.3.0."** Claude will:
   - run `gh workflow run Deploy -f target=live` and wait for it to go green,
   - tag it: `git tag -a v0.3.0 -m "…"`, `git push origin v0.3.0`,
   - create release notes: `gh release create v0.3.0 --generate-notes`.

   (Or do step one yourself: GitHub → Actions → Deploy → Run workflow → `live`.)
4. Existing servers keep the old version until they close. To update everyone now:
   Creator Hub → experience → ⋯ → **Restart servers**.

Versions: `v<major>.<minor>.<patch>`. Minor for features, patch for fixes.

## Something is broken on LIVE: roll back

**Fastest (1 minute, human):** Creator Hub → experience → **Places** → the place → **Version History** → previous
version → **Restore**. Then restart servers.

**Then the real fix:** *"LIVE is broken since v0.3.0: players can't open the shop. Find the cause, revert or fix it,
and get it onto TEST."* Check TEST, then release again.

> ⚠️ A rollback restores code, **not data**. If a bug saved bad data, going back doesn't un-save it.
> That's why data changes get extra testing on TEST and the save format has a `version` field.

## The API key

- Repo secret **`ROBLOX_API_KEY`**: `universe-places` **Write** on TEST + LIVE, IP `0.0.0.0/0`.
- One key per game. Set it yourself with `gh secret set` and never paste it into a chat.
- Publishing starts failing with 401/403? The key expired or lost access. Create a new one and `gh secret set` again.
- Leaked? Delete it in Creator Hub **immediately**, then make a new one.

## What the build contains

`lune run tools/build.luau` = `rojo build` of `default.project.json`: all code, `world/Map`, `world/Lighting`,
`assets/` and the `Captured` `.rbxm` files. Nothing else. What's in Git is what players get.

Not in the place file (set by hand in Creator Hub): experience name, description, icon, thumbnails, genre,
permissions/privacy, game passes, developer products, badges.

## Game passes, products, badges

Made in Creator Hub per experience, so TEST and LIVE have different IDs. Give both to Claude:
> "Game pass 'Double Growth': TEST id 222222, LIVE id 111111. Add it to Config and make it double feeding growth."

Claude stores them in `Config.luau` and picks the right one with `game.GameId`.
