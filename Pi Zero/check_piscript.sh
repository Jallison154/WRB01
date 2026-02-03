#!/bin/bash
# Check PiScript for syntax errors and show the problematic area

PSCRIPT="/home/wrb01/WRB/PiScript"

# Find PiScript
if [ ! -f "$PSCRIPT" ]; then
    PSCRIPT=$(find /home/wrb01 -name "PiScript" -type f 2>/dev/null | head -1)
fi

if [ ! -f "$PSCRIPT" ]; then
    echo "ERROR: PiScript not found"
    exit 1
fi

echo "Checking: $PSCRIPT"
echo "=================================="
echo

# Try to compile and show error
python3 -m py_compile "$PSCRIPT" 2>&1

echo
echo "=================================="
echo "Context around the error (lines 260-275):"
echo "=================================="
sed -n '260,275p' "$PSCRIPT" | cat -n

echo
echo "=================================="
echo "All 'try:' statements in file:"
echo "=================================="
grep -n "try:" "$PSCRIPT"

echo
echo "=================================="
echo "All 'except:' statements in file:"
echo "=================================="
grep -n "except" "$PSCRIPT"
