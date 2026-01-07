# Trade State Machine Implementation

## Overview
Implemented a deferred trade execution pattern that respects MQ2's ImGui callback limitations. The trade button no longer attempts to execute delays within the ImGui callback, which was causing "Cannot delay from non-yieldable thread" crashes.

## Architecture

### State Variables (Lines 42-44)
```lua
pending_trade = nil            -- Stores {char_name, upgrade, step} for current trade
trade_step_timer = 0           -- Tracks time within each step (incremented by process_pending_trade)
```

### Trade Flow

#### 1. ImGui Button Callback (Line ~1410)
When user clicks "Trade" button next to an upgrade:
- Sets `pending_trade = {char_name, upgrade, step="pickup"}`
- Sets `trade_step_timer = 0`
- **No delays executed here** (avoids ImGui callback crash)

#### 2. State Machine (process_pending_trade function, Lines 1314-1360)
Called from main event loop every 100ms. Executes trades step-by-step:

**Step 1: pickup** (timer=1 tick)
- Calls `pick_up_item_from_inventory()` with upgrade slot data
- Item is placed on cursor
- Transitions to: step="target", timer=0

**Step 2: target** (timer=5 ticks = 500ms)
- Waits 500ms after pickup
- Executes `/target {char_name}`
- Transitions to: step="usetarget", timer=0

**Step 3: usetarget** (timer=5 ticks = 500ms)
- Waits 500ms after targeting
- Executes `/usetarget` to open trade window
- Transitions to: step="trade_button", timer=0

**Step 4: trade_button** (timer=10 ticks = 1000ms)
- Waits 1000ms for trade window to fully open
- Executes `/shift /itemnotify TRDW_Trade_Button leftmouseup`
- Clears `pending_trade = nil`
- Trade complete!

#### 3. Main Event Loop Integration (Lines 1623-1625)
```lua
while show_cross_upgrade_window or cross_char_results.scan_complete do
    mq.doevents()
    
    process_pending_trade()  -- <-- Called every iteration
    
    mq.delay(100)
    -- ...
end
```

## Why This Works

### Problem with Direct Execution
```lua
-- ❌ THIS CRASHES:
if ImGui.SmallButton(...) then
    mq.delay(500)  -- ERROR: Cannot delay from non-yieldable thread
    mq.cmdf('/usetarget')
end
```

### Solution with State Machine
```lua
-- ✅ THIS WORKS:
if ImGui.SmallButton(...) then
    pending_trade = {...}  -- Just set flag, no delays
end

-- In main loop (can delay):
process_pending_trade()  -- Executes steps with delays
```

## Key Functions

### `distribute_single_upgrade(char_name, upgrade)`
- Called by ImGui trade button
- Queues upgrade for trading
- Returns immediately (no blocking)

### `process_pending_trade()`
- Called from main event loop every 100ms
- Executes pending trade state-by-state
- Increments `trade_step_timer` each call
- Transitions between states based on timer thresholds

### `distribute_upgrades_auto()`
- Placeholder for bulk trade distribution
- Currently just counts upgrades
- Can be extended to queue multiple trades sequentially

## Timing Values (100ms base unit)

| Step | Timer Value | Actual Time | Purpose |
|------|------------|-------------|---------|
| pickup | 1 | 100ms | Execute immediately |
| target | 5 | 500ms | Item pickup delay |
| usetarget | 5 | 500ms | Target acknowledgment |
| trade_button | 10 | 1000ms | Trade window open delay |

## Debug Output

Each trade step produces echo messages:
```
[Trade] Picked up item
[Trade] Targeted {character_name}
[Trade] Opened trade window
✓ Traded {item_name} to {character_name}
```

## Testing

To test the trade system:
1. Open the cross-character upgrade window
2. Click "Trade" next to any upgrade
3. Watch echo messages as trade executes
4. Verify item appears in recipient's inventory

## Future Improvements

- [ ] Bulk queue multiple trades at once
- [ ] Error handling if character logs out
- [ ] Retry logic if trade fails
- [ ] UI feedback showing current trade status
- [ ] Cancel button for pending trades
