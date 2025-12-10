# Testing Checklist - Per-Character Quest Quantity Parsing

## Step-by-Step Test Instructions

### Step 1: Start YALM2
```
/yalm2 start
```
Wait for quest system to initialize (should see "Native quest system initialized successfully")

### Step 2: Open the YALM2 Native Quest UI
You should see a window with "YALM2 Native Quest" in the title
- Characters tracked: Should show 6
- My tasks: Should show your number of active tasks
- Last update: Should show recent time

### Step 3: Click "Refresh Quest Data"
- Wait for "Manual refresh complete" message in your log
- You should see:
  ```
  [YALM2 Native Quest] Manual refresh complete: 2 quest item types updated
  [YALM2 Native Quest] Manual refresh - Orbweaver Silks: 6 characters
  [YALM2 Native Quest] Manual refresh - Tanglefang Pelts: 5 characters
  ```

### Step 4: Click "Test Qty Parser"
- Should immediately print parsing results to console
- Should see output like:

```
============================================================
PER-CHARACTER QUEST ITEM QUANTITIES TEST
============================================================

Orbweaver Silks:
  Forestess       needs 4
  Vaeloraa        needs 3
  Lumarra         needs 2
  Tarnook         needs 6
  Lyricen         needs 3
  Vexxuss         needs 5

Tanglefang Pelts:
  Vaeloraa        needs 2
  Lumarra         needs 3
  Tarnook         needs 4
  Lyricen         needs 1

============================================================
```

## Expected Results

✅ **Success Criteria:**

1. **No variable errors in log**
   - Should NOT see "/varset failed, variable 'YALM2_Quest_Items_WithQty' not found"
   - (This was the bug we just fixed)

2. **Test button shows data**
   - Should see "PER-CHARACTER QUEST ITEM QUANTITIES TEST" header
   - Should NOT see "ERROR: No quest data available"

3. **Character names correct**
   - All 6 characters appear somewhere in output
   - Names are spelled correctly (Forestess, Vaeloraa, etc.)

4. **Item names correct**
   - "Orbweaver Silks" appears
   - "Tanglefang Pelts" appears
   - (Not other items)

5. **Quantities are numbers**
   - Shows "needs 4", "needs 6", etc.
   - Not showing "needs ?" (that would indicate parse error)

6. **Quantities match UI**
   - Open each character's quest log
   - Compare "needs X" from test output with TaskWnd status
   - Example: If Tarnook's status shows "0/6", test should show "needs 6"

## What To Check In Logs

Good signs:
```
[2025/12/09 19:17:08] ============================================================
[2025/12/09 19:17:08] PER-CHARACTER QUEST ITEM QUANTITIES TEST
[2025/12/09 19:17:08] ============================================================
[2025/12/09 19:17:08] Orbweaver Silks:
[2025/12/09 19:17:08]   Forestess       needs 4
[2025/12/09 19:17:08]   Vaeloraa        needs 3
```

Bad signs:
```
[2025/12/09 19:16:54] /varset failed, variable 'YALM2_Quest_Items_WithQty' not found
[2025/12/09 19:17:08] ERROR: No quest data available - run Refresh Quest Data first!
```

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| "ERROR: No quest data available" | Haven't clicked Refresh yet | Click "Refresh Quest Data" first |
| "/varset failed" | Old variable declaration | Fixed - should work now |
| Shows "needs ?" | Status parsing failed | Check TaskWnd status format |
| Missing character | Character not in group | Verify character is online |
| Wrong quantity | Status not read correctly | Check status field in UI |

## Next Steps After Testing

Once all checks pass:
1. ✅ Parsing works correctly
2. ✅ Per-character quantities are captured
3. ✅ Data format is correct
4. ✅ Ready to implement distribution logic

Can proceed with:
- Detection when items drop
- Distribution decisions (who gets what)
- Fair rotation/priority implementation
- Loot processing integration
