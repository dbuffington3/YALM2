---
applyTo: '**'
---
Provide project context and coding guidelines that AI should follow when generating code, answering questions, or reviewing changes.

# CRITICAL AGENT RULES - READ FIRST

## BEFORE PROPOSING ANY CHANGES:
1. READ ACTUAL LOG FILES - Never assume what logs say
2. ASK CLARIFYING QUESTIONS - Get specifics from user first
3. MARK ALL ASSUMPTIONS - "I'm assuming X - is that correct?"
4. TEST/REPRODUCE - Ask user to show actual behavior before fixing

## CHANGES REQUIRING APPROVAL FIRST:
- Any change affecting more than 5 lines total across all files
- Any change touching core communication/message handling
- Any change to multiple files
- Any change adding debug code/logging

FORMAT: "I propose [specific change]. Should I proceed?"

## COMMUNICATION FLOW - NEVER SKIP:
1. User reports issue
2. Ask: "What exactly happened? Show me logs?"
3. Ask: "When did this start? After which change?"
4. Ask: "What did we change right before this?"
5. Read the actual logs/context
6. Propose specific fix with file/line numbers
7. Wait for approval
8. Execute ONLY what was approved

## EXECUTION ENVIRONMENT - CRITICAL:
- **Lua cannot be executed natively** - Only PowerShell or Python
- Use `powershell` or `python` to run scripts
- Never attempt direct `lua` command execution
- For Lua code testing: wrap it in PowerShell or use Python subprocess

## QUEST DATABASE - CRITICAL TOOLS:
- **Location**: `C:\MQ2\config\YALM2\quest_tasks.db` (SQLite database)
- **Purpose**: Caches quest objectives and their matched item names (quest_objectives table)
  - Maps quest objective text → item name
  - Persists across script reloads
  - Can cause stale data if old objectives remain cached
- **SQLite Executable**: `C:\mq2\yalm2\sqlite3.exe`
- **Query Examples**:
  ```powershell
  & 'C:\mq2\yalm2\sqlite3.exe' 'C:\MQ2\config\YALM2\quest_tasks.db' "SELECT * FROM quest_objectives WHERE item_name LIKE '%ItemName%'"
  ```
- **When debugging loot decisions**: Always check this database for stale/cached objective mappings that might cause items to be kept when they shouldn't be

## DATABASE ITEM LOOKUPS - COMPLETE ANALYSIS:
- **SQLite Location**: `C:\MQ2\lua\yalm2\MQ2LinkDB.db` (raw_item_data table)
- **When checking items in database, ALWAYS query these columns**:
  - `id, name, questitem, nodrop, guildfavor, cost, tradeskills, stackable`
  - These columns are used in loot/distribution decisions throughout the codebase
- **Query Template**:
  ```powershell
  & 'C:\MQ2\lua\yalm2\sqlite3.exe' 'C:\MQ2\lua\yalm2\MQ2LinkDB.db' "SELECT id, name, questitem, nodrop, guildfavor, cost, tradeskills, stackable FROM raw_item_data WHERE name LIKE '%ItemName%'"
  ```
- **CRITICAL: Cost Value Format (PACKED FORMAT)**:
  - Database `cost` field uses **packed decimal format**, NOT copper
  - Format: Read digits left-to-right as Platinum/Gold/Silver/Copper
  - Example: cost=3200 means 3pp 2gp 0sp 0cp (NOT 3200 copper!)
  - Example: cost=23519 means 23pp 5gp 1sp 9cp
  - **To convert to copper for calculations**: 
    - Extract platinum = cost / 1000 (integer division)
    - Extract gold = (cost % 1000) / 100
    - Extract silver = (cost % 100) / 10  
    - Extract copper = cost % 10
    - Total copper = (platinum × 1000) + (gold × 100) + (silver × 10) + copper
  - **Conversion rates**: 1pp = 1000 copper, 1gp = 100 copper, 1sp = 10 copper, 1cp = 1 copper
- **Key Decision Points These Affect**:
  - `questitem=1`: Item is flagged as quest item → handled by quest system
  - `cost`: Item value in PACKED FORMAT → must convert to copper for "valuable item" logic
  - `tradeskills=1`: Item usable by crafters → keep_tradeskills logic applies
  - `nodrop`: NO TRADE items → stricter class restrictions enforced
  - `guildfavor`: Guild favor item → special handling
  - `stackable`: Non-stackable low-value items may be left on corpse to save inventory
  - `nodrop`: NO TRADE flag affects distribution safety checks