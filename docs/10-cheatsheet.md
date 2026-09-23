# 10 · Cheat sheet

## Things you say to Claude

| When | Say |
|---|---|
| New game | "New game: **MyGame**. Create it from the template with a GitHub repo in TwiiinStudios." |
| Start of a session | "Start a session." (then open `build/game.rbxl` in Studio → Rojo → Connect) |
| Build something | "Add … (what the player sees/does, numbers, where). Test it in Studio." |
| Change something | "The shop is too far from spawn. Move it next to the spawn and make the button bigger." |
| Test | "Play-test as a new player: …, screenshot the UI, and check the console for errors." |
| Deliver | "Ship it." → PR. "Merge it when CI is green." |
| Pick up work | "What issues are open? Take #7." |
| Conflicts | "Merge main into my branch and resolve the conflicts. Ask me about design choices." |
| Friend's work | "Check out PR #5 and play-test it." |
| Try on real servers | "Publish this branch to TEST." |
| Release | "Release main to LIVE as v1.2.0." (only when you both agreed) |
| Broken | "CI is red on my PR, fix it." / "LIVE is broken since v1.2.0: … Find and fix it." |
| Generated art | "Generate a cartoon frog mesh in Studio, capture it, and use it for the frog model." |

## From anywhere (GitHub)

- New issue: `@claude add …`
- PR comment: `@claude change …`
- Merge: the green **Squash and merge** button
- Release: **Actions → Deploy → Run workflow → live**

## Your only manual Studio actions

1. Open `build/game.rbxl` → **Plugins → Rojo → Connect** (once per session)
2. **Ctrl+S** when Claude asks (after it captured a generated asset)
3. **F5** whenever you want to play it yourself

## Commands (Claude runs these, but you can too)

```powershell
lune run tools/check.luau --fix      # format + lint + world lint + tests + build
lune run tools/build.luau            # build/game.rbxl
rojo serve                           # live sync into Studio
lune run tools/capture.luau          # Studio Captured folders → files
lune run tools/publish.luau test     # publish to TEST (needs .env)
gh workflow run Deploy -f target=live
git switch main; git pull; wally install
```

## Undo

| Situation | What to do |
|---|---|
| Don't like what Claude just did (not committed) | "Undo those changes." (`git restore .`) |
| Bad merge on `main` | "Revert PR #12." |
| LIVE broken | Creator Hub → Place → Version History → Restore, then fix on TEST |
