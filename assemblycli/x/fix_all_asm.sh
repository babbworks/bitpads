#!/bin/bash
# =============================================================================
# fix_all_asm.sh
# 
# Aggressive but safe fixer for "invalid combination of opcode and operands"
# errors caused by eax/al mixing in x86-64 assembly on macOS.
#
# Creates backups before modifying anything.
# =============================================================================

echo "=== BitPads Full Assembly Register Fixer ==="
echo "This will fix eax/al register conflicts in all .asm files."

# Step 1: Create backups
echo "Creating backups of all .asm files..."
find . -name "*.asm" -exec cp --backup=numbered {} {}.bak \;

echo "Applying fixes..."

# Fix 1: movzx eax, byte[...]  →  movzx r8d, byte[...]
find . -name "*.asm" -exec sed -i '' 's/movzx[[:space:]]\+eax,[[:space:]]*byte/movzx r8d, byte/g' {} +

# Fix 2: mov eax, byte[...] → movzx r8d, byte[...]
find . -name "*.asm" -exec sed -i '' 's/\bmov[[:space:]]\+eax,[[:space:]]*byte/movzx r8d, byte/g' {} +

# Fix 3: test al, → test r8b,
find . -name "*.asm" -exec sed -i '' 's/test[[:space:]]\+al,/test r8b,/g' {} +

# Fix 4: More aggressive patterns with eax/al in same block
find . -name "*.asm" -exec sed -i '' 's/movzx[[:space:]]\+eax,[[:space:]]*byte\[rbx/movzx r8d, byte[rbx/g' {} +
find . -name "*.asm" -exec sed -i '' 's/test[[:space:]]\+al,[[:space:]]/test r8b, /g' {} +

# Fix 5: Common reload + test patterns
find . -name "*.asm" -exec sed -i '' 's/movzx[[:space:]]\+eax,[[:space:]]*byte\[rbx + BP_CTX_TASK_BYTE\]/movzx r8d, byte[rbx + BP_CTX_TASK_BYTE]/g' {} +

echo ""
echo "All fixes applied!"
echo ""
echo "Now clean and rebuild:"
echo "   make clean"
echo "   make"
echo ""
echo "If you still get errors, run this script again, or tell me the new error."
echo "Backups are saved as filename.asm.bak"