# Multi-Group HUD Architecture - Visual Reference

## The Problem → Solution Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ SCENARIO: Two Groups Running Quest HUD Simultaneously               │
└─────────────────────────────────────────────────────────────────────┘

BEFORE (BROKEN):
═══════════════════════════════════════════════════════════════════════

DanNet Network:
  Group 1: Vexxuzz, Lumarra, Thornwick
  Group 2: Bristle, Twiggle, Sparkles

Timeline:
  Time 0: Vexxuzz runs "/yalm2quest"
    Action: /dge /lua run yalm2/yalm2_native_quest nohud
            └─ Starts on ALL except self ← TOO BROAD!
                ├─ Lumarra (Group 1) ✓ CORRECT
                ├─ Thornwick (Group 1) ✓ CORRECT
                ├─ Bristle (Group 2) ✗ WRONG - affects another group!
                ├─ Twiggle (Group 2) ✗ WRONG
                └─ Sparkles (Group 2) ✗ WRONG
    
    Vexxusz Window: ✓ HUD OPEN

  Time 5: Bristle runs "/yalm2quest"
    Action: /dge /lua run yalm2/yalm2_native_quest nohud
            └─ Starts on ALL except self ← STOPS VEXXUSZ!
                ├─ ❌ STOPS Vexxuzz (Group 1 master!) ← DISASTER!
                ├─ Twiggle (Group 2) ✓
                ├─ Sparkles (Group 2) ✓
                ├─ Lumarra (Group 1) ← NOT intended
                └─ Thornwick (Group 1) ← NOT intended
    
    Result:
      Vexxusz Window: ✗ HUD CLOSED (stops script when /dge targets it)
      Bristle Window: ✓ HUD OPEN

    Problem: Only ONE HUD visible ❌


AFTER (FIXED):
═══════════════════════════════════════════════════════════════════════

DanNet Network (same as before):
  Group 1: Vexxuzz, Lumarra, Thornwick
  Group 2: Bristle, Twiggle, Sparkles

Timeline:
  Time 0: Vexxuzz runs "/yalm2quest"
    Action: Loop through Group members only:
              /dquery Lumarra /lua run yalm2/yalm2_native_quest nohud
              /dquery Thornwick /lua run yalm2/yalm2_native_quest nohud
            └─ Targets ONLY actual group members ✓
                ├─ Lumarra (Group 1) ✓
                ├─ Thornwick (Group 1) ✓
                ├─ Bristle (Group 2) ✗ NOT TARGETED (not in Vexxusz's group)
                ├─ Twiggle (Group 2) ✗ NOT TARGETED
                └─ Sparkles (Group 2) ✗ NOT TARGETED
    
    Vexxusz Window: ✓ HUD OPEN
                      (drawGUI = true)

  Time 5: Bristle runs "/yalm2quest"
    Action: Loop through Group members only:
              /dquery Twiggle /lua run yalm2/yalm2_native_quest nohud
              /dquery Sparkles /lua run yalm2/yalm2_native_quest nohud
            └─ Targets ONLY actual group members ✓
                ├─ Twiggle (Group 2) ✓
                ├─ Sparkles (Group 2) ✓
                ├─ Vexxuzz (Group 1) ✗ NOT TARGETED (not in Bristle's group)
                ├─ Lumarra (Group 1) ✗ NOT TARGETED
                └─ Thornwick (Group 1) ✗ NOT TARGETED
    
    Result:
      Vexxusz Window: ✓ HUD STILL OPEN (unaffected by Bristle's commands)
      Bristle Window: ✓ HUD OPEN

    Success: BOTH HUDs visible ✅
```

## Command Comparison

```
OLD APPROACH (Global Broadcast):
═════════════════════════════════

  Master Character: Vexxuzz
  
  /dge /lua run yalm2/yalm2_native_quest nohud
   │
   └─ "/dge" = "do group except" (everyone EXCEPT self)
   
  Affects:
    ✓ Lumarra (intended)
    ✓ Thornwick (intended)
    ✓ Bristle (NOT intended - different group!)
    ✓ Twiggle (NOT intended)
    ✓ Sparkles (NOT intended)
    ... and any other DanNet peer


NEW APPROACH (Group-Specific Targeting):
════════════════════════════════════════

  Master Character: Vexxuzz
  
  Loop through group members:
    /dquery Lumarra /lua run yalm2/yalm2_native_quest nohud
    /dquery Thornwick /lua run yalm2/yalm2_native_quest nohud
     │
     └─ "/dquery" = "send to specific character"
  
  Affects:
    ✓ Lumarra (intended)
    ✓ Thornwick (intended)
    ✗ Bristle (not targeted)
    ✗ Twiggle (not targeted)
    ✗ Sparkles (not targeted)
    ... no other DanNet peers affected
```

## Data Flow Diagram

```
MULTI-GROUP QUEST SYSTEM WITH FULL ISOLATION
═════════════════════════════════════════════

                    GROUP 1                          GROUP 2
           ═══════════════════════        ═══════════════════════

MASTER:    Vexxuzz                        Bristle
           ├─ drawGUI = true              ├─ drawGUI = true
           └─ HUD Window visible          └─ HUD Window visible

COLLECTORS:├─ Lumarra                     ├─ Twiggle
           │  └─ drawGUI = false          │  └─ drawGUI = false
           │     └─ Sends tasks           │     └─ Sends tasks
           │
           └─ Thornwick                   └─ Sparkles
              └─ drawGUI = false             └─ drawGUI = false
                 └─ Sends tasks              └─ Sends tasks

ACTOR MSGS:Group 1 collectors             Group 2 collectors
           send to Vexxuzz's              send to Bristle's
           actor handler                  actor handler
                │                               │
                └─ Filtered by:                 └─ Filtered by:
                   is_character_in_our_group()     is_character_in_our_group()
                   (only accept from              (only accept from
                    Group 1 members)               Group 2 members)

QUEST DATA:task_data.tasks = {           task_data.tasks = {
              Vexxuzz: {...},              Bristle: {...},
              Lumarra: {...},              Twiggle: {...},
              Thornwick: {...}             Sparkles: {...}
           }                               }

HUD DISPLAY:Shows Group 1                 Shows Group 2
           quests only                    quests only

LOOT DIST: Quest items given              Quest items given
           to Group 1 only                to Group 2 only
```

## State Initialization Flow

```
BEFORE (GLOBAL /dge):
═════════════════════

User runs: /yalm2quest
│
├─ check_args() called with no arguments (master instance)
│  │
│  ├─ mq.cmd('/dge /lua stop yalm2/yalm2_native_quest')
│  │  └─ Stops ALL except self (too broad!)
│  │
│  ├─ mq.cmd('/dge /lua run yalm2/yalm2_native_quest nohud')
│  │  └─ Starts on ALL except self (too broad!)
│  │     └─ If 2nd group starts now, Vexxusz's script stops! ❌
│  │
│  └─ drawGUI = true
│
└─ HUD visible (until someone else broadcasts globally)


AFTER (TARGETED /dquery):
════════════════════════

User runs: /yalm2quest
│
├─ check_args() called with no arguments (master instance)
│  │
│  ├─ Detect group membership:
│  │  ├─ mq.TLO.Raid.Members() or 0
│  │  └─ mq.TLO.Group.Members() or 0
│  │
│  ├─ For each group member (except self):
│  │  │
│  │  ├─ Get member.DisplayName()
│  │  │
│  │  └─ mq.cmd(string.format('/dquery %s /lua run yalm2/yalm2_native_quest nohud', member_name))
│  │     └─ Sends ONLY to that member (safe and isolated!)
│  │        └─ Other groups unaffected ✓
│  │
│  └─ drawGUI = true
│
└─ HUD visible (and stays visible - no interference)
```

## ImGui Window Naming

```
Each master has a UNIQUE window name based on character name:

Vexxuzz: "YALM2 Native Quest##Vexxusz"
Bristle: "YALM2 Native Quest##Bristle"

These create separate ImGui windows that don't interfere:

┌──────────────────────────┐    ┌──────────────────────────┐
│ YALM2 Native Quest       │    │ YALM2 Native Quest       │
│ ##Vexxusz                │    │ ##Bristle                │
├──────────────────────────┤    ├──────────────────────────┤
│ Tasks | Database | Failed│    │ Tasks | Database | Failed│
├──────────────────────────┤    ├──────────────────────────┤
│ Vexxusz Quests:          │    │ Bristle Quests:          │
│  - Task 1                │    │  - Task A                │
│  - Task 2                │    │  - Task B                │
│                          │    │                          │
│ Lumarra Quests:          │    │ Twiggle Quests:          │
│  - Task 3                │    │  - Task C                │
│  - Task 4                │    │  - Task D                │
│                          │    │                          │
│ Thornwick Quests:        │    │ Sparkles Quests:         │
│  - Task 5                │    │  - Task E                │
│  - Task 6                │    │  - Task F                │
│                          │    │                          │
└──────────────────────────┘    └──────────────────────────┘
        ↑                                ↑
    Vexxusz                          Bristle
    (Group 1 Master)                (Group 2 Master)
```

## Complete Protection Layers

```
THREE-LAYER ISOLATION SYSTEM:
════════════════════════════════════════════════════════════════

LAYER 1: HUD INITIALIZATION (This Fix)
───────────────────────────────────────
  /dquery targets only group members
  └─ Other groups' masters never stopped
  └─ Both HUDs can run simultaneously
  
LAYER 2: QUEST DATA COLLECTION (Previous Fix)
──────────────────────────────────────────────
  Actor handler checks is_character_in_our_group()
  └─ Out-of-group task data silently dropped
  └─ Each group only sees its own quests
  
LAYER 3: LOOT DISTRIBUTION (Previous Fix)
──────────────────────────────────────────
  get_characters_needing_item() filters by group
  └─ Quest items only considered for group members
  └─ Never attempts to give to other group

Result: COMPLETE ISOLATION ✅
┌──────────────────────────────────────────────────────┐
│ Each group operates independently and safely         │
│ No cross-group interference at any level             │
│ Both HUDs visible and fully functional               │
│ Quest loot properly distributed within groups only   │
└──────────────────────────────────────────────────────┘
```

## Testing Verification Checklist

```
✅ SETUP
  ☐ Group 1: Vexxuzz, Lumarra, Thornwick
  ☐ Group 2: Bristle, Twiggle, Sparkles
  ☐ All on DanNet

✅ INITIALIZATION
  ☐ On Vexxuzz: /yalm2quest
    ☐ Check /echo shows "Starting as master HUD for Vexxuzz"
    ☐ Check /echo shows "Managing group with 2 members"
    ☐ Vexxusz HUD window appears
    ☐ Vexxusz HUD titled "YALM2 Native Quest##Vexxusz"
  
  ☐ On Bristle: /yalm2quest
    ☐ Check /echo shows "Starting as master HUD for Bristle"
    ☐ Check /echo shows "Managing group with 2 members"
    ☐ Bristle HUD window appears
    ☐ Bristle HUD titled "YALM2 Native Quest##Bristle"

✅ CONCURRENT OPERATION
  ☐ Vexxusz's HUD STILL VISIBLE (not closed)
  ☐ Both HUDs are open at same time
  ☐ Both HUDs are responsive

✅ DATA ISOLATION
  ☐ Vexxusz HUD shows Group 1 quests only
  ☐ Bristle HUD shows Group 2 quests only
  ☐ No cross-group quest data

✅ LOOT DISTRIBUTION
  ☐ Drop quest item on corpse
  ☐ Master looter tries to give to Group 1 member
  ☐ If multiple Group 1 members need it, rotates among them
  ☐ Never attempts to give to Group 2 member

✅ COMMANDS
  ☐ /yalm2quest refresh works on Vexxusz
  ☐ /yalm2quest refresh works on Bristle independently
  ☐ /yalm2quest show/hide work on both

✅ CLEANUP
  ☐ /yalm2quest stop on Vexxusz closes Vexxusz's HUD only
  ☐ Bristle's HUD remains open
  ☐ /yalm2quest stop on Bristle closes Bristle's HUD only
```

## Summary

```
THE FIX IN ONE PICTURE:

BROKEN:  /dge (affects everyone except self) ❌
         └─ When group 2 starts, stops group 1

FIXED:   /dquery (targets specific members) ✓
         └─ Each group independent and safe
```
