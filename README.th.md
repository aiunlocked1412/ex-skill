# /ex-skill — ตัวจัดการ Skill & Plugin สำหรับ Claude Code

Slash command ตัวเล็ก ๆ สำหรับ **[Claude Code](https://claude.com/claude-code)** ที่ scan skill, plugin และ slash command ทั้งหมดที่ติดตั้งอยู่ในเครื่อง แสดงผลเป็นตาราง ASCII สวย ๆ แล้วเปิดให้คุณเลือก **ลบ** หรือ **เคลียร์ทั้งหมด** ผ่าน CLI

> 🇬🇧 English version: [README.md](./README.md)

---

## ทำไมต้องมี

หลังจากติดตั้ง skill กับ plugin จาก marketplace หลาย ๆ ตัวไปแล้ว มันยากมากที่จะติดตามว่าอะไรค้างอยู่ในเครื่องบ้าง — และ Claude Code ก็ไม่มีคำสั่ง "ลบทุกอย่าง" แบบ built-in ในตัว `/ex-skill` รวบทุกอย่างมาในหน้าเดียว: **เห็น → เลือก → ลบ** ไม่ต้องไปขุด `~/.claude/` เอง

## ทำอะไรได้บ้าง

เมื่อพิมพ์ `/ex-skill` ใน Claude Code มันจะ:

1. **Scan** 3 แหล่ง:
   - `~/.claude/skills/` และ `./.claude/skills/` (user + project scope)
   - `~/.claude/plugins/installed_plugins.json` (เฉพาะ user — Claude Code plugins เป็น user-scope เสมอ)
   - `~/.claude/commands/` และ `./.claude/commands/`

   > ถ้า cwd = home directory จะข้าม project scope (ไม่สแกนซ้ำ)
2. **แสดง** ตาราง ASCII มีสี + เลข index กำกับทุกบรรทัด
3. **ถาม** ว่าต้องการทำอะไร: ลบบางรายการ / เคลียร์ทั้งหมด / ยกเลิก
4. **Preview** แบบ dry-run ก่อนแตะไฟล์จริงเสมอ
5. **ลบ** อย่างปลอดภัย (backup `installed_plugins.json` เป็น `.bak` ก่อน)

### ตัวอย่างผลลัพธ์

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

## วิธีติดตั้ง

### วิธี A — Plugin marketplace (แนะนำ)

ใน Claude Code พิมพ์:

```
/plugin marketplace add aiunlocked1412/ex-skill
/plugin install ex-skill@ex-skill-marketplace
```

เสร็จ — `/ex-skill` ใช้ได้เลย และจะ uninstall ทีหลังด้วย `/plugin uninstall ex-skill@ex-skill-marketplace` ก็ได้

### วิธี B — Standalone install (ไม่ผ่าน marketplace)

```bash
git clone https://github.com/aiunlocked1412/ex-skill.git
cd ex-skill
./install.sh             # โหมด copy — ปลอดภัย แยกขาดจาก repo
# หรือ
./install.sh --link      # โหมด symlink — แก้ใน repo มีผลกับตัวที่ติดตั้ง
```

แล้วเปิด Claude Code พิมพ์ `/ex-skill`

ถ้ามีไฟล์ชื่อซ้ำใน `~/.claude/commands/` อยู่แล้ว มันจะ backup เป็น `*.bak` แทนการ overwrite

## ถอนการติดตั้ง

ถ้าติดตั้งผ่าน marketplace:
```
/plugin uninstall ex-skill@ex-skill-marketplace
```

ถ้าติดตั้งผ่าน `install.sh`:
```bash
./uninstall.sh
```

…หรือใช้ `/ex-skill` เองลบ slash command `ex-skill` ก็ได้ (มันลบตัวเองได้ — มีเตือนก่อน)

---

## หลักการทำงาน

มี 3 ส่วน:

| ไฟล์ | หน้าที่ |
|---|---|
| `commands/ex-skill.md` | Slash command entry — orchestrate flow ด้วย `AskUserQuestion` ของ Claude |
| `scripts/ex-skill-scan.sh` | Bash scanner ล้วน ๆ — แสดงกล่อง ASCII + เขียน `/tmp/ex-skill-index.tsv` |
| `scripts/ex-skill-delete.sh` | Engine ลบ — รับ `"1,3,5"`, `"all"`, หรือ `--dry` |

Slash command มี smart path resolver — ใช้ `${CLAUDE_PLUGIN_ROOT}` เมื่อติดตั้งผ่าน marketplace, ใช้ `~/.claude/commands/` เมื่อติดตั้ง standalone — ไฟล์เดียวรองรับทั้ง 2 วิธี

Scanner เขียน index แบบ tab-separated ทิ้งไว้ ทำให้ deletion script อ้าง numeric ID คงที่ได้แม้ user เลื่อนหน้าพ้นกล่องไปแล้ว

### กติกาการลบ

| ประเภท | สิ่งที่ทำ |
|---|---|
| Skill (folder) | `rm -rf` ทั้ง folder |
| Skill (symlink) | `rm -f` (**ไม่แตะ** target ของ symlink) |
| Slash command | `rm -f` ไฟล์ `.md` |
| Plugin | ลบ cache folder **และ** ลบ entry ใน `installed_plugins.json` (backup เป็น `.bak` อัตโนมัติ) |

### ฟีเจอร์ความปลอดภัย

- **Dry-run preview** ก่อนลบจริงทุกครั้ง
- **ยืนยัน 2 ชั้น** สำหรับโหมด "เคลียร์ทั้งหมด"
- **Auto-backup** `installed_plugins.json` ก่อนแก้
- **รู้จัก symlink** — ไม่เผลอ `rm -rf` ทะลุเข้าไปใน folder จริง
- **Regenerate index ทุกครั้ง** ที่ scan ใหม่ ทำให้เลขเก่าไม่ลบผิด

---

## ความต้องการ

- macOS หรือ Linux (ใช้ bash + `/usr/bin/python3` สำหรับ parse JSON)
- ติดตั้ง [Claude Code](https://claude.com/claude-code) แล้ว
- มี folder `~/.claude/commands/` (Claude Code สร้างให้อัตโนมัติตอนเปิดครั้งแรก)

## โครงสร้างไฟล์

```
ex-skill/
├── .claude-plugin/
│   ├── marketplace.json     # marketplace manifest
│   └── plugin.json          # plugin manifest
├── commands/
│   └── ex-skill.md          # slash command (smart path resolver)
├── scripts/
│   ├── ex-skill-scan.sh     # scanner
│   └── ex-skill-delete.sh   # deleter
├── install.sh               # standalone install
├── uninstall.sh
├── LICENSE                  # MIT
└── README.md / README.th.md
```

## License

MIT © 2026 [AI UNLOCKED](https://github.com/aiunlocked1412)
