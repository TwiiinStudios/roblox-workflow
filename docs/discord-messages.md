# Discord messages

Messages to post and pin in Discord. Each fits Discord's 2000-character limit. Copy the text inside a box,
post it, then right-click → Pin. For another game, replace the game name and the TEST link.

| Channel | Purpose |
|---|---|
| `#start-here` | One-time setup |
| `#how-we-work` | The workflow |
| `#working-on` | Who is working on what |
| `#dev-log` | Automatic messages from GitHub (webhook: `02-new-game.md` step 6b) |
| `#troubleshooting` | Problems and fixes |

---

## `#start-here`, message 1

```
**Setup (one time, about 20 minutes)**
1. Accept the GitHub invite from TwiiinStudios (GitHub notifications or email).
2. Install VS Code: https://code.visualstudio.com
3. In VS Code: Extensions (Ctrl+Shift+X) → search "Claude Code" (by Anthropic) → Install → log in with your Claude account.
4. Create the folder `Documents\Projects\Roblox`. In VS Code: File → Open Folder → select it.
5. In the Claude panel, send:
> Clone https://github.com/TwiiinStudios/roblox-workflow into this folder, read its CLAUDE.md, and set up my PC.

Claude installs everything else and downloads the games. Your part:
- click Yes when Windows asks to install something
- log in to GitHub in the browser when Claude asks
- log in to Roblox Studio when Claude asks
If a step fails, Claude sees the error and tells you what to do next.
```

## `#start-here`, message 2

```
**Roblox Studio setting (one time)**
Studio → Assistant panel → ... (top right) → Manage MCP Servers:
- Enable Studio as MCP server: ON
- Claude Code CLI: OFF
- Visual Studio Code: doesn't matter
Then close and reopen the Claude panel in VS Code.

**Check access to the TEST game**
Open it and press Play: https://www.roblox.com/games/125769981061146
If you can't join: your role in our Roblox group needs access to the group's experiences (Group → Configure Community → Roles).

Full beginner guide: https://github.com/TwiiinStudios/roblox-workflow/blob/main/docs/00-start-here.md
```

---

## `#how-we-work`, message 1

```
**Workflow: BUILD → SHIP → PLAY**

**Before**
1. Open Roblox Studio (the start screen is enough).
2. Open VS Code → File → Open Folder → `Roblox\GrowAFrog` → Claude panel.
3. Post in #working-on what you're doing.

**BUILD**
Tell Claude what you want: what the player sees and does, numbers, where.
Example: "Add a shop next to spawn. Flies cost 10 coins. Feeding a frog a fly makes it grow by 5."
Claude gets the latest version, opens the game in Studio, builds the feature and tests it itself.
When the game appears in Studio: Plugins → Rojo → Connect. No need to reply to Claude.
To try it yourself: F5 in Studio (Shift+F5 to stop), then tell Claude what to change.

**SHIP**
Say "ship it". About 2 minutes later it's in the TEST game and #dev-log gets a message.
For small changes one message is enough: "Add a fly shop next to spawn, flies cost 10 coins, and ship it."

**PLAY**
TEST game: https://www.roblox.com/games/125769981061146

When you're done, close VS Code. Unfinished work is saved online automatically.
```

## `#how-we-work`, message 2

```
**Other things you can say to Claude**
- "share it": the other person reviews before it goes to TEST. Claude gives you a link to post.
- "what changed?": summary of what the other person added
- "what did we decide about ...?": answer from our design notes
- "undo that": reverts the last change
- "release to LIVE as v1.0.0": publishes to real players. Only after we both agreed.

**Rules**
1. Post in #working-on before you start.
2. Work on different features at the same time.
3. Put everything into one message where possible.
4. Ship small changes often.
5. Don't build anything by hand in Studio. It gets overwritten. Ask Claude instead.
6. Never press Publish in Studio.
7. Never paste passwords or keys into Claude or Discord.
8. Answer Claude's design questions. They are saved in the design notes for both of us.
```

---

## `#working-on`, pinned

```
**Who's working on what**
Post one line when you start and one when you ship:
started: fly shop
shipped: fly shop
If you stop halfway: paused: fly shop (the work itself is saved automatically)
```

---

## `#dev-log`, pinned

```
**Automatic messages**
GitHub posts here when the game changes:
- TEST updated: a new version is in the TEST game
- LIVE updated: real players have the new version
- failed: tell Claude "the deploy failed, fix it"
No chatting in this channel.
```

---

## `#troubleshooting`, pinned

```
**Claude can't see Studio**
Studio has to be open before the Claude panel starts. In the Claude panel type /mcp → Roblox_Studio → Reconnect.
First time on this PC: check the Studio setting in #start-here.

**Changes don't appear in Studio**
Plugins → Rojo → Connect.

**Something in the game is broken**
Tell Claude exactly what happens, e.g. "the shop button does nothing", or paste the red error text from Studio's Output window.

**Claude reports a conflict**
You both changed the same thing. Claude asks which version to keep. Decide together.

**Claude asks you to press Ctrl+S in Studio**
Do it. This only happens after Claude generated a 3D asset in Studio.

**Studio was closed or the PC restarted**
Open Studio and keep talking to Claude. It reopens the game. Click Rojo → Connect again.

**Claude asks "Allow?"**
Choose "Yes, and don't ask again".

**Anything else**
Describe the problem to Claude. It can read errors, logs and the game state itself.
```
