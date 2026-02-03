#!/usr/bin/env python3
"""
Fix indentation issue in PiScript - moves t=classify(line) to correct indentation
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
import shutil
import glob
backups = glob.glob(f"{script_path}.backup.*")
backup_path = f"{script_path}.backup.{len(backups) + 1}"
shutil.copy(script_path, backup_path)
print(f"Backup created: {backup_path}")

# Read file
with open(script_path, 'r') as f:
    lines = f.readlines()

# Find the problematic line around 267
fixed = False
for i in range(len(lines)):
    line = lines[i]
    
    # Look for the line "t=classify(line)" that's incorrectly indented
    stripped = line.rstrip()
    if stripped == "t=classify(line)" or stripped.startswith("t=classify(line)"):
        # Check the indentation
        current_indent = len(line) - len(line.lstrip())
        
        # Look backwards to find the "if not line:" line to match its indentation
        for j in range(i - 1, max(0, i - 10), -1):
            prev_line = lines[j].rstrip()
            if "if not line:" in prev_line:
                # Found it - get its indentation
                correct_indent = len(lines[j]) - len(lines[j].lstrip())
                
                # Fix the indentation of t=classify(line)
                lines[i] = ' ' * correct_indent + "t=classify(line)\n"
                fixed = True
                print(f"Fixed: Line {i+1} indentation corrected to match 'if not line:' at line {j+1}")
                break
        
        if not fixed:
            # If we can't find "if not line:", look for the try block's indentation
            for j in range(i - 1, max(0, i - 20), -1):
                prev_line = lines[j].rstrip()
                if "try:" in prev_line:
                    try_indent = len(lines[j]) - len(lines[j].lstrip())
                    # t=classify should be at same level as the code after try/except
                    # Look for the "if not line:" which should be at try_indent level
                    for k in range(j, i):
                        if "if not line:" in lines[k]:
                            correct_indent = len(lines[k]) - len(lines[k].lstrip())
                            lines[i] = ' ' * correct_indent + "t=classify(line)\n"
                            fixed = True
                            print(f"Fixed: Line {i+1} indentation corrected")
                            break
                    break
        break

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
    print("Could not automatically fix. Showing context around the problematic line:")
    print()
    # Find the line number
    for i in range(len(lines)):
        if "t=classify(line)" in lines[i]:
            start = max(0, i - 5)
            end = min(len(lines), i + 5)
            for j in range(start, end):
                marker = ">>>" if j == i else "   "
                print(f"{marker} {j+1:4d}: {lines[j]}", end='')
            break
    print()
    print("Please fix manually - ensure 't=classify(line)' is at the same indentation as 'if not line:'")
    sys.exit(1)
