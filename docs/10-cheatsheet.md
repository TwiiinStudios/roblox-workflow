# 10 · Cheat sheet

```
 🐸  START  →  BUILD  →  SHIP  →  PLAY          (+ PAUSE)
```

| | You | |
|---|---|---|
| **0** | Discord: *"I'm doing …"* | |
| **1. START** | Open Studio → VS Code (game folder) → Claude: **"Start"** → Studio: **Plugins → Rojo → Connect** | |
| **2. BUILD** | *"Add … (what the player sees/does, numbers, where)"* → feedback until you like it | |
| **3. SHIP** | **"Ship it"** | → TEST in ~2 min, Discord message |
| **4. PLAY** | Play TEST together in the Roblox app | |
| **PAUSE** | **"Pause"** when stopping before it's done | saved online |

## Other things you can say

| When | Say |
|---|---|
| Teammate should look first | "Share it" |
| Catch up | "What changed?" |
| Try their unfinished work | "Show me what my teammate is working on and play-test it." |
| Real servers before shipping | "Publish this branch to TEST." |
| Release (both agreed) | "Release to LIVE as v1.2.0." |
| Something's broken | "The shop button does nothing when I click it." / "LIVE is broken since v1.2.0: …" |
| Generated art | "Generate a cartoon frog mesh in Studio, capture it, and use it for the frog model." |
| Design question | "What did we decide about egg prices?" (Claude checks `DESIGN.md`) |
| New game | "New game: **MyGame**. Create it from the template with a GitHub repo in TwiiinStudios." |
| New PC / new teammate | "Set up my PC." |

## Your only manual actions

1. Studio: **Plugins → Rojo → Connect** (once per session)
2. **Ctrl+S** in Studio when Claude asks (only after it generated an asset in Studio)
3. **F5** whenever you want to play it yourself in Studio

## If something's off

| Problem | Fix |
|---|---|
| Claude can't see Studio | Studio open? Claude panel: `/mcp` → Roblox_Studio → Reconnect |
| Changes don't show in Studio | Plugins → Rojo → Connect (again) |
| Don't like what Claude just did | "Undo that." |
| LIVE broken | Creator Hub → Place → Version History → Restore, then fix on TEST |
