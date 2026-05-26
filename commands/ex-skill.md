---
description: วิเคราะห์ skills / plugins / slash commands ที่ติดตั้ง แล้วเปิดเมนู ลบ หรือ เคลียร์ทั้งหมด ผ่าน CLI
---

# /ex-skill — Skill & Plugin Manager

ทำตามขั้นตอนนี้ทันที **ไม่ต้องถามผู้ใช้ก่อนเริ่ม** (เริ่ม Step 1 เลย)

---

## Path resolution (ทำก่อน Step 1)

Scripts ของ ex-skill อยู่ได้ 2 ที่ ขึ้นกับวิธีติดตั้ง — เมื่อรันคำสั่งใด ๆ ใน flow นี้ ให้ใช้ snippet นี้นำหน้าทุกครั้ง:

```bash
SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/commands}"
[[ -d "$SCRIPT_DIR/scripts" ]] && SCRIPT_DIR="$SCRIPT_DIR/scripts"
```

- ติดตั้งผ่าน **marketplace/plugin** → `${CLAUDE_PLUGIN_ROOT}/scripts/`
- ติดตั้งผ่าน **`./install.sh`** (standalone) → `~/.claude/commands/`

---

## Step 1 — Scan และแสดงผล

```bash
SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/commands}"
[[ -d "$SCRIPT_DIR/scripts" ]] && SCRIPT_DIR="$SCRIPT_DIR/scripts"
bash "$SCRIPT_DIR/ex-skill-scan.sh"
```

Scanner:
- Scan `~/.claude/skills/`, `~/.claude/plugins/installed_plugins.json`, `~/.claude/commands/` (user scope)
- Scan `./.claude/skills/`, `./.claude/commands/` (project scope ถ้ามี)
- แสดงผลแบบ ASCII box + ANSI สี
- บันทึก index ลง `/tmp/ex-skill-index.tsv` สำหรับ Step 3a ใช้

**แสดง output ของ script ให้ user เห็นตรง ๆ** (อย่าสรุปย่อ)

ถ้า total = 0 → บอก user ว่าไม่มีอะไรติดตั้ง แล้วจบ

---

## Step 2 — เมนูหลัก

ใช้ `AskUserQuestion` ถาม:

- **question**: "ต้องการทำอะไร?"
- **header**: "Action"
- **multiSelect**: false
- **options**:
  1. `"ลบบางรายการ"` — เลือกเฉพาะที่ต้องการลบ (แนะนำ)
  2. `"เคลียร์ทั้งหมด"` — ลบทุกอย่างที่อยู่ในรายการ ⚠️
  3. `"ยกเลิก"` — ออกโดยไม่ทำอะไร

---

## Step 3a — ถ้าเลือก "ลบบางรายการ"

> **กฎสำคัญ (UX)**: ห้ามให้ user พิมพ์เลข index เอง — ต้องแสดงรายการเป็น **multi-select options ที่ user คลิกเลือกได้เลย**

### 3a.1 — โหลด index และสร้าง multi-select pages

อ่าน `/tmp/ex-skill-index.tsv` (TSV format: `idx\tkind\tname\tscope\tpath\textra`)

แล้วสร้าง pages ของ `AskUserQuestion` ตามกติกานี้:

1. **แต่ละ page = 1 question** ใน `AskUserQuestion` โดย `multiSelect: true`
2. **แต่ละ option label** ต้องขึ้นต้นด้วย `"<idx>. "` ตามด้วย display name (เช่น `"3. github (vunknown) [plugin]"`)
   - Skills: `"<idx>. <name> [skill·<extra>]"` (extra = folder/symlink)
   - Plugins: `"<idx>. <name> (v<extra>) [plugin]"`
   - Commands: `"<idx>. /<name> [command]"`
   - ถ้าชื่อตรงกับ `ex-skill` → ใส่ `⚠️` ต่อท้ายเตือนว่าลบตัวเอง
3. **แต่ละ page ต้องมี option `"⊘ ข้ามกลุ่มนี้ (ไม่ลบอะไรในหน้านี้)"`** เป็น option สุดท้ายเสมอ
4. **Cap**: 4 options ต่อ question → ใช้ได้ 3 items + 1 ข้าม
5. **Cap**: 4 questions ต่อ `AskUserQuestion` call → 1 batch ครอบคลุม 12 items
6. ถ้า items > 12 → ส่งหลาย batches เรียงต่อกัน
7. แต่ละ question header สั้น (≤12 ตัวอักษร) เช่น `"กลุ่ม 1/3"`, `"กลุ่ม 2/3"`, `"กลุ่ม 3/3"`
8. คำถามทุก question ใช้ template: `"เลือกรายการที่ต้องการลบ (กลุ่ม X จาก Y)"`

### 3a.2 — Parse selection

หลังได้คำตอบ:
- รวบรวม labels ที่ user ติ๊กในทุก question
- กรอง option ที่ขึ้นต้นด้วย `"⊘"` ออก (เพราะคือ "ข้ามกลุ่ม")
- จาก label ที่เหลือ → extract เลข index ตัวแรก (regex `^(\d+)\.`)
- ถ้า user ไม่ติ๊กอะไรเลยทุก question → จบ flow บอก "ไม่ได้เลือกอะไร"

ได้ comma-separated index list เช่น `"1,4,7"`

### 3a.3 — Dry-run แสดง preview

```bash
SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/commands}"
[[ -d "$SCRIPT_DIR/scripts" ]] && SCRIPT_DIR="$SCRIPT_DIR/scripts"
bash "$SCRIPT_DIR/ex-skill-delete.sh" --dry "<selection>"
```

แสดง output ให้ user เห็น

### 3a.4 — ยืนยันก่อนลบจริง

ใช้ `AskUserQuestion`:
- **question**: "ยืนยันลบรายการข้างต้น?"
- **header**: "Confirm"
- **options**: `"ยืนยัน ลบเลย"`, `"ยกเลิก"`

ถ้ายืนยัน → รัน (ไม่มี `--dry`):
```bash
bash "$SCRIPT_DIR/ex-skill-delete.sh" "<selection>"
```

---

## Step 3b — ถ้าเลือก "เคลียร์ทั้งหมด"

### 3b.1 — เตือนและยืนยัน 2 ชั้น

ใช้ `AskUserQuestion`:
- **question**: "⚠️ คุณกำลังจะลบ **ทุกอย่าง** ที่อยู่ในรายการ (skills + plugins + commands ทั้งหมด) — แน่ใจหรือไม่?"
- **header**: "Danger"
- **options**: `"ฉันแน่ใจ ดำเนินการต่อ"`, `"ยกเลิก"`

ถ้าผ่าน → ถามอีกครั้ง:
- **question**: "ยืนยันครั้งสุดท้าย: ลบทั้งหมด?"
- **header**: "Final"
- **options**: `"ลบทั้งหมดเลย"`, `"ยกเลิก"`

### 3b.2 — Dry-run + ลบจริง

```bash
SCRIPT_DIR="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/commands}"
[[ -d "$SCRIPT_DIR/scripts" ]] && SCRIPT_DIR="$SCRIPT_DIR/scripts"
bash "$SCRIPT_DIR/ex-skill-delete.sh" --dry all
# … ถ้าผู้ใช้ยืนยัน:
bash "$SCRIPT_DIR/ex-skill-delete.sh" all
```

---

## Step 4 — สรุป

หลังลบเสร็จ:
- บอก user ว่าลบสำเร็จกี่รายการ
- เตือนว่า: **plugins/skills ที่ถูกลบจะมีผลใน session ถัดไป** (Claude Code ต้อง reload เพื่อ refresh)
- ถ้ามีการแก้ `installed_plugins.json` → backup เก็บไว้ที่ `installed_plugins.json.bak`

---

## หมายเหตุสำคัญ

- **อย่าให้ user พิมพ์เลข index** — ใช้ multi-select เสมอ (ดู Step 3a.1)
- **อย่าลบ `/ex-skill` เอง** — ถ้า user ติ๊ก option ที่มี `⚠️` → เตือนใน Step 3a.4 ก่อนยืนยัน
- ถ้า `installed_plugins.json` เสีย → restore จาก `.bak` ด้วย `cp ~/.claude/plugins/installed_plugins.json.bak ~/.claude/plugins/installed_plugins.json`
- Repo: <https://github.com/aiunlocked1412/ex-skill>
