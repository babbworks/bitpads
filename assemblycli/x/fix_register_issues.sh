#!/bin/bash
echo "=== Fixing common register size issues in .asm files ==="

# Backup original files
echo "Creating backups in .bak files..."

find . -name "*.asm" -exec cp {} {}.bak \;

# Fix 1: movzx eax, byte [...]  →  movzx ecx, byte [...]
find . -name "*.asm" -exec sed -i '' 's/movzx[[:space:]]\+eax,[[:space:]]*byte/movzx ecx, byte/g' {} +

# Fix 2: mov eax, byte [...] → movzx ecx, byte [...]
find . -name "*.asm" -exec sed -i '' 's/mov[[:space:]]\+eax,[[:space:]]*byte/movzx ecx, byte/g' {} +

# Fix 3: test al,  → test cl,   (when we changed eax to ecx)
find . -name "*.asm" -exec sed -i '' 's/test[[:space:]]\+al,/test cl,/g' {} +

echo ""
echo "Fixes applied. Now run:"
echo "  make clean"
echo "  make"
echo ""
echo "If it still fails, run ./find_register_issues.sh again to see remaining problems."