# Artisanal Todo

A simple, local-only todo app for macOS with a warm pen-and-paper feel.

- One scrollable page — active tasks at the bottom, history above
- Fully offline — all data stays on your machine
- macOS widget (shows up to 10 pending tasks)
- Light, Dark, and Auto (system) appearance modes

**Requires macOS 14 (Sonoma) or later.**

---

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/hparpia8/todoApp/main/install.sh | bash
```

This downloads the latest release from GitHub and copies it to `/Applications`.

> **Widget setup:** After installing, right-click your desktop → Edit Widgets → search "Artisanal Todo".

---

## How it works

| Action | Result |
|--------|--------|
| Type in the bar at the bottom + press Return | Adds a task |
| Click the circle next to a task | Marks it complete (moves to history) |
| Click a completed circle | Restores the task to active |
| Scroll up | Browse completed history |
| Right-click a task | Delete |

---

## Build from source

**Prerequisites:** Xcode 15+, Homebrew

```bash
git clone https://github.com/hparpia8/todoApp.git
cd todoApp
./setup.sh        # installs XcodeGen, generates TodoApp.xcodeproj
open TodoApp.xcodeproj
```

Or use `make`:

```bash
make setup    # install deps + generate project
make open     # open in Xcode
make build    # build from terminal
```

---

## Data storage

- **With Apple Developer account (signed):** stored in the App Group container at `~/Library/Group Containers/group.com.artisanal.todo/todos.json`
- **Unsigned / development builds:** stored at `~/Library/Application Support/ArtisanalTodo/todos.json`

The widget reads from the same location. For the widget to display real data in unsigned builds, both paths must match — which they will as long as you run the app at least once.

---

## Future plans

- [ ] App Store release (macOS, iOS)
- [ ] Tags / projects
- [ ] Keyboard shortcuts
- [ ] Due dates
- [ ] iOS / Android companion apps

---

## Project structure

```
todoApp/
├── project.yml              XcodeGen project spec
├── setup.sh                 Dev setup script
├── install.sh               Curl-installable release script
├── Makefile                 Build commands
├── TodoApp/
│   ├── App/                 App entry point
│   ├── Views/               SwiftUI views
│   ├── Models/              Data model + store
│   ├── Theme/               Colors, fonts, layout constants
│   └── Assets.xcassets/     Color assets (light + dark variants)
└── TodoWidget/              WidgetKit extension
```

---

MIT License
