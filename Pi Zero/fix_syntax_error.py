#!/usr/bin/env python3
"""
Fix syntax error in PiScript - adds missing except block
"""

import sys
import os

# Find PiScript
script_path = "/home/wrb01/WRB/PiScript"
if not os.path.exists(script_path):
    import subprocess
    result = subprocess.run(['find', '/home/wrb01', '-name', 'PiScript', '-type', 'f'], 
                          capture_output=True, text=True)
    if result.returncode == 0 and result.stdout.strip():
        script_path = result.stdout.strip().split('\n')[0]

if not os.path.exists(script_path):
    print(f"ERROR: PiScript not found")
    sys.exit(1)

print(f"Fixing: {script_path}")

# Backup
backup_path = f"{script_path}.backup"
if os.path.exists(backup_path):
    import shutil
    import glob
    backups = glob.glob(f"{script_path}.backup.*")
    backup_path = f"{script_path}.backup.{len(backups) + 1}"

import shutil
shutil.copy(script_path, backup_path)
print(f"Backup created: {backup_path}")

# Read file
with open(script_path, 'r') as f:
    lines = f.readlines()

# Look for the problematic pattern around line 267
# The error says line 267 has "t=classify(line)" and expects except/finally
# So we need to find a try: block before line 267 that's missing except

fixed = False
i = 0
while i < len(lines) and i < 270:  # Look up to line 270
    line = lines[i]
    
    # Look for try: statements
    stripped = line.rstrip()
    if stripped.endswith('try:'):
        indent = len(line) - len(line.lstrip())
        try_line = i
        
        # Look ahead to find where try block ends
        j = i + 1
        found_except = False
        
        while j < len(lines):
            next_line = lines[j]
            next_stripped = next_line.rstrip()
            next_indent = len(next_line) - len(next_line.lstrip())
            
            # Check for except or finally
            if next_stripped.startswith('except') or next_stripped.startswith('finally'):
                if next_indent == indent:
                    found_except = True
                    break
            
            # If we hit a line at same or less indent that's not part of try block
            if next_stripped and not next_stripped.startswith('#') and next_indent <= indent:
                # This is outside the try block - we need to add except before it
                if not found_except:
                    # Insert except block
                    except_lines = [
                        ' ' * indent + 'except Exception:\n',
                        ' ' * (indent + 4) + 'time.sleep(0.05)\n',
                        ' ' * (indent + 4) + 'continue\n'
                    ]
                    
                    # Insert before this line
                    for k, except_line in enumerate(except_lines):
                        lines.insert(j + k, except_line)
                    
                    fixed = True
                    print(f"Fixed: Added except block after try: at line {try_line + 1}")
                    break
                break
            
            j += 1
        
        if fixed:
            break
    
    i += 1

if fixed:
    # Write fixed file
    with open(script_path, 'w') as f:
        f.writelines(lines)
    
    print(f"✓ File fixed and saved")
    
    # Test syntax
    import py_compile
    try:
        py_compile.compile(script_path, doraise=True)
        print("✓ Syntax check passed!")
        sys.exit(0)
    except py_compile.PyCompileError as e:
        print(f"✗ Syntax error still exists: {e}")
        print("Restoring backup...")
        shutil.copy(backup_path, script_path)
        print("Backup restored")
        sys.exit(1)
else:
    print("Could not automatically fix. Showing context around line 267:")
    print()
    for i in range(max(0, 260), min(len(lines), 275)):
        marker = ">>>" if i == 266 else "   "
        print(f"{marker} {i+1:4d}: {lines[i]}", end='')
    print()
    print("Please fix manually - ensure every 'try:' has an 'except:' or 'finally:' block")
    sys.exit(1)
