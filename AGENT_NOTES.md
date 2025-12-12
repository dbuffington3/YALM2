IMPORTANT NOTES FOR FUTURE REFERENCE
====================================

1. NEVER make up item names
   - ALWAYS query the LinkDB when discussing item names
   - Use: SELECT name FROM raw_item_data WHERE name LIKE 'search_pattern%'

2. Configuration file location
   - Global YALM2 settings: C:\MQ2\config\YALM2.lua
   - mq.configDir = C:\MQ2\config\
   - Do NOT use AppData or any other location

3. Item configuration structure
   - Global items go in ['items'] section of YALM2.lua
   - Format includes both 'setting' and optionally 'quantity'
   - Example:
     ['Item Name'] = {
       ['setting'] = 'Keep',
       ['quantity'] = 1,
     }

4. Actual Recondite Remnant items (from database):
   - Recondite Remnant of Desire
   - Recondite Remnant of Devotion
   - Recondite Remnant of Fear → Maps to Legs slot (user confirmed via UI)
   - Recondite Remnant of Greed
   - Recondite Remnant of Knowledge
   - Recondite Remnant of Survival
   - Recondite Remnant of Truth (EXCEPTION: keep 2 instead of 1)
   
5. IMPORTANT: Remnant-to-Slot mapping
   - The mapping exists in the database but is not straightforward
   - slots field in raw_item_data may not reliably indicate the relationship
   - User can see the mapping in-game UI
   - Need to confirm: Should we create a hardcoded mapping or find the DB relationship?
