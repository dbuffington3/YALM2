IMPORTANT CONFIGURATION LOCATIONS
==================================

Global YALM2 Settings:
  Location: C:\MQ2\config\YALM2.lua
  Purpose: Global configuration that applies to all characters
  Contains: items, preferences, rules, categories, etc.

Character-Specific Settings:
  Location: C:\MQ2\config\YALM2-<SERVER>-<CHARACTER>.lua
  Purpose: Per-character overrides of global settings
  Example: C:\MQ2\config\YALM2-bristlbane-bristle_vexxuss.lua

MQ2 Config Directory:
  The mq.configDir variable in MQ2 points to: C:\MQ2\config\
  
When modifying YALM2 settings:
- ALWAYS check C:\MQ2\config\ first
- Global settings are in YALM2.lua
- Do NOT use AppData\MacroQuest or any other location
