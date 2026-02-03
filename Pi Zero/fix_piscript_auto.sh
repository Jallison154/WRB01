#!/bin/bash
# Automatically fix the missing except block in PiScript

PSCRIPT="/home/wrb01/WRB/PiScript"

# Find PiScript if not at default location
if [ ! -f "$PSCRIPT" ]; then
    PSCRIPT=$(find /home/wrb01 -name "PiScript" -type f 2>/dev/null | head -1)
fi

if [ ! -f "$PSCRIPT" ]; then
    echo "ERROR: PiScript not found"
    exit 1
fi

echo "Found PiScript at: $PSCRIPT"
echo

# Backup original file
BACKUP="${PSCRIPT}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$PSCRIPT" "$BACKUP"
echo "Backup created: $BACKUP"
echo

# Check the area around line 267
echo "Checking code around line 267..."
sed -n '255,270p' "$PSCRIPT" | cat -n
echo

# Create a Python script to fix the issue
python3 << 'PYTHON_FIX'
import sys
import re

script_path = "/home/wrb01/WRB/PiScript"

# Try to find it if not at default location
import os
if not os.path.exists(script_path):
    import subprocess
    result = subprocess.run(['find', '/home/wrb01', '-name', 'PiScript', '-type', 'f'], 
                          capture_output=True, text=True)
    if result.returncode == 0 and result.stdout.strip():
        script_path = result.stdout.strip().split('\n')[0]

if not os.path.exists(script_path):
    print(f"ERROR: PiScript not found")
    sys.exit(1)

print(f"Reading: {script_path}")

with open(script_path, 'r') as f:
    lines = f.readlines()

# Find the problematic try block
# Look for a try: that's followed by code but no except/finally before the next def/class/if at same indent
fixed = False
i = 0
while i < len(lines):
    line = lines[i]
    
    # Look for try: statements
    if re.match(r'^\s+try:\s*$', line):
        indent = len(line) - len(line.lstrip())
        try_line_num = i
        
        # Look ahead to see if there's an except or finally
        has_except = False
        j = i + 1
        while j < len(lines):
            next_line = lines[j]
            next_indent = len(next_line) - len(next_line.lstrip())
            
            # If we hit a line with same or less indent that's not empty/comment, stop looking
            if next_line.strip() and not next_line.strip().startswith('#') and next_indent <= indent:
                break
            
            # Check if there's an except or finally at the right indent
            if re.match(r'^\s+except', next_line) or re.match(r'^\s+finally:', next_line):
                has_except = True
                break
            
            j += 1
        
        # If no except found, and the next non-empty line after try: is not except/finally, add one
        if not has_except:
            # Find where to insert the except block
            # Look for the next line that would be inside the try block
            j = i + 1
            insert_pos = i + 1
            
            # Skip empty lines and comments
            while j < len(lines) and (not lines[j].strip() or lines[j].strip().startswith('#')):
                j += 1
                insert_pos = j
            
            # Check what's after the try block content
            # If it's a line like "t=classify(line)" or similar, we need to add except before it
            if j < len(lines):
                next_content = lines[j]
                next_indent = len(next_content) - len(next_content.lstrip())
                
                # If next line is at same indent level as try, it's outside the try block
                # We need to add except before it
                if next_indent <= indent and next_content.strip():
                    # Insert except block
                    except_block = ' ' * indent + 'except Exception:\n'
                    except_block += ' ' * (indent + 4) + 'time.sleep(0.05)\n'
                    except_block += ' ' * (indent + 4) + 'continue\n'
                    
                    # Insert before the line that's outside the try block
                    lines.insert(j, except_block)
                    fixed = True
                    print(f"Fixed: Added except block after try: at line {try_line_num + 1}")
                    break
    
    i += 1

if fixed:
    # Write the fixed file
    with open(script_path, 'w') as f:
        f.writelines(lines)
    print(f"\n✓ File fixed and saved")
    print(f"Backup saved at: {script_path}.backup.*")
    
    # Test syntax
    import py_compile
    try:
        py_compile.compile(script_path, doraise=True)
        print("✓ Syntax check passed!")
    except py_compile.PyCompileError as e:
        print(f"✗ Syntax error still exists: {e}")
        print("Restoring backup...")
        import shutil
        import glob
        backups = glob.glob(f"{script_path}.backup.*")
        if backups:
            shutil.copy(backups[-1], script_path)
            print("Backup restored")
        sys.exit(1)
else:
    print("Could not automatically fix the issue.")
    print("Please manually check the try/except blocks in the file.")
    sys.exit(1)
PYTHON_FIX

if [ $? -eq 0 ]; then
    echo
    echo "=== Fix Applied Successfully ==="
    echo
    echo "Testing syntax again..."
    python3 -m py_compile "$PSCRIPT"
    if [ $? -eq 0 ]; then
        echo "✓ Syntax is now correct!"
        echo
        echo "You can now restart the service:"
        echo "  sudo systemctl restart WRB-enhanced.service"
    else
        echo "✗ Syntax error still exists. Please check manually."
    fi
else
    echo "Automatic fix failed. Please fix manually."
fi
