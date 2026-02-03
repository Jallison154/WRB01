#!/bin/bash
# Simple fix for indentation issues - fixes lines after try/except block

PSCRIPT="/home/wrb01/WRB/PiScript"

# Find PiScript
if [ ! -f "$PSCRIPT" ]; then
    PSCRIPT=$(find /home/wrb01 -name "PiScript" -type f 2>/dev/null | head -1)
fi

if [ ! -f "$PSCRIPT" ]; then
    echo "ERROR: PiScript not found"
    exit 1
fi

echo "Fixing: $PSCRIPT"
echo

# Backup
BACKUP="${PSCRIPT}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$PSCRIPT" "$BACKUP"
echo "Backup: $BACKUP"
echo

# Use Python to fix
python3 << 'FIXPY'
import sys
import re

script_path = "/home/wrb01/WRB/PiScript"
import os
if not os.path.exists(script_path):
    import subprocess
    result = subprocess.run(['find', '/home/wrb01', '-name', 'PiScript', '-type', 'f'], 
                          capture_output=True, text=True)
    if result.returncode == 0 and result.stdout.strip():
        script_path = result.stdout.strip().split('\n')[0]

with open(script_path, 'r') as f:
    lines = f.readlines()

# Find "if not line:" to get correct indentation
correct_indent = None
if_line_idx = None

for i in range(len(lines)):
    if "if not line:" in lines[i]:
        correct_indent = len(lines[i]) - len(lines[i].lstrip())
        if_line_idx = i
        print(f"Found 'if not line:' at line {if_line_idx+1} with {correct_indent} spaces indent")
        break

if correct_indent is None:
    print("ERROR: Could not find 'if not line:' line")
    sys.exit(1)

# Fix lines that come after "if not line: continue" 
# These should be at same indentation: t=classify(line), current_time = time.time(), etc.
fixed_lines = []
for i in range(if_line_idx + 1, min(len(lines), if_line_idx + 15)):
    line = lines[i]
    stripped = line.rstrip()
    
    # Skip empty lines
    if not stripped:
        continue
    
    # Skip comments
    if stripped.startswith('#'):
        continue
    
    # Check if this is a line that should be fixed
    # Look for lines that are clearly part of the main flow (not nested blocks)
    current_indent = len(line) - len(line.lstrip())
    
    # If line starts with these patterns and has less indent than "if not line:", fix it
    patterns_to_fix = [
        r'^\s*t\s*=\s*classify',
        r'^\s*current_time\s*=',
        r'^\s*if\s+t\s*==',
        r'^\s*elif\s+t\s*==',
    ]
    
    should_fix = False
    for pattern in patterns_to_fix:
        if re.match(pattern, line, re.IGNORECASE):
            if current_indent < correct_indent:
                should_fix = True
                break
    
    # Also fix if it's clearly a statement (not a control structure) with wrong indent
    if not should_fix:
        is_control = any(stripped.startswith(kw) for kw in ['if ', 'elif ', 'else:', 'for ', 'while ', 'def ', 'class ', 'try:', 'except', 'finally'])
        if not is_control and current_indent < correct_indent and current_indent > 0:
            # Check if previous line was "continue" - if so, this should be at same level
            if i > 0 and "continue" in lines[i-1].rstrip():
                should_fix = True
    
    if should_fix:
        lines[i] = ' ' * correct_indent + stripped + '\n'
        fixed_lines.append((i+1, stripped[:50]))

if fixed_lines:
    # Write back
    with open(script_path, 'w') as f:
        f.writelines(lines)
    
    print(f"\nFixed {len(fixed_lines)} line(s):")
    for line_num, content in fixed_lines:
        print(f"  Line {line_num}: {content}")
    
    # Test syntax
    import py_compile
    try:
        py_compile.compile(script_path, doraise=True)
        print("\n✓ Syntax check passed!")
        sys.exit(0)
    except py_compile.PyCompileError as e:
        print(f"\n✗ Syntax error: {e}")
        # Show context
        error_msg = str(e)
        import re
        match = re.search(r'line (\d+)', error_msg)
        if match:
            error_line = int(match.group(1))
            print(f"\nContext around line {error_line}:")
            start = max(0, error_line - 3)
            end = min(len(lines), error_line + 3)
            for j in range(start, end):
                marker = ">>>" if j == error_line - 1 else "   "
                print(f"{marker} {j+1:4d}: {lines[j]}", end='')
        sys.exit(1)
else:
    print("No lines needed fixing. Showing context:")
    for i in range(max(0, 260), min(len(lines), 275)):
        print(f"   {i+1:4d}: {lines[i]}", end='')
    sys.exit(1)
FIXPY

if [ $? -eq 0 ]; then
    echo
    echo "✓ Fix complete! Restart service:"
    echo "  sudo systemctl restart WRB-enhanced.service"
else
    echo
    echo "Please fix manually. The lines after 'if not line: continue' should"
    echo "be at the same indentation level as 'if not line:'"
fi
