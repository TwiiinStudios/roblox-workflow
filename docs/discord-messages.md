# Discord messages (copy, post, pin)

Ready-to-post messages that explain the workflow to a teammate. Each block fits Discord's 2000-character limit.
Copy the text **inside** each box, post it in the channel, then right-click → **Pin**.
Replace the TEST game link when using this for another game.

| Channel | Purpose |
|---|---|
| `#📌start-here` | One-time setup |
| `#🐸how-we-work` | The workflow |
| `#🔨working-on` | Who's doing what (one line each) |
| `#🤖dev-log` | Automatic messages from GitHub (the webhook goes here, see `02-new-game.md` step 6b) |
| `#🆘help` | Problems and fixes |

---

## `#📌start-here`, message 1

```
# 👋 Welcome! One-time setup (~20 min)
**1.** Accept the GitHub invite from **TwiiinStudios** (check your email / GitHub notifications)
**2.** Install **VS Code** → https://code.visualstudio.com
**3.** In VS Code: **Extensions** (Ctrl+Shift+X) → search **Claude Code** (by Anthropic) → **Install** → log in with your Claude account
**4.** Create the folder `Documents\Projects\Roblox` → in VS Code: **File → Open Folder** → pick that folder
**5.** Open the Claude panel and paste this:
> Clone https://github.com/TwiiinStudios/roblox-workflow into this folder, read its CLAUDE.md, and set up my PC.

Claude installs everything else (Git, Roblox tools, plugins…) and downloads our games. It will ask you for a few things only you can do:
• click **Yes** when Windows asks to install something
• log in to **GitHub** in your browser
• log in to **Roblox Studio**
Just follow what Claude says. Stuck? → post in #🆘help
```

## `#📌start-here`, message 2

```
# ⚙️ One switch in Roblox Studio (only once)
Studio → **Assistant** panel → **⋯** (top right) → **Manage MCP Servers**
✅ **Enable Studio as MCP server** → ON
➖ **Visual Studio Code** → doesn't matter
❌ **Claude Code CLI** → leave OFF
Then close & reopen the Claude panel in VS Code.

# 🎮 Check you can join our TEST game
https://www.roblox.com/games/125769981061146 → **Play**
Can't join? Tell me in #🆘help

📖 What is everything? Read the beginner guide:
https://github.com/TwiiinStudios/roblox-workflow/blob/main/docs/00-start-here.md
```

---

## `#🐸how-we-work`, message 1

```
# 🐸 How we work: BUILD → SHIP → PLAY

**Before**
• Open **Roblox Studio** (the start screen is enough)
• Open **VS Code** → File → Open Folder → `Roblox\GrowAFrog` → Claude panel
• Post in #🔨working-on what you're doing: "🔨 fly shop"

**1️⃣ BUILD** → just say what you want
Like you'd tell a friend: what the player sees/does, numbers, where.
> Add a shop next to spawn. Flies cost 10 coins. Feeding a frog a fly makes it grow by 5.
Claude gets everything ready by itself, tells you what the other one is working on and opens the game in Studio.
➡️ When the game shows up in Studio: **Plugins → Rojo → Connect** (your only click, no need to tell Claude)
Claude builds it AND tests it in Studio by itself. Want to see it? **F5** in Studio (**Shift+F5** = stop). Don't like something? Just say what to change.

**2️⃣ SHIP** → say **Ship it**
~2 min later it's in the TEST game + a message shows up in #🤖dev-log
💡 Small change? One message does it all: *"Add a fly shop next to spawn, flies cost 10 coins, and ship it."*

**3️⃣ PLAY** → play the TEST game together 🎮
https://www.roblox.com/games/125769981061146

**Done for today?** Just close VS Code. Your work is saved online automatically.
```

## `#🐸how-we-work`, message 2

```
# 🗣️ Other things you can say to Claude
• **Share it** → the other one should look before it goes on TEST (you get a link to post)
• **What changed?** → Claude explains what the other one added
• **What did we decide about …?** → Claude checks our design notes
• **Undo that** → you don't like what Claude just did
• **Release to LIVE as v1.0.0** → real players get it ⚠️ ONLY when we BOTH agreed here

# 🤝 Rules for working together
1. Post in #🔨working-on before you start
2. Work on different things (one does frogs, the other the shop) → no clashes
3. Put everything into one message when you can. Fewer messages = faster
4. Ship small things often
5. Never build things by hand in Studio. They get deleted. Tell Claude instead
6. Never press **Publish** in Studio. "Ship it" does that
7. Never paste passwords or keys into Claude or Discord
When Claude asks you a design question, answer it: you're the game designer 🎨
```

---

## `#🔨working-on`, pinned

```
# 🔨 Who's working on what
Before you start, post one line:
`🔨 fly shop`
When you shipped it:
`✅ fly shop shipped`
Stopping before it's done? Nothing to do: Claude saves it online. Just post:
`⏸️ fly shop half done`
This keeps us from building the same thing twice.
```

---

## `#🤖dev-log`, pinned

```
# 🤖 Automatic updates
GitHub posts here every time the game changes:
🧪 **TEST updated** → something new to play in the TEST game
🌍 **LIVE updated** → real players have it now
❌ **… failed** → tell Claude: "the deploy failed, fix it"
Please don't chat here, it's only for the bot 🙂
```

---

## `#🆘help`, pinned

```
# 🆘 Something's off?
**Claude can't see Studio** → Studio must be open BEFORE the Claude panel. Fix: in the Claude panel type `/mcp` → Roblox_Studio → Reconnect
**Changes don't show up in Studio** → Plugins → Rojo → Connect again
**Something is broken** → tell Claude exactly what you see: "the shop button does nothing", or copy the red text from Studio's Output window
**Claude says there's a conflict** → it asks which version to keep → decide together here
**Claude asks you to press Ctrl+S in Studio** → do it (only happens when it made 3D art in Studio)
**Studio closed / PC restarted** → open Studio, keep talking to Claude. It reopens the game; click Rojo → Connect again
**Anything else** → ask Claude "what's wrong?" first, then post here with a screenshot
```
