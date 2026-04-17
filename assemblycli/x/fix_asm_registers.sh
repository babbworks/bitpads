#!/bin/bash
# =============================================================================
# fix_asm_registers.sh
# 
# Fixes common "invalid combination of opcode and operands" errors
# caused by mixing eax/al in x86-64 assembly on macOS.
#
# Creates .bak backups of every modified file.
# =============================================================================

echo "=== BitPads Assembly Register Fixer ==="
echo "Scanning all .asm files for dangerous register patterns..."

# Create backups first
echo "Creating backups (*.bak) of all .asm files..."
find . -name "*.asm" -exec cp --backup=numbered {} {}.bak \;

# Fix 1: movzx eax, byte [...]  →  movzx r8d, byte [...]
find . -name "*.asm" -exec sed -i '' 's/movzx[[:space:]]\+eax,[[:space:]]*byte/movzx r8d, byte/g' {} +

# Fix 2: mov eax, byte [...] → movzx r8d, byte [...]
find . -name "*.asm" -exec sed -i '' 's/\bmov[[:space:]]\+eax,[[:space:]]*byte/movzx r8d, byte/g' {} +

# Fix 3: test al,  → test r8b,   (after changing to r8d)
find . -name "*.asm" -exec sed -i '' 's/test[[:space:]]\+al,/test r8b,/g' {} +

# Fix 4: Common reload patterns using eax/al
find . -name "*.asm" -exec sed -i '' 's/movzx[[:space:]]\+eax,[[:space:]]*byte\[rbx/movzx r8d, byte[rbx/g' {} +

echo ""
echo "Fixes applied successfully!"
echo ""
echo "Now run:"
echo "   make clean"
echo "   make"
echo ""
echo "If there are still errors, run this script again or check the .bak files."
echo "Backups were created as original.asm.bak"