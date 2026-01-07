import sqlite3

conn = sqlite3.connect('MQ2LinkDB.db')
cur = conn.cursor()

# Check the schema
cur.execute("PRAGMA table_info(raw_item_data)")
columns = cur.fetchall()
print(f'Total columns in table: {len(columns)}')
print('All columns:')
for col in columns:
    col_id, name, type_, notnull, dflt_value, pk = col
    print(f'  {name} ({type_})')

print('\nSearching for slots and itemtype columns...')
for col in columns:
    if 'slot' in col[1].lower() or 'itemtype' in col[1].lower():
        print(f'  Found: {col[1]} ({col[2]})')

# Check item 121564
cur.execute("SELECT slots, itemtype FROM raw_item_data WHERE id = 121564")
result = cur.fetchone()
if result:
    print(f'\nItem 121564: slots={result[0]}, itemtype={result[1]}')

conn.close()
