# Graceful Failure Handling & Manual Quest Item Matching

**Status:** ✅ IMPLEMENTED & READY FOR TESTING  
**Date:** December 13, 2025  
**Commits:** 2 (Infrastructure + UI)

---

## Overview

When quest item matching fails automatically (i.e., fuzzy matching can't find a match in the database), the system now gracefully handles the failure instead of retrying forever every 3 seconds. Users can now manually help the system by entering a custom search term.

---

## What Changed

### 1. Failed Objectives Tracking (Infrastructure)

**Files Modified:**
- `yalm2_native_quest.lua` - Added tracking data structures
- `core/quest_interface.lua` - Added failure detection and manual retry

**New Data Structures:**

```lua
-- yalm2_native_quest.lua (lines ~103-108)

local failed_objectives = {}
    -- Maps: objective_text → {filtered_words = {...}}
    -- Tracks objectives that couldn't be automatically matched

local failed_objectives_list = {}
    -- List of failed objective texts (for combo display in UI)
    
local selected_failed_objective = 1
    -- Current selection in UI combo
    
local failed_objective_search_input = ""
    -- User's custom search term input
```

### 2. Failure Detection Logic

**Automatic Refresh Path** (line ~945 in yalm2_native_quest.lua):
```lua
matched_item_name = quest_interface.find_matching_quest_item(objective.objective)
if matched_item_name then
    -- Store in quest_objectives for future lookups
    quest_db.store_objective(objective.objective, task.task_name, matched_item_name)
    -- Remove from failed objectives if it was there before
    failed_objectives[objective.objective] = nil
else
    -- Match failed - track this objective for user assistance
    if not failed_objectives[objective.objective] then
        failed_objectives[objective.objective] = {
            filtered_words = quest_interface.get_last_filtered_words()
        }
        Write.Info("[CHAR_REFRESH] Failed to match objective: '%s' - User can provide search term in UI", objective.objective)
    end
end
```

**Manual Refresh Path** (line ~1116 in yalm2_native_quest.lua):
```lua
-- Same logic as automatic refresh
-- Tracks failures so user can resolve them
```

**Key Point:** Failed objectives are stored ONCE. They don't keep retrying every 3 seconds. The system waits for user input.

### 3. New Functions in quest_interface.lua

#### Function: `get_last_filtered_words()` (line ~219)
```lua
quest_interface.get_last_filtered_words = function()
    return last_filtered_words
end
```

**Purpose:** Return the keywords extracted from the most recent matching attempt  
**Used By:** UI to show user what keywords couldn't find a match  
**Example:** For "Loot 3 pieces of bark from treants" → returns `["bark", "treant"]`

#### Function: `retry_match_with_custom_term()` (line ~227)
```lua
quest_interface.retry_match_with_custom_term = function(objective_text, custom_search_term)
    -- Try exact match first with custom search term
    local query = "SELECT * FROM raw_item_data 
                   WHERE LOWER(name) = LOWER(?) AND questitem = 1"
    
    -- Try fuzzy/contains match if exact fails
    local query = "SELECT * FROM raw_item_data 
                   WHERE LOWER(name) LIKE LOWER('%%%s%%') AND questitem = 1"
    
    return matched_item or nil
end
```

**Purpose:** Perform a single matching attempt with user-provided search term  
**Input:** 
- `objective_text`: Original objective (e.g., "Loot 3 pieces of bark from the treants")
- `custom_search_term`: User-provided search term (e.g., "treant")

**Output:** Matched item name or `nil`

**Process:**
1. Try exact match first (fastest)
2. Try contains/fuzzy match if exact fails
3. Return first match found
4. Log success/failure to character log

---

## UI Implementation

### New View Mode: "Failed" (Line ~544)

**Button Behavior:**
```lua
if ImGui.Button("Failed##ViewMode2", 80, 0) then
    ui_view_mode = 2
    update_failed_objectives_list()
end
```

**Displays when:**
- User clicks "Failed" button
- `ui_view_mode == 2`

### Helper Function: `update_failed_objectives_list()` (Line ~523)

```lua
local function update_failed_objectives_list()
    failed_objectives_list = {}
    for objective_text, _ in pairs(failed_objectives) do
        table.insert(failed_objectives_list, objective_text)
    end
    if selected_failed_objective > #failed_objectives_list then
        selected_failed_objective = 1
    end
end
```

**Purpose:** 
- Convert failed_objectives table to a list for combo display
- Maintain valid selection index
- Called when switching to Failed view mode

### View Function: `display_failed_objectives_view()` (Line ~539)

**Content Layout:**

```
┌─ Failed Objectives View ───────────────────────────────────────┐
│                                                                 │
│ ⚠ 3 objectives failed to match                                │
│                                                                 │
│ Failed Objective: [Combo: Select objective]                   │
│                                                                 │
│ ─────────────────────────────────────────────────────────────  │
│                                                                 │
│ Objective:                                                     │
│ "Loot 3 pieces of bark from the treants"                      │
│                                                                 │
│ Keywords found:                                                │
│ bark, treant                                                   │
│                                                                 │
│ ─────────────────────────────────────────────────────────────  │
│                                                                 │
│ Enter item name to search for:                                │
│ [____________________________________________ text input]     │
│                                                                 │
│ [Retry Match with Custom Term] [Clear]                       │
│                                                                 │
│ Tip: Type part of the item name (e.g., 'treant', 'bark')     │
│ Once matched, the item will be cached and won't appear here.  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Elements:**

1. **Status Header** (Red)
   - Shows count of failed objectives
   - Shows "✓ All objectives matched!" if empty

2. **Failed Objective Selector**
   - Dropdown combo listing all failed objectives
   - Updates when objectives are matched

3. **Objective Details**
   - Full objective text (wrapped for readability)
   - Keywords extracted during automatic matching

4. **Manual Input**
   - Text box for user to enter custom search term
   - Examples shown in tips
   - Can be any part of item name

5. **Action Buttons**
   - "Retry Match with Custom Term" - Attempt matching with custom term
   - "Clear" - Reset the text box

6. **Helpful Tips**
   - Guide user on what to type
   - Explain caching behavior

**User Workflow:**

```
Step 1: Switch to "Failed" tab
    ↓
Step 2: See list of objectives that couldn't match
    ↓
Step 3: Select an objective from dropdown
    ↓
Step 4: See keywords extracted + original objective
    ↓
Step 5: Type custom search term in text box (e.g., "treant bark")
    ↓
Step 6: Click "Retry Match with Custom Term"
    ↓
Step 7a: If match found → cached, removed from failed list
Step 7b: If no match → error message shown in chat
    ↓
Step 8: Move to next failed objective or repeat with different term
```

---

## How It Works End-to-End

### Scenario: Quest Item Can't Be Matched Automatically

```
Time 0:00 - Objective arrives
    ↓
"Loot 3 pieces of bark from the treants"
    ↓
Automatic fuzzy matching attempts
    ├─ Cleaned: "pieces of bark from the treants"
    ├─ Filtered words: ["bark", "treant"]
    ├─ Search terms: ["bark treant", "bark", "treant"]
    └─ Result: NO MATCH in database
    ↓
failed_objectives["Loot 3 pieces of bark from the treants"] = {
    filtered_words = ["bark", "treant"]
}
    ↓
Write.Info("[CHAR_REFRESH] Failed to match objective: ...")
    ↓
No more automatic retries (not cached)

Time 3:00 - Next 3-second auto refresh
    ↓
Check cache: NOT FOUND (failed objectives not cached)
    ↓
Check if already in failed_objectives: YES
    ↓
Skip automatic matching (already tracked)
    ↓
No new log spam!

Time 5:30 - User clicks "Failed" button in UI
    ↓
display_failed_objectives_view() renders
    ├─ Shows count: "⚠ 1 objectives failed to match"
    ├─ Dropdown: "Loot 3 pieces of bark from the treants"
    ├─ Keywords: "bark, treant"
    └─ Text box: (empty, waiting for input)
    ↓
User types: "treant bark"
    ↓
User clicks "Retry Match with Custom Term"
    ↓
quest_interface.retry_match_with_custom_term(
    "Loot 3 pieces of bark from the treants",
    "treant bark"
)
    ├─ Query: SELECT * WHERE name LIKE '%treant bark%'
    ├─ Result: "Treant Bark" (questitem=1)
    └─ Return: "Treant Bark"
    ↓
matched_item = "Treant Bark" (SUCCESS!)
    ↓
quest_db.store_objective(objective, "", "Treant Bark")
    ├─ Caches the result
    └─ Future automatic matches use this
    ↓
failed_objectives["Loot 3 pieces of bark from the treants"] = nil
    ├─ Removes from failed list
    └─ Won't appear in UI anymore
    ↓
update_failed_objectives_list()
    ├─ Rebuilds combo
    └─ UI now shows "✓ All objectives matched!" or next failed item
    ↓
Write.Info("[UI] Manual override successful: ... -> 'Treant Bark'")
```

---

## Key Features

### ✅ No More Infinite Retries
- Failed objectives NOT cached (can't retry automatically)
- Don't appear in 3-second auto-refresh retries
- Only retried when user provides new information

### ✅ User-Friendly Failure Handling
- Clear UI showing what failed
- Keywords displayed so user understands what was searched
- Simple text input + button to try custom search
- Success/failure logged to character log

### ✅ One-Time Matching
- Once user successfully matches: result cached
- Same objective won't appear in UI again
- Future encounters use cached match (instant)

### ✅ Non-Intrusive
- Users who don't have failures see nothing
- "Failed" tab empty when everything matches
- No spam logging for failed objectives

### ✅ Extensible
- Easy to add more options later (e.g., dropdown of common items)
- Manual override data stored same as auto matches
- Same validation (questitem=1 requirement)

---

## Code Structure Summary

### Data Flow for Failures

```
Objective arrives
    ↓
fuzzy_matching.find_matching_quest_item(objective)
    ├─ YES: Cache result, continue
    └─ NO: ↓
          Store in failed_objectives with filtered_words
          ↓
          Write.Info to user
          ↓
          UI can access failed_objectives
          ↓
          User views UI, selects objective
          ↓
          User enters custom search term
          ↓
          Click "Retry" button
          ↓
          quest_interface.retry_match_with_custom_term()
          ├─ YES: Cache result, remove from failed_objectives
          └─ NO: Log error, stay in failed list
```

### Files Changed

1. **yalm2_native_quest.lua**
   - Added `failed_objectives` tracking table
   - Added `failed_objectives_list` for UI combo
   - Added UI state variables
   - Modified CHAR_REFRESH to track failures
   - Modified manual_refresh to track failures
   - Added `update_failed_objectives_list()` function
   - Added `display_failed_objectives_view()` function
   - Added "Failed" view mode button and handler

2. **core/quest_interface.lua**
   - Added `last_filtered_words` variable
   - Added `get_last_filtered_words()` function
   - Added `retry_match_with_custom_term()` function
   - Updated `find_matching_quest_item()` to store filtered_words

---

## Testing Checklist

When user tests, verify:

- [ ] Failed objective appears in "Failed" view mode
- [ ] Objective text displays correctly
- [ ] Filtered words show correctly (extracted keywords)
- [ ] User can type in text box without error
- [ ] "Retry Match" button works and attempts matching
- [ ] Successful match: objective removed from list, logged
- [ ] Failed match: error message shown, stays in list
- [ ] No log spam from 3-second retries during failed match
- [ ] Matched item can be used for looting
- [ ] After restart: matched item still cached and works

---

## Future Enhancements

Could add later without changing current design:

1. **Item Dropdown** - Show list of similar items in database
2. **Item ID Search** - If quest provides item ID, use that directly
3. **Suggestion Algorithm** - Suggest similar item names
4. **Import from Clipboard** - Paste item links
5. **Cache Editor** - View/manage all cached matches
6. **Stats** - Show success rate, common failures
7. **Bulk Retry** - Retry multiple failed items at once

---

## Summary

The graceful failure system:
- ✅ Stops infinite retries (failed items tracked once)
- ✅ Provides user-friendly UI to help system
- ✅ Lets user manually provide search term
- ✅ Caches successful manual matches
- ✅ Non-intrusive (only shows when needed)
- ✅ Extensible for future features

**Status: Ready for testing!** 🚀
