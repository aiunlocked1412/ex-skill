---
description: วิเคราะห์ skills / plugins / slash commands ที่ติดตั้ง แล้วเปิดเมนู ลบ หรือ เคลียร์ทั้งหมด ผ่าน CLI
---

# /ex-skill — Skill & Plugin Manager

ทำตามขั้นตอนนี้ทันที **ไม่ต้องถามผู้ใช้ก่อนเริ่ม** (เริ่ม Step 1 เลย)

---

## Step 1 — Scan และแสดงผล

รัน scanner script ด้วย Bash tool:

```bash
bash ~/.claude/commands/ex-skill-scan.sh
```

Script จะ:
- Scan `~/.claude/skills/`, `~/.claude/plugins/installed_plugins.json`, `~/.claude/commands/` (user scope)
- Scan `./.claude/skills/`, `./.claude/commands/` (project scope ถ้ามี)
- แสดงผลแบบ ASCII box + ANSI สี
- บันทึก index ลง `/tmp/ex-skill-index.tsv` สำหรับขั้นตอนลบ

**แสดง output ของ script ให้ user เห็นตรง ๆ** (อย่าสรุปย่อ) เพราะ user ต้องดูเลข index เพื่อเลือกลบ

ถ้า total = 0 → บอก user ว่าไม่มีอะไรติดตั้ง แล้วจบ

---

## Step 2 — เมนูหลัก

ใช้ `AskUserQuestion` ถาม:

- **คำถาม**: "ต้องการทำอะไร?"
- **header**: "Action"
- **multiSelect**: false
- **options**:
  1. `"ลบบางรายการ"` — เลือกเฉพาะที่ต้องการลบ (แนะนำ)
  2. `"เคลียร์ทั้งหมด"` — ลบทุกอย่างที่อยู่ในรายการ ⚠️
  3. `"ยกเลิก"` — ออกโดยไม่ทำอะไร

---

## Step 3a — ถ้าเลือก "ลบบางรายการ"

### 3a.1 — ขอเลข index ที่จะลบ

ใช้ `AskUserQuestion`:
- **คำถาม**: "พิมพ์เลข index ที่ต้องการลบ (คั่นด้วย comma เช่น `1,3,5` หรือช่วง `2-4`) — ดูเลขจากตารางด้านบน"
- **header**: "Indices"
- **multiSelect**: false
- **options**:
  1. `"พิมพ์เลขเอง"` — user จะคลิก "Other" แล้วพิมพ์เลข
  2. `"ยกเลิก"`

ถ้า user เลือก "ยกเลิก" → จบ
ถ้า user พิมพ์เลขมา (notes/Other input) → ใช้ค่าที่ user พิมพ์เป็น selection string

> **Hint**: ถ้า user พิมพ์ range เช่น `"2-4"` ให้ expand เป็น `"2,3,4"` ก่อนส่งต่อ

### 3a.2 — Dry-run แสดง preview

รัน:
```bash
bash ~/.claude/commands/ex-skill-delete.sh --dry "<selection>"
```

แสดง output ให้ user เห็น

### 3a.3 — ยืนยันก่อนลบจริง

ใช้ `AskUserQuestion`:
- **คำถาม**: "ยืนยันลบรายการข้างต้น?"
- **header**: "Confirm"
- **options**: `"ยืนยัน ลบเลย"`, `"ยกเลิก"`

ถ้ายืนยัน → รัน:
```bash
bash ~/.claude/commands/ex-skill-delete.sh "<selection>"
```

---

## Step 3b — ถ้าเลือก "เคลียร์ทั้งหมด"

### 3b.1 — เตือนและยืนยัน 2 ชั้น

ใช้ `AskUserQuestion`:
- **คำถาม**: "⚠️ คุณกำลังจะลบ **ทุกอย่าง** ที่อยู่ในรายการ (skills + plugins + commands ทั้งหมด) — แน่ใจหรือไม่?"
- **header**: "Danger"
- **options**: `"ฉันแน่ใจ ดำเนินการต่อ"`, `"ยกเลิก"`

ถ้าผ่าน → ถามอีกครั้ง:
- **คำถาม**: "ยืนยันครั้งสุดท้าย: ลบทั้งหมด?"
- **header**: "Final"
- **options**: `"ลบทั้งหมดเลย"`, `"ยกเลิก"`

### 3b.2 — Dry-run + ลบจริง

ถ้ายืนยันทั้ง 2 ครั้ง → รัน dry-run แสดงผลก่อน:
```bash
bash ~/.claude/commands/ex-skill-delete.sh --dry all
```

แล้วลบจริง:
```bash
bash ~/.claude/commands/ex-skill-delete.sh all
```

---

## Step 4 — สรุป

หลังลบเสร็จ:
- บอก user ว่าลบสำเร็จกี่รายการ
- เตือนว่า: **plugins/skills ที่ถูกลบจะมีผลใน session ถัดไป** (Claude Code ต้อง reload เพื่อ refresh)
- ถ้ามีการแก้ `installed_plugins.json` → backup เก็บไว้ที่ `installed_plugins.json.bak`

---

## หมายเหตุสำคัญ

- **อย่าลบ `/ex-skill` เอง** — ถ้า user เลือก index ที่ตรงกับไฟล์ `ex-skill.md`, `ex-skill-scan.sh`, `ex-skill-delete.sh` ให้เตือนก่อนทุกครั้ง
- ถ้า `installed_plugins.json` เสีย → restore จาก `.bak` ด้วย `cp ~/.claude/plugins/installed_plugins.json.bak ~/.claude/plugins/installed_plugins.json`
- Script ทั้งหมดอยู่ที่ `~/.claude/commands/ex-skill-*.sh`
