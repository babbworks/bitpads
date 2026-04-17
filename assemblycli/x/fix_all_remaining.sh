#!/bin/bash
# =============================================================================
# fix_all_remaining.sh
# 
# Final aggressive fixer for all "invalid combination of opcode and operands" 
# errors across the entire BitPads project.
# Uses r8d/r8b consistently — the most reliable pattern for macOS NASM.
# =============================================================================

echo "=== Final BitPads Register Fixer (One-Pass) ==="

# Backup everything first
echo "Creating backups of all .asm files..."
find . -name "*.asm" -exec cp --backup=numbered {} {}.bak \;

echo "Applying comprehensive fixes..."

# Fix 1: Replace dangerous eax/al patterns with safe r8d/r8b
find . -name "*.asm" -exec sed -i '' 's/movzx[[:space:]]\+eax,[[:space:]]*byte/movzx r8d, byte/g' {} +
find . -name "*.asm" -exec sed -i '' 's/mov[[:space:]]\+eax,[[:space:]]*byte/movzx r8d, byte/g' {} +
find . -name "*.asm" -exec sed -i '' 's/test[[:space:]]\+al,/test r8b,/g' {} +

# Fix 2: Handle reload patterns more aggressively
find . -name "*.asm" -exec sed -i '' 's/movzx[[:space:]]\+eax,[[:space:]]*byte\[rbx/movzx r8d, byte[rbx/g' {} +
find . -name "*.asm" -exec sed -i '' 's/mov[[:space:]]\+r8d,[[:space:]]*byte\[rbx.*BP_CTX_TASK_BYTE\]/mov r8b, byte[rbx/g' {} +

# Fix 3: Clean up any remaining al after eax-style loads
find . -name "*.asm" -exec sed -i '' 's/\bal,\s*/r8b, /g' {} +

# Fix 4: Common shift + test patterns in ctx1101, cmd1100, etc.
find . -name "*.asm" -exec sed -i '' 's/movzx[[:space:]]\+eax,[[:space:]]*dword/mov r8d, dword/g' {} +

echo ""
echo "All fixes applied in one pass."
echo ""
echo "Now rebuild with:"
echo "   make clean"
echo "   make"
echo ""
echo "If any errors remain, paste the new error message."
echo "Backups are in .bak files if you need to revert."