# YALM2
A mashup of YALM and Taskhud that automates some items related to quest related loot items, detection of the loot, and a handy UI to show the status in a simple way.  YALM is the basis with an emphasis on enriching the data that taskhud was being able to gather crams them together into a single system with improvements

YALM2 - Yet Another Loot Manager with TaskHUD Integration

YALM2 is an advanced EverQuest loot distribution system that integrates with features and logic from the original TaskHUD to provide intelligent, quest-aware item distribution for group play. The system automatically detects which group members need quest items and distributes them accordingly, with real-time UI updates and persistent tracking.

## Requirements

### Required MQ2 Plugins
YALM2 requires the **MQ2LinkDB** plugin to be loaded. This is part of the standard RedGuides MacroQuest distribution.

**To load MQ2LinkDB:**
1. In-game, run: `/plugin mq2linkdb load`
2. To make it persistent across sessions, add to your macro or login sequence

**If you don't have MQ2LinkDB:**
1. Ensure you're using the latest MacroQuest from [RedGuides](https://redguides.com)
2. The plugin is included in the standard distribution
3. It provides access to the item database for quest item validation

### Database Files
The repository includes pre-populated database files. Copy these to your MQ2 resources directory:
- `MQ2LinkDB.db` → `C:\MQ2\resources\MQ2LinkDB.db`
- `MQ2LinkDB.db-wal` → `C:\MQ2\resources\MQ2LinkDB.db-wal`

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed installation instructions.

## Why Was This Necessary
Well, because I am lazy and while I am a CLI fan in my day job, my secret passion is automation.  I hate taking something I can visually see and then having to type it in somewhere else.  I especially hate typo's which I am prone to, so I decided to use this as a learning project to teach myself a little lua, work more with AI agents, and just have some fun in the process.  I hated having to get the quests, figure out what they needed and then update lootly to keep X of those items.  I hated it even more when I could see on my screen how many I had, and how many each character still needed.  So, having searched around found nothing that met my specific needs, I decided to start this monster.

## Features

### Core Functionality
- **Quest-Aware Loot Distribution**: Automatically identifies quest items and distributes them to characters who need them
- **Native Quest Integration**: Works seamlessly with EverQuest's native quest system via TaskHUD interface
- **Real-Time Progress Tracking**: Live UI updates showing quest progress as items are distributed
- **Persistent Database**: SQLite-based quest progress tracking that survives across sessions
- **Character-Specific Refresh**: Optimized UI refresh that only updates affected characters (not full system scans)

### Advanced Features
- **Master Looter Coordination**: Centralized loot management via DanNet for multi-character groups
- **Intelligent Item Matching**: Fuzzy matching for quest items handles plurals and partial matches
- **Progress Parsing**: Automatic parsing of quest progress (e.g., "0/2" → "1/2" → "Done")
- **Duplicate Prevention**: Immediate database updates prevent double-distribution of back-to-back quest items
- **Per-Character Quantity Tracking**: Maintains awareness of how many of each quest item each character still needs

### Distribution System
- **Automatic Detection**: Identifies quest items as they drop
- **Smart Routing**: Routes items to appropriate characters based on quest requirements
- **Configurable Preferences**: Support for loot rules and distribution preferences
- **Fallback Handling**: Graceful degradation when items don't match any active quests

## Technical Architecture

### Database Layer
- SQLite persistence at `C:\MQ2\config\YALM2\quest_tasks.db`
- Persistent in-memory connections prevent data loss
- Automatic schema creation and maintenance
- Stores: character name, quest item, progress status, timestamps

### Integration Points
- **TaskHUD Interface**: Reads quest objectives directly from TaskHUD's task window
- **DanNet Broadcasting**: Communicates quest data across characters in group
- **MQ2 LinkDB**: Validates quest items against official item database
- **AdvLoot System**: Distributes items via EverQuest's advanced loot window

### UI Components
- Native quest tracking window with ImGui
- Two-view interface: Tasks view and Database view
- Real-time progress display with color-coded status
- Manual refresh button for on-demand updates

## Recent Enhancements

### Character-Specific Refresh System
Implemented optimized quest UI updates that only refresh affected characters instead of scanning the entire group. This provides:
- Immediate database updates (preventing item loss on back-to-back drops)
- Fast UI refresh within seconds of item distribution
- No performance penalty from full system scans
- Reliable distribution with confirmed state tracking

### Database Persistence
Fixed database persistence to use persistent connections with proper SQLite pragmas:
- DELETE journal mode for Windows compatibility
- Automatic PRAGMA optimization for data sync
- Immediate updates to prevent distribution conflicts
- Full session persistence across restarts

## Configuration

Settings are stored per-character in `C:\MQ2\config\YALM2\` with support for:
- Loot distribution rules and preferences
- Quest item identification
- Per-character quest tracking
- UI preferences and display options

## Usage

Basic commands:
- `/yalm2 help` - Display help information
- `/yalm2 nativequest` - Toggle native quest system on/off
- `/yalm2 taskrefresh` - Force refresh of quest data
- `/yalm2 simulate <item>` - Test item distribution logic
- `/yalm2quest refresh` - Manual quest UI refresh

## Requirements

- EverQuest with MQ2 (MacroQuest2)
- Advanced Loot enabled
- DanNet for multi-character coordination
- I personally run lootly on the characters that are not the master looter so they just accept what I pass out.  You could run YALM or really anything else that will accept the loot I suppose, but lootly is simple and low overhead.  

## Project Status

Early Alpha - It is functional and I am actively running it with a 6 character group but it still bears watching.
