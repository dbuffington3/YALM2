# YALM2 Database Reference

## SQLite Executable
**Location:** `C:\MQ2\lua\yalm2\sqlite3.exe`

**Usage:** From the `C:\MQ2\lua\yalm2` folder, run:
```powershell
.\sqlite3.exe "DATABASE_PATH" "SQL_QUERY"
```

---

## Quest Tasks Database

**File Location:** `C:\MQ2\config\YALM2\quest_tasks.db`

**Purpose:** Stores all quest-related data for YALM2 system

### Tables

#### 1. `quest_objectives` (STATIC CACHE)
Stores unique objectives and their matched items - ONE-TIME population per objective.

**Columns:**
- `objective` (TEXT, PRIMARY KEY) - The objective text from TaskWnd
- `task_name` (TEXT) - The task this objective belongs to
- `item_name` (TEXT) - The matched item name (result of fuzzy matching)
- `matched_at` (INTEGER) - Timestamp when fuzzy matched
- `created_at` (INTEGER) - Timestamp when first stored

**Query Examples:**
```sql
-- List all cached objectives
SELECT objective, task_name, item_name FROM quest_objectives ORDER BY objective;

-- Count cached objectives
SELECT COUNT(*) FROM quest_objectives;

-- Find specific objective
SELECT * FROM quest_objectives WHERE objective LIKE '%antheia%';
```

#### 2. `quest_tasks` (DYNAMIC STATUS)
Stores character task data with current status - UPDATES FREQUENTLY.

**Columns:**
- `character` (TEXT) - Character name
- `task_name` (TEXT) - Task name
- `objective` (TEXT) - Objective text
- `status` (TEXT) - Current completion status (e.g., "0/3", "1/3", "Done")
- `item_name` (TEXT) - Item name for this objective (matches quest_objectives)
- `updated_at` (INTEGER) - Last update timestamp
- **PRIMARY KEY:** (character, task_name, objective)

**Query Examples:**
```sql
-- Show all tasks with their status
SELECT character, task_name, objective, status FROM quest_tasks ORDER BY character, task_name;

-- Show specific character's tasks
SELECT * FROM quest_tasks WHERE character = 'Vexxuss';

-- Show quest items needed
SELECT character, item_name, status FROM quest_tasks WHERE item_name IS NOT NULL;

-- Count total tasks
SELECT COUNT(*) FROM quest_tasks;
```

---

## MQ2LinkDB (Read-Only Item Database)

**File Location:** `C:\MQ2\resources\MQ2LinkDB.db`

**Purpose:** Contains 134,000+ items from Lucy Allakhazam with quest flags

**Key Table:** `raw_item_data`

**Columns:** id, name, quest item, etc.

**Note:** This database is used for fuzzy matching quest items - NEVER modified by YALM2.

---

## Architecture Flow

```
1. Character completes task → TaskWnd updated
2. yalm2_native_quest reads objective text
3. Check quest_objectives table:
   - If found: Use cached item_name (NO fuzzy match)
   - If NOT found: Fuzzy match against MQ2LinkDB
4. Store result in quest_objectives for future use
5. Update/Insert status in quest_tasks
6. UI queries both tables to display objectives with current status
```

---

## Quick Database Checks

**Check quest_objectives table:**
```powershell
.\sqlite3.exe "C:\MQ2\config\YALM2\quest_tasks.db" "SELECT objective, task_name, item_name FROM quest_objectives;"
```

**Check how many objectives are cached:**
```powershell
.\sqlite3.exe "C:\MQ2\config\YALM2\quest_tasks.db" "SELECT COUNT(*) FROM quest_objectives;"
```

**Check quest_tasks table:**
```powershell
.\sqlite3.exe "C:\MQ2\config\YALM2\quest_tasks.db" "SELECT character, task_name, objective, status FROM quest_tasks LIMIT 10;"
```

**Check schema:**
```powershell
.\sqlite3.exe "C:\MQ2\config\YALM2\quest_tasks.db" ".schema"
```

---

## Key Points

- **quest_objectives = Static objective cache** - Populated ONCE per unique objective via fuzzy matching
- **quest_tasks = Dynamic status tracking** - Updates frequently as characters progress objectives
- **MQ2LinkDB.db = Read-only reference** - Used only for fuzzy matching on first encounter
- **SQLite location = C:\MQ2\lua\yalm2\sqlite3.exe** - Always available in working directory
