#!/bin/bash
echo "=== Scanning for register size conflicts in .asm files ==="

find . -name "*.asm" | while read -r file; do
    echo "Checking $file ..."
    grep -nE "movzx[[:space:]]+eax,[[:space:]]*byte" "$file" && echo "  ^^^ Problematic movzx eax, byte in $file"
    grep -nE "mov[[:space:]]+eax,[[:space:]]*byte" "$file" && echo "  ^^^ Problematic mov eax, byte in $file"
    grep -nE "test[[:space:]]+al," "$file" && echo "  ^^^ test al, ... after eax load in $file"
done

echo ""
echo "Scan complete. Look for lines with 'Problematic' above."