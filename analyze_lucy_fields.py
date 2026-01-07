#!/usr/bin/env python3
import json
import os

lucy_dir = r'D:\lucy'

# Sample a few Lucy JSON files to see all possible fields
sample_files = [
    'lucy_item_1001.json',
    'lucy_item_10001.json',
    'lucy_item_50000.json',
    'lucy_item_100000.json',
    'lucy_item_121564.json'
]

all_fields = set()
field_types = {}

for filename in sample_files:
    filepath = os.path.join(lucy_dir, filename)
    if os.path.exists(filepath):
        with open(filepath) as f:
            data = json.load(f)
            all_fields.update(data.keys())
            print(f'\nFields in {filename}:')
            for key in sorted(data.keys()):
                value = data[key]
                val_type = type(value).__name__
                if val_type not in field_types:
                    field_types[val_type] = []
                if key not in field_types[val_type]:
                    field_types[val_type].append(key)
                print(f'  {key}: {val_type} = {repr(value)[:70]}')

print(f'\n\n=== SUMMARY ===')
print(f'All unique fields found across samples: {sorted(all_fields)}')
print(f'\nTotal unique fields: {len(all_fields)}')
