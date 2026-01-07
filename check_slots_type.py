import sqlite3

conn = sqlite3.connect('MQ2LinkDB.db')
cur = conn.cursor()

# Check what type slots is stored as
cur.execute("SELECT typeof(slots), slots FROM raw_item_data WHERE id = 121564 LIMIT 1")
result = cur.fetchone()
print(f"Item 121564 slots field: type={result[0]}, value={result[1]}, repr={repr(result[1])}")

# Check if slots is NULL or empty string for items with 0
cur.execute("SELECT id, typeof(slots), slots FROM raw_item_data WHERE slots IS NULL OR slots = '' OR slots = '0' LIMIT 5")
results = cur.fetchall()
print(f"\nItems with NULL/empty/0 slots:")
for row in results:
    print(f"  Item {row[0]}: type={row[1]}, slots={repr(row[2])}")

conn.close()
