# Artisanal Todo

A local-first macOS todo app with a warm pen-and-paper feel — and a built-in MCP server so AI assistants like Claude can manage your tasks for you.

**Requires macOS 15 (Sequoia) or later.**

---

## Why Artisanal Todo?

Most todo apps are cluttered, cloud-dependent, or designed for teams. Artisanal Todo is built for individuals who want something simple, private, and genuinely pleasant to use.

- **One continuous page** — active tasks at the bottom, completed history above. No projects, no tags, no friction.
- **Fully offline** — your data never leaves your machine. No account required.
- **AI-ready** — a built-in MCP server lets Claude (or any MCP-compatible AI) read and manage your tasks by natural language. Ask Claude to add tasks while you're in a meeting, or have it clear your list when you're done for the day.
- **macOS widget** — see your top 3, 5, or 10 tasks at a glance on your desktop.
- **Light, Dark, and Auto** appearance modes.

---

## Download

**Option 1 — DMG:** Grab the latest `TodoApp.dmg` from the [Releases page](https://github.com/hparpia8/artisanal-todoApp/releases), open it, and drag the app to `/Applications`.

**Option 2 — Install script:**

```bash
curl -fsSL https://raw.githubusercontent.com/hparpia8/artisanal-todoApp/main/install.sh | bash
```

Downloads the latest release and installs the app to `/Applications`.

---

## How to use

| Action | Result |
|--------|--------|
| Type in the bottom bar + press **Return** | Adds a task |
| Click the circle next to a task | Marks it complete — moves to history |
| Click a completed circle | Restores the task to active |
| Scroll up | Browse all completed history |
| Right-click a task | Delete it |
| ☀ · ◑ · ☾ buttons in the header | Switch Light / Auto / Dark mode |

### Adding the widget

1. Right-click your macOS desktop → **Edit Widgets**
2. Search for **Artisanal Todo**
3. Choose Small (3 tasks), Medium (5), or Large (10)

> **Note:** The widget requires the app to be code-signed with an Apple Developer account to display live data. Without signing, the widget shows placeholder tasks. The app and MCP server work fully regardless.

---

## Use with AI (MCP)

Artisanal Todo ships with an MCP (Model Context Protocol) server. This means any MCP-compatible AI assistant — including Claude Desktop and Claude Code — can read and manage your todos directly, without copy-pasting or switching windows.

### What you can do

Once connected, just talk to Claude naturally:

| You say | What happens |
|---------|--------------|
| *"What's on my list?"* | Claude reads and summarizes your todos |
| *"Add: review the quarterly report"* | Task appears in the app instantly |
| *"Mark 'review the quarterly report' as done"* | Moves it to history |
| *"Actually unmark that — I'm not done"* | Restores it to active |
| *"Clear everything I've finished today"* | Claude removes completed tasks |
| *"I'm heading into a meeting — add these action items: ..."* | Add multiple tasks at once |

The app refreshes live whenever Claude makes a change — no manual sync needed.

### Use cases

- **During meetings** — ask Claude to capture action items while you stay focused
- **Voice-to-task** — dictate tasks to Claude and have them land in your list
- **End-of-day cleanup** — ask Claude to summarize what you finished and clear completed tasks
- **Quick triage** — ask *"what do I still have open?"* without opening the app
- **Agentic workflows** — let Claude manage tasks as part of longer automated sequences (e.g., "research X, then add a follow-up task when done")

### Setup

The MCP server and a Node.js runtime are bundled inside the app — no extra installs needed.

**Add to Claude Desktop** — open `~/Library/Application Support/Claude/claude_desktop_config.json` and merge the following `mcpServers` key into your existing config:

```json
"mcpServers": {
  "artisanal-todo": {
    "command": "/Applications/TodoApp.app/Contents/Resources/node",
    "args": ["/Applications/TodoApp.app/Contents/Resources/mcp-server/dist/index.js"]
  }
}
```

> **Note:** Do not paste this as a separate `{ }` block. Add the `"mcpServers"` key inside your existing JSON object, alongside any other top-level keys like `"preferences"`.

Restart Claude Desktop after saving.

**Add to Claude Code:**

```bash
claude mcp add artisanal-todo /Applications/TodoApp.app/Contents/Resources/node /Applications/TodoApp.app/Contents/Resources/mcp-server/dist/index.js
```

### Available MCP tools

| Tool | Description |
|------|-------------|
| `list_todos` | Returns all todos (pending and completed) |
| `add_todo` | Adds a new task |
| `complete_todo` | Marks a task done (by number, title, or ID) |
| `uncomplete_todo` | Restores a completed task to active |
| `delete_todo` | Permanently removes a task |

### Other MCP clients

Any MCP-compatible client works. Point it at the bundled server using stdio transport:

```
/Applications/TodoApp.app/Contents/Resources/node /Applications/TodoApp.app/Contents/Resources/mcp-server/dist/index.js
```

### Building from source (optional)

If you cloned the repo and want to run the MCP server from source instead:

```bash
cd mcp-server
npm install
npm run build
node dist/index.js
```

---

## Your data

All todos are stored locally in a SQLite database at:

```
~/Library/Containers/com.artisanal.todo/Data/Library/Application Support/ArtisanalTodo/todos.db
```

Nothing is synced to the cloud. You can back up this file at any time.

---

## Build from source

**Prerequisites:** Xcode 16+, Homebrew, Node.js 18+

```bash
git clone https://github.com/hparpia8/artisanal-todoApp.git
cd todoApp
make setup   # installs XcodeGen and generates the Xcode project
make open    # opens the project in Xcode
```

Press **⌘R** in Xcode to build and run. Make sure the scheme is set to **TodoApp** (not `TodoWidgetExtension`).

> The `TodoApp.xcodeproj` file is git-ignored and generated by [XcodeGen](https://github.com/yonaskolb/XcodeGen). Run `make setup` again after pulling changes.

---

MIT License
