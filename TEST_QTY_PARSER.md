# Testing Per-Character Quest Quantity Parsing

## Test Button Added to UI

A new button "Test Qty Parser" has been added to the YALM2 Native Quest UI window, right next to the "Refresh Quest Data" button.

## How to Test

1. **Click "Refresh Quest Data"** button in the UI
   - This updates YALM2_Quest_Items_WithQty variable with current quest data
   - Wait for the "Manual refresh complete" message in your log

2. **Click "Test Qty Parser"** button in the UI
   - This parses YALM2_Quest_Items_WithQty and prints results to console

3. **Check the console output**
   - You should see output like:

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

## What's Being Tested

✅ **Parsing YALM2_Quest_Items_WithQty variable** - Can we read the MQ2 variable?
✅ **Splitting by item names** - Are items separated correctly?
✅ **Extracting character:quantity pairs** - Can we parse "char:qty"?
✅ **Converting to numbers** - Are quantities showing as correct numbers?
✅ **Formatting for readability** - Are character names and quantities displayed clearly?

## Expected Results

Each character should appear exactly once per item they need:
- **Forestess** - Only in Orbweaver Silks
- **Vaeloraa** - In both Silks and Pelts
- **Lumarra** - In both Silks and Pelts
- **Tarnook** - In both Silks and Pelts
- **Lyricen** - In both Silks and Pelts
- **Vexxuss** - Only in Orbweaver Silks

## Error Handling

If you see:
```
ERROR: No quest data available - run Refresh Quest Data first!
```

This means:
- YALM2_Quest_Items_WithQty variable hasn't been created yet
- Solution: Click "Refresh Quest Data" first

## What Gets Tested

The test button exercises:

1. **MQ2 variable reading** - Can we access YALM2_Quest_Items_WithQty?
2. **String parsing** - Can we split the format correctly?
3. **Pattern matching** - Can we extract pairs correctly?
4. **Type conversion** - Can we convert to numbers?
5. **Console output** - Can we print results clearly?

All of this is necessary for the actual `get_per_character_needs()` function to work in real distribution logic.

## Next Steps After Testing

Once this test shows correct output:
1. The parsing logic is proven to work
2. `get_per_character_needs()` function is ready
3. Distribution logic can be built using this data
4. Can proceed with deciding who gets what items

## Button Location

In the YALM2 Native Quest window:
```
╔════════════════════════════════════════════╗
║ YALM2 Native Quest                    [X]  ║
╠════════════════════════════════════════════╣
║ Characters tracked: 6                      ║
║ My tasks: X                                ║
║ Last update: Xs ago                        ║
║                                            ║
║ [Refresh Quest Data] [Test Qty Parser] ← YOU ARE HERE
║                                            ║
║ Quest Character:              [Dropdown]   ║
║ ...                                        ║
╚════════════════════════════════════════════╝
```
