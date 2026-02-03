#!/bin/bash
# Fix syntax error in PiScript file
# This script checks and fixes the try/except block issue

echo "=== Fixing PiScript Syntax Error ==="
echo

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

# Check for syntax errors
echo "Checking for syntax errors..."
python3 -m py_compile "$PSCRIPT" 2>&1 | head -20

echo
echo "Checking around line 267..."
sed -n '260,275p' "$PSCRIPT" | cat -n

echo
echo "Looking for try blocks without except..."
# This is a simple check - the actual fix needs to be done manually
grep -n "try:" "$PSCRIPT" | head -10

echo
echo "To fix this, you need to:"
echo "1. Open the file: nano $PSCRIPT"
echo "2. Go to line 267 (or the line with the try statement)"
echo "3. Make sure every 'try:' has a corresponding 'except:' or 'finally:' block"
echo
echo "Common pattern should be:"
echo "  try:"
echo "      line = ser.readline().decode(errors=\"ignore\")"
echo "  except Exception:"
echo "      time.sleep(0.05)"
echo "      continue"
