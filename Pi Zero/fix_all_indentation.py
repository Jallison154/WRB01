#!/usr/bin/env python3
"""
Fix indentation issues in PiScript - fixes all lines after the try/except block
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

# Find the "if not line:" line to get the correct indentation
correct_indent = None
if_not_line_idx = None

for i in range(len(lines)):
    if "if not line:" in lines[i]:
        correct_indent = len(lines[i]) - len(lines[i].lstrip())
        if_not_line_idx = i
        print(f"Found 'if not line:' at line {i+1} with indentation: {correct_indent} spaces")
        break

if correct_indent is None:
    print("ERROR: Could not find 'if not line:' line")
    sys.exit(1)

# Now fix all lines that come after "if not line: continue" that are incorrectly indented
# These should be at the same level as "if not line:"
fixed_count = 0
start_fixing = False

for i in range(if_not_line_idx, min(len(lines), if_not_line_idx + 20)):
    line = lines[i]
    stripped = line.rstrip()
    
    # Skip empty lines and comments
    if not stripped or stripped.startswith('#'):
        continue
    
    # After we see "if not line: continue", start fixing subsequent lines
    if "if not line:" in stripped:
        start_fixing = True
        continue
    
    if start_fixing:
        current_indent = len(line) - len(line.lstrip())
        
        # If this line is less indented than "if not line:", it needs fixing
        # But we need to be careful - some lines might be part of if/elif blocks
        # Look for lines that should be at the same level as the code after "if not line:"
        
        # Check if this is a line that should be at the same level (not a control structure)
        is_control_structure = any(stripped.startswith(keyword) for keyword in 
                                   ['if ', 'elif ', 'else:', 'for ', 'while ', 'def ', 'class ', 'try:', 'except', 'finally'])
        
        # If it's not a control structure and has less indentation, fix it
        if not is_control_structure and current_indent < correct_indent:
            # But don't fix if it's clearly part of a nested block (has some indentation)
            if current_indent > 0:
                lines[i] = ' ' * correct_indent + stripped + '\n'
                fixed_count += 1
                print(f"Fixed line {i+1}: '{stripped[:50]}' - indented to {correct_indent} spaces")
        
        # Stop if we hit another control structure at the same or less indentation as "if not line:"
        if is_control_structure and current_indent <= correct_indent and "if not line:" not in stripped:
            break

if fixed_count > 0:
    # Write fixed file
    with open(script_path, 'w') as f:
        f.writelines(lines)
    
    print(f"\n✓ Fixed {fixed_count} line(s)")
    print(f"✓ File saved")
    
    # Test syntax
    import py_compile
    try:
        py_compile.compile(script_path, doraise=True)
        print("✓ Syntax check passed!")
        sys.exit(0)
    except py_compile.PyCompileError as e:
        print(f"\n✗ Syntax error still exists:")
        print(f"  {e}")
        print("\nShowing context around error...")
        # Try to extract line number from error
        error_msg = str(e)
        import re
        match = re.search(r'line (\d+)', error_msg)
        if match:
            error_line = int(match.group(1))
            start = max(0, error_line - 5)
            end = min(len(lines), error_line + 5)
            for j in range(start, end):
                marker = ">>>" if j == error_line - 1 else "   "
                print(f"{marker} {j+1:4d}: {lines[j]}", end='')
        sys.exit(1)
else:
    print("\nNo lines needed fixing, but showing context around the error area:")
    print()
    for i in range(max(0, 260), min(len(lines), 275)):
        marker = ">>>" if i == 267 else "   "
        print(f"{marker} {i+1:4d}: {lines[i]}", end='')
    print()
    print("\nPlease check the indentation manually.")
    sys.exit(1)
