# 10 · Cheat sheet

```
 BUILD  →  SHIP  →  PLAY
```

| | You |
|---|---|
| **Before** | Open Studio (start screen) → VS Code (game folder) → Claude panel · Discord: *"I'm doing …"* |
| **BUILD** | *"Add … (what the player sees/does, numbers, where)"*. When the game shows up in Studio: **Plugins → Rojo → Connect** |
| **SHIP** | **"Ship it"**, or *"… and ship it"* in the same message → TEST in ~2 min, Discord message |
| **PLAY** | Play TEST together in the Roblox app |
| **Done** | Close VS Code. Work is saved online automatically |

**One prompt is enough:** *"Add a fly shop next to spawn, flies cost 10 coins, and ship it."*

## Other things you can say

| When | Say |
|---|---|
| Teammate should look first | "Share it" |
| Catch up | "What changed?" |
| Try their unfinished work | "Show me what my teammate is working on and play-test it." |
| Real servers before shipping | "Publish this branch to TEST." |
| Release (both agreed) | "Release to LIVE as v1.2.0." |
| Something's broken | "The shop button does nothing when I click it." / "LIVE is broken since v1.2.0: …" |
| Didn't like it | "Undo that." |
| Generated art | "Generate a cartoon frog mesh in Studio, capture it, and use it for the frog model." |
| Design question | "What did we decide about egg prices?" |
| New game | "New game: **MyGame**. Create it from the template with a GitHub repo in TwiiinStudios." |
| New PC / new teammate | "Set up my PC." |

## Your only manual actions

1. Studio: **Plugins → Rojo → Connect** (once per session, when the game shows up)
2. **Ctrl+S** in Studio when Claude asks (only after it generated an asset in Studio)
3. **F5** whenever you want to play it yourself in Studio

## If something's off

| Problem | Fix |
|---|---|
| Claude can't see Studio | Studio open? Claude panel: `/mcp` → Roblox_Studio → Reconnect |
| Changes don't show in Studio | Plugins → Rojo → Connect (again) |
| LIVE broken | Creator Hub → Place → Version History → Restore, then fix on TEST |
