#!/usr/bin/env python3
"""Direct Lucy data importer using Python sqlite3"""

import sqlite3
import json
import os
import glob
from pathlib import Path

DB_PATH = r'C:\MQ2\resources\MQ2LinkDB.db'
LUCY_DIR = r'D:\Lucy'

def get_fields_from_sample():
    """Get field list from first Lucy file"""
    sample_file = glob.glob(os.path.join(LUCY_DIR, 'lucy_item_*.json'))[0]
    with open(sample_file, 'r') as f:
        data = json.load(f)
    return sorted(data.keys())

def create_table(fields):
    """Create the database table"""
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    # Drop and recreate
    cur.execute('DROP TABLE IF EXISTS raw_item_data')
    
    # Build CREATE TABLE
    cols = ['id INTEGER PRIMARY KEY']
    for field in fields:
        if field != 'id':
            safe_field = ''.join(c if c.isalnum() or c == '_' else '_' for c in field)
            cols.append(f'{safe_field} TEXT')
    
    sql = 'CREATE TABLE raw_item_data (\n    ' + ',\n    '.join(cols) + '\n)'
    print(f"Creating table with {len(fields)} columns...")
    cur.execute(sql)
    conn.commit()
    print("Table created!")
    return conn, cur, fields

def insert_lucy_data(conn, cur, fields):
    """Insert all Lucy data"""
    lucy_files = sorted(glob.glob(os.path.join(LUCY_DIR, 'lucy_item_*.json')))
    total = len(lucy_files)
    
    print(f"Found {total} Lucy files")
    print("Starting insert...")
    
    success = 0
    errors = 0
    
    for idx, lucy_file in enumerate(lucy_files):
        try:
            # Extract item ID from filename
            item_id = int(lucy_file.split('_')[-1].replace('.json', ''))
            
            # Read and parse JSON
            with open(lucy_file, 'r') as f:
                data = json.load(f)
            
            # Build INSERT with only non-null fields
            cols = ['id']
            vals = ['?']
            params = [item_id]
            
            for field in fields:
                if field == 'id':
                    continue
                if field in data:  # Insert ALL fields that exist, including 0, False, empty strings
                    safe_field = ''.join(c if c.isalnum() or c == '_' else '_' for c in field)
                    cols.append(safe_field)
                    vals.append('?')
                    params.append(str(data[field]))  # Convert to string, including "0"
            
            sql = f"INSERT INTO raw_item_data ({', '.join(cols)}) VALUES ({', '.join(vals)})"
            cur.execute(sql, params)
            success += 1
            
            # Commit every 10000 rows
            if success % 10000 == 0:
                conn.commit()
                pct = (idx+1) / total * 100
                print(f"Progress: {idx+1}/{total} ({pct:.1f}%) - Success: {success}, Errors: {errors}")
        
        except Exception as e:
            errors += 1
            if errors <= 5:
                print(f"Error on {lucy_file}: {e}")
    
    # Final commit
    conn.commit()
    
    print(f"\nComplete!")
    print(f"  Processed: {total}")
    print(f"  Success: {success}")
    print(f"  Errors: {errors}")
    
    # Verify
    cur.execute('SELECT COUNT(*) FROM raw_item_data')
    db_count = cur.fetchone()[0]
    print(f"  Items in database: {db_count}")
    
    cur.execute('SELECT COUNT(*) FROM raw_item_data WHERE ac > 0')
    ac_count = cur.fetchone()[0]
    print(f"  Items with AC: {ac_count}")
    
    cur.execute('SELECT COUNT(*) FROM raw_item_data WHERE ac > 0 AND slots > 0')
    slots_count = cur.fetchone()[0]
    print(f"  Items with AC and slots: {slots_count}")

if __name__ == '__main__':
    print("=== Lucy Data Importer ===")
    print(f"Database: {DB_PATH}")
    print(f"Lucy Dir: {LUCY_DIR}")
    print()
    
    # Get fields
    print("Step 1: Reading Lucy schema...")
    fields = get_fields_from_sample()
    print(f"  Found {len(fields)} fields")
    print(f"  Sample: {', '.join(fields[:12])}...")
    print()
    
    # Create table
    print("Step 2: Creating table...")
    conn, cur, fields = create_table(fields)
    print()
    
    # Insert data
    print("Step 3: Inserting data...")
    insert_lucy_data(conn, cur, fields)
    
    conn.close()
