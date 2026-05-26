# /ex-skill — Claude Code Skill & Plugin Manager

A tiny **slash command for [Claude Code](https://claude.com/claude-code)** that scans every skill, plugin, and slash command installed on your machine, shows them in a beautiful ASCII table, and lets you delete them interactively from the CLI.

> 🇹🇭 Thai version: [README.th.md](./README.th.md)

---

## Why

After installing a bunch of skills and plugins via marketplaces, it's hard to keep track of what's actually on your machine — and there's no built-in "uninstall everything" command. `/ex-skill` gives you a single pane to **see → select → delete** without digging through `~/.claude/` by hand.

## What it does

When you type `/ex-skill` in Claude Code, it:

1. **Scans** three sources:
   - `~/.claude/skills/` and `./.claude/skills/` (user + project)
   - `~/.claude/plugins/installed_plugins.json`
   - `~/.claude/commands/` and `./.claude/commands/` (user + project)
2. **Renders** a unified, color-coded ASCII table with index numbers
3. **Asks** what you want to do: delete some, clear all, or cancel
4. **Confirms** with a dry-run preview before any file is touched
5. **Deletes** safely (backups `installed_plugins.json` to `.bak`)

### Example output

```
╭───────────────────────────────────────────────────────────────╮
│  📦 INSTALLED SKILLS / PLUGINS / COMMANDS                    │
├───────────────────────────────────────────────────────────────┤
│ ✨ SKILLS (2)                                                 │
│    1. context-engineering            [symlink] user          │
│    2. open-chrome-mcp                [folder] user           │
├───────────────────────────────────────────────────────────────┤
│ 🔌 PLUGINS (4)                                                │
│    3. github                         vunknown                │
│    4. frontend-design                vunknown                │
│    5. claude-md-management           v1.0.0                  │
│    6. boxbox                         v0.1.0                  │
├───────────────────────────────────────────────────────────────┤
│ ⚡ SLASH COMMANDS (3)                                         │
│    7. ex-skill                       /ex-skill user          │
│    8. gold                           /gold user              │
│    9. open-devtool                   /open-devtool user      │
╰───────────────────────────────────────────────────────────────╯
```

---

## Install

```bash
git clone https://github.com/aiunlocked1412/ex-skill.git
cd ex-skill
./install.sh             # copy mode — safe, isolated
# or
./install.sh --link      # symlink mode — edits in repo affect installed copy
```

Then open Claude Code and type:

```
/ex-skill
```

If a file with the same name already exists in `~/.claude/commands/`, it's backed up to `*.bak` instead of overwritten.

## Uninstall

```bash
./uninstall.sh
```

…or use `/ex-skill` itself to delete the `ex-skill` slash command (it can self-remove — it will warn you first).

---

## How it works

Three files installed into `~/.claude/commands/`:

| File | Role |
|---|---|
| `ex-skill.md` | Slash command entry — orchestrates the flow with Claude's `AskUserQuestion` |
| `ex-skill-scan.sh` | Pure bash scanner — prints the ASCII box and writes `/tmp/ex-skill-index.tsv` |
| `ex-skill-delete.sh` | Deletion engine — accepts `"1,3,5"`, `"all"`, or `--dry` |

The scanner emits a tab-separated index file so the deletion script can operate on stable numeric IDs even if the user scrolls past the box.

### Deletion rules

| Kind | Action |
|---|---|
| Skill (folder) | `rm -rf` the folder |
| Skill (symlink) | `rm -f` (does **not** touch the symlink target) |
| Slash command | `rm -f` the `.md` file |
| Plugin | Remove cache folder **and** strip the entry from `installed_plugins.json` (auto-backed-up to `.bak`) |

### Safety features

- **Dry-run preview** before every real deletion
- **Two-step confirmation** for "clear all"
- **Automatic backup** of `installed_plugins.json` before mutation
- **Symlink-aware** — won't accidentally `rm -rf` into your real skills folder
- **Index file regenerated** every scan, so stale numbers can't cause mis-deletion

---

## Requirements

- macOS or Linux (uses bash + `/usr/bin/python3` for JSON parsing)
- [Claude Code](https://claude.com/claude-code) installed
- `~/.claude/commands/` directory exists (created automatically by Claude Code on first launch)

## File layout

```
ex-skill/
├── commands/
│   ├── ex-skill.md          # slash command
│   ├── ex-skill-scan.sh     # scanner
│   └── ex-skill-delete.sh   # deleter
├── install.sh
├── uninstall.sh
├── LICENSE                  # MIT
└── README.md / README.th.md
```

## License

MIT © 2026 [AI UNLOCKED](https://github.com/aiunlocked1412)
