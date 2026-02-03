#!/bin/bash
# Quick fix for indentation of t=classify(line)

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

# Show context
echo "Context around the issue:"
sed -n '260,270p' "$PSCRIPT" | cat -n
echo

# Fix: The line "t=classify(line)" should be at the same indentation as "if not line:"
# Use Python to fix it properly
python3 << 'FIXPY'
import sys

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

# Find the problematic line
for i in range(len(lines)):
    line = lines[i]
    stripped = line.rstrip()
    
    # Find "t=classify(line)" that's incorrectly indented
    if stripped == "t=classify(line)" or (stripped.startswith("t=classify(line") and ")" in stripped):
        # Look backwards for "if not line:" to get correct indentation
        for j in range(i - 1, max(0, i - 15), -1):
            if "if not line:" in lines[j]:
                correct_indent = len(lines[j]) - len(lines[j].lstrip())
                # Fix the line
                lines[i] = ' ' * correct_indent + "t=classify(line)\n"
                print(f"Fixed line {i+1}: indented to match 'if not line:' at line {j+1}")
                break
        break

# Write back
with open(script_path, 'w') as f:
    f.writelines(lines)

# Test syntax
import py_compile
try:
    py_compile.compile(script_path, doraise=True)
    print("✓ Syntax is now correct!")
    sys.exit(0)
except py_compile.PyCompileError as e:
    print(f"✗ Still has error: {e}")
    # Restore backup
    import shutil
    import glob
    backups = glob.glob(f"{script_path}.backup.*")
    if backups:
        shutil.copy(sorted(backups)[-1], script_path)
        print("Backup restored")
    sys.exit(1)
FIXPY

if [ $? -eq 0 ]; then
    echo
    echo "✓ Fix applied successfully!"
    echo "Restart service: sudo systemctl restart WRB-enhanced.service"
else
    echo
    echo "Automatic fix failed. Manual fix needed:"
    echo "  The line 't=classify(line)' should be at the same indentation as 'if not line:'"
    echo "  Edit with: nano $PSCRIPT"
fi
