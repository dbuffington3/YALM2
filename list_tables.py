#!/usr/bin/env python3
import sqlite3

conn = sqlite3.connect(r'C:\MQ2\lua\yalm2\lib\linkdb.db')
cur = conn.cursor()
tables = cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
print("Tables in linkdb.db:")
for t in tables:
    print(f"  {t[0]}")
conn.close()
