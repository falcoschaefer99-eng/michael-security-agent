#!/bin/bash
# Post-edit security pattern check
# Runs after Write/Edit on .ts, .py, .js files
# Reads tool input from stdin (JSON with file_path, etc.)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path','') or d.get('tool_input',{}).get('file',''))" 2>/dev/null)

# Only check code files
case "$FILE_PATH" in
  *.ts|*.py|*.js) ;;
  *) exit 0 ;;
esac

# Skip if file doesn't exist
[ -f "$FILE_PATH" ] || exit 0

WARNINGS=""

# Check for path traversal vulnerability patterns
if grep -qn '\.\.\/' "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS}PATH_TRAVERSAL: File contains '../' pattern — verify path validation exists\n"
fi

# Check for innerHTML usage with variables (potential XSS)
if grep -qn 'innerHTML\s*=' "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS}XSS_RISK: innerHTML assignment found — prefer textContent for user data\n"
fi

# Check for unsanitized path joins
if grep -qn 'path\.join.*req\.\|path\.join.*params\.\|path\.join.*body\.' "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS}PATH_INPUT: User input in path.join() — ensure validation before join\n"
fi

# Check for non-timing-safe comparisons on auth-looking code
if grep -qn 'apiKey\s*===\|token\s*===\|secret\s*===\|password\s*===' "$FILE_PATH" 2>/dev/null; then
  WARNINGS="${WARNINGS}TIMING_ATTACK: Direct string comparison on auth value — use timingSafeEqual\n"
fi

if [ -n "$WARNINGS" ]; then
  echo -e "SECURITY PATTERNS DETECTED in $FILE_PATH:\n$WARNINGS" >&2
fi

exit 0
