#!/usr/bin/env python3
"""
Run the image_url migration on Supabase
"""
import subprocess
import sys

# Read the SQL file
try:
    with open('add_image_url_column.sql', 'r') as f:
        sql_content = f.read()
    print(f"SQL to execute:\n{sql_content}\n")
except FileNotFoundError:
    print("Error: add_image_url_column.sql not found")
    sys.exit(1)

print("To run this migration:")
print("1. Go to https://supabase.com/dashboard")
print("2. Select your project")
print("3. Go to SQL Editor")
print("4. Click 'New Query'")
print("5. Paste the following SQL:")
print("-" * 60)
print(sql_content)
print("-" * 60)
print("6. Click 'Run'")
print("\nAlternatively, you can use the supabase CLI if you have it installed:")
print("supabase migration new add_image_url_column")
print("# Then add the SQL content to the migration file")
print("supabase db push")
