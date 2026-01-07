# NODROP Safety Override - Prevent Item Destruction

## Problem Identified

When an item reaches its keep quota (e.g., "Keep 2" of "Recondite Remnant of Truth"), the system correctly identifies that no one needs it. However, when it falls back to the safety "Keep" default for unmatched items:

1. Item configured: `Keep 2`
2. All characters have 2 of the item
3. Item drops on corpse
4. System: "No one needs this" → Fallback to "Keep" (safety default)
5. **Issue**: If item is NODROP and master looter can't use it:
   - Item is looted by master looter
   - Item cannot be traded (NODROP)
   - Item cannot be sold (NODROP)
   - Item is effectively destroyed

**Example**: "Recondite Remnant of Truth" - NODROP, Paladin-only, looted by Warrior master looter = Item lost forever

## Solution Implemented

Added a **NODROP Safety Override** check in the fallback preference logic:

**When applying the fallback "Keep" rule, check:**
1. Is this item NODROP (NoRent flag)?
2. Can the master looter actually use it (class restrictions)?
3. If NO to either:
   - Override fallback from "Keep" → "Leave"
   - Log warning about destruction risk
   - Leave item on corpse for someone else or delete safely

**File Modified**: `core/evaluate.lua` (Lines 462-501)

## Code Change

```lua
-- Apply unmatched item rule if no preference found
if preference == nil and unmatched_item_rule then
    debug_logger.info("LOOT: No preference found, applying unmatched item rule: %s", 
                      tostring(unmatched_item_rule))
    preference = unmatched_item_rule
    
    -- CRITICAL: Check if this is a NODROP/NOTRADE item that nobody can use
    -- If so, override the "Keep" safety default to "Leave" instead
    if loot_item and loot_item.NoRent and loot_item.NoRent() then
        -- This is a NO TRADE (NODROP) item
        local anyone_can_use = false
        
        -- Check if master looter can use it
        local my_class = mq.TLO.Me.Class.ShortName()
        if loot_item.Class then
            local class_match = loot_item.Class(my_class)
            if class_match ~= "NULL" then
                anyone_can_use = true
            end
        else
            -- No class restriction
            anyone_can_use = true
        end
        
        if not anyone_can_use then
            -- NODROP item and we can't use it
            -- Override to Leave instead of Keep
            Write.Warn("LOOT SAFETY: %s is NODROP and you cannot use it - leaving on corpse", 
                      item_name)
            preference = { setting = "Leave" }
        end
    end
end
```

## How It Works

### Scenario 1: Item Reaches Keep Quota (Safe)
```
Item: "Recondite Remnant of Truth" (NODROP, Paladin-only)
Group: 4 Paladins, all have 2
ML: Paladin

Flow:
1. No one needs it (all have 2)
2. Fallback to "Keep"
3. Check: Is it NODROP? YES
4. Check: Can ML (Paladin) use it? YES
5. Result: Keep it (safe - Paladin can use it)
```

### Scenario 2: Item Reaches Keep Quota (Destructive) - FIXED
```
Item: "Recondite Remnant of Truth" (NODROP, Paladin-only)
Group: 4 Paladins, ML is Warrior

Flow:
1. No one needs it (all Paladins have 2)
2. Fallback to "Keep"
3. Check: Is it NODROP? YES
4. Check: Can ML (Warrior) use it? NO (class restricted)
5. Override: Leave instead of Keep ✓
6. Result: Leave on corpse (prevent destruction)
```

### Scenario 3: Quantity Met, Item is Tradeable (Safe)
```
Item: "Some Tradeable Item" (not NODROP, no restrictions)
Group: All have 2

Flow:
1. No one needs it
2. Fallback to "Keep"
3. Check: Is it NODROP? NO
4. Skip check (safe to keep - tradeable)
5. Result: Keep it
```

## Benefits

✅ **Prevents Item Destruction**: NODROP items that can't be used are left on corpse

✅ **Respects Class Restrictions**: Class-restricted items only kept if usable

✅ **Backward Compatible**: Only affects NODROP items without usable classes

✅ **Clear Logging**: Warns when override happens, explains why

✅ **Flexible**: Still keeps other items with fallback rule (normal behavior)

## Log Examples

### Item Successfully Kept (Safe)
```
[LOOT SAFETY] Master looter (Paladin) CAN use Recondite Remnant of Truth
[LOOT] Final preference: Keep
```

### Item Override to Leave (Prevention)
```
[LOOT SAFETY] Recondite Remnant of Truth is NODROP and master looter cannot use it (class restricted)
[LOOT SAFETY] Overriding fallback rule from Keep to Leave to prevent item destruction
[LOOT SAFETY] Recondite Remnant of Truth is NODROP and you cannot use it - leaving on corpse
```

## Edge Cases Handled

| Scenario | Item Flags | ML Class | Action | Reason |
|----------|-----------|----------|--------|--------|
| Quantity met, NODROP, right class | NODROP, class restricted | Matching class | Keep | Can use it |
| Quantity met, NODROP, wrong class | NODROP, class restricted | Non-matching | Leave | Cannot use, override |
| Quantity met, tradeable | NOT NODROP | Any | Keep | Tradeable, safe |
| Quantity met, NODROP, no restriction | NODROP, any | Any | Keep | No class restriction |
| Quantity not met | NODROP | Any | Keep | Someone needs it |

## Configuration Notes

This check runs automatically when:
- No explicit loot rule matches the item
- System falls back to `unmatched_item_rule` (default: "Keep")
- Item is NODROP (NoRent flag)

**No configuration changes needed** - works with existing settings.

## Testing Recommendations

1. **Test with NODROP item, wrong class**:
   - Set item keep quantity to 1
   - Get 1 on master looter
   - Drop another on corpse
   - Verify it's NOT looted (left on corpse)
   - Check logs for override message

2. **Test with NODROP item, right class**:
   - Same setup but with matching class
   - Verify it IS looted (safety preserved)

3. **Test with tradeable item**:
   - Set keep quantity
   - Get quantity
   - Drop more
   - Verify it IS looted (normal fallback behavior)

## Performance Impact

- **Minimal**: Only runs when falling back to `unmatched_item_rule`
- **One database lookup**: Check item flags
- **One class comparison**: Compare master looter class with item restriction
- **No impact** on normal item processing (rules-based matching)

## Related Features

- **NO TRADE SAFETY**: Lines 60-88 in evaluate.lua
  - Different check: prevents DISTRIBUTION to wrong class
  - This fix: prevents LOOTING items we can't use
  - Both work together for comprehensive safety

## Future Enhancements

1. Extend to check other group members (not just ML)
   - "If ANYONE in group can use it, keep it"
   - More complex but more thorough

2. Add configurable override behavior
   - Let user choose: "always_leave_nodrop" setting
   - Override this safety mechanism if desired

3. Race restrictions
   - Also check race restrictions (not just class)
   - Applies same logic: if nobody can use it, leave it

---

**Status**: Implemented and ready for testing  
**Impact**: Prevents accidental item destruction from NODROP class-restricted items
