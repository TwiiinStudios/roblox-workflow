# 05 · Working together (two people, two AIs)

Each of you drives your own Claude. Both Claudes work on the same repo through Git, exactly like two
human programmers, so the same rules apply.

## The golden rules

1. **One task = one branch = one PR.** Never two people on the same branch.
2. **Split by system.** You do frogs, your friend does the shop. Different files mean no conflicts.
3. **Use GitHub Issues as the to-do list.** Every task is an issue, and the person working on it assigns it to themselves.
4. **Merge often.** Small PRs merged daily beat one giant PR after two weeks.
5. **Each person play-tests in their own Studio** with their own `build/game.rbxl`. Never Team Create, never a shared place.

## The task board (GitHub Issues)

```
#4  Frog feeding               → assigned: you       (Mode A, needs Studio)
#5  Shop UI                    → assigned: friend    (Mode A)
#6  Daily reward               → @claude             (Mode B, runs on GitHub)
#7  Pond area in the map       → unassigned
```

Ask your Claude: *"What issues are open? Take #7 and assign it to me."* It uses `gh issue list` / `gh issue edit`.

## What happens when you both work at the same time

### Different files → nothing to do ✅
`FrogService.luau` (you) and `ShopController.luau` (friend) merge cleanly.

### Same text file, different lines → Git merges automatically ✅
You add `FLY_PRICE` to `Config.luau`; your friend adds `EGG_PRICE`. Both land.

### Same lines → merge conflict → let Claude fix it ⚠️
GitHub shows *"This branch has conflicts"* on your PR. Tell your Claude:

> "Merge main into my branch and resolve the conflicts. If a conflict is a design decision, ask me."

Claude runs `git pull origin main`, sees for example:
```lua
<<<<<<< HEAD
	GROWTH_PER_FLY = 5,
=======
	GROWTH_PER_FLY = 10,
>>>>>>> main
```
It keeps both changes where it can. When the same value was changed to two different numbers, it **asks you**,
because that's a game-design choice. Then it runs the checks, commits and pushes. The PR turns green.

### Same `.rbxm` in `Captured/` → can't be merged
Binary files can't be combined. Claude keeps one version (usually `main`'s) and re-captures your change on top.
To avoid this, only one person works on a given captured asset at a time (another reason to use issues).

### Your friend's work isn't merged yet but you need it
> "Check out my friend's PR #5, play-test it in Studio and tell me if it works."

Or wait for the merge. Usually better.

## Reviewing each other's PRs

Claude Review comments automatically. The human review is short:
1. Read the PR description: what changed, what was verified.
2. Glance at Claude Review's summary. Any "must change"?
3. For gameplay: have your Claude check it out and play-test it, or play TEST after merging.
4. Approve and merge.

## Keeping each other in the loop

- Before starting: assign the issue (it tells the other person you're on it).
- After merging something big: post *"#4 merged, pull main"* in your chat.
- Claude pulls `main` at the start of every session, so you're always up to date.
