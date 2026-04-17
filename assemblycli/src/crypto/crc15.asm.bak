; =============================================================================
; crc15.asm — CRC-15 computation and embedding for BitPads Layer 1
;
; Reference: BitPads Protocol v2 §4.1
;   "CRC-15 over bits 1-49, polynomial x^15+x+1 (G(x) = 0x0003)"
;
; The Layer 1 header is 64 bits = 8 bytes.  The CRC protects the session
; identity and control fields encoded in bits 1-49.  Bits 50-64 carry the
; 15-bit CRC remainder that allows any receiver to detect corruption.
;
; Bit-to-byte layout:
;   byte[0]       → protocol bits  1- 8  (MSB of byte = bit 1)
;   byte[1]       → protocol bits  9-16  (bit 12 = byte[1] bit4 = Enhancement flag)
;   byte[2]       → protocol bits 17-24
;   byte[3]       → protocol bits 25-32
;   byte[4]       → protocol bits 33-40
;   byte[5]       → protocol bits 41-48
;   byte[6] bit7  → protocol bit  49     (last data bit, MSB of byte[6])
;   byte[6] b6-0  → CRC bits  1- 7       (upper 7 bits of 15-bit CRC)
;   byte[7]       → CRC bits  8-15       (lower 8 bits of CRC)
;
; Algorithm (standard MSB-first linear feedback shift register):
;   crc = 0
;   for each input bit b (processed MSB-first, byte[0] bit7 first):
;       feedback = ((crc >> 14) & 1) XOR b
;       crc = (crc << 1) & 0x7FFF          ; shift left, mask to 15 bits
;       if feedback != 0: crc ^= 0x0003    ; apply polynomial x^15+x+1 lower terms
;
; Exported symbols:
;   crc15_compute  — compute 15-bit CRC from a 7-byte input buffer (bits 1-56;
;                    only the first 49 are consumed)
;   crc15_embed    — compute CRC over bits 1-49 of an 8-byte Layer 1 buffer
;                    and write the result back into bits 50-64 of that buffer
;
; Calling convention: System V AMD64 (rdi=arg1, rsi=arg2, rax=return)
; Assembled with:     nasm -f macho64
; =============================================================================

%include "include/bitpads.inc"   ; bp_ctx offsets, BPv2_L1_CRC15_POLY, constants
%include "include/syscall.inc"   ; SYS_* numbers (not directly used here but included for consistency)
%include "include/macros.inc"    ; SAVE_REGS / RESTORE_REGS, SET_BIT, etc.

; ── section declarations ──────────────────────────────────────────────────────
section .text

; Export both functions so the linker can resolve them from other translation
; units (layer1.asm calls crc15_embed; test harnesses may call crc15_compute).
global crc15_compute
global crc15_embed


; =============================================================================
; crc15_compute
;
; Computes the CRC-15 remainder over the first 49 bits (MSB-first) of a
; provided buffer.  Only bits 1-49 participate in the CRC calculation as
; specified by BitPads Protocol v2 §4.1.
;
; Inputs:
;   rdi = pointer to a 7-byte buffer whose MS bits form the 49 data bits.
;         byte[0] bit7 = bit 1 (first fed into shift register)
;         byte[6] bit7 = bit 49 (last fed into shift register)
;
; Output:
;   rax = 15-bit CRC value (bits 14-0 significant; bits 63-15 are zero)
;
; Clobbers (callee-saved registers preserved via SAVE_REGS):
;   rbx, r12, r13, r14 (used as scratch; all saved/restored)
;   rdi, rsi, rcx, rdx (caller-saved; not preserved by this function)
; =============================================================================
crc15_compute:
    SAVE_REGS                       ; push rbp/rbx/r12-r15, align stack to 16 bytes

    ; --- Register allocation for this function ---
    ; r12 = pointer to input buffer (preserved across the loops)
    ; r13 = running CRC accumulator (15-bit value, upper bits always 0)
    ; r14 = outer loop counter (byte index: 0..6, we visit 7 bytes)
    ; rbx = current byte being processed
    ; rcx = inner loop counter (bit index within current byte: 7 downto 0)

    mov     r12, rdi                ; r12 ← input buffer pointer (§4.1: bits 1-49 start at byte[0])
    xor     r13, r13                ; r13 ← 0 — initialise CRC shift register to all-zeros per spec
    xor     r14, r14                ; r14 ← 0 — byte loop index starts at first byte

.byte_loop:
    ; Each iteration processes one byte (8 bits) of the input.
    ; We visit bytes 0-5 in full (48 bits), then handle byte 6 specially
    ; to extract only the single valid data bit (bit 49 = bit7 of byte[6]).
    cmp     r14, 7                  ; have we processed all 7 bytes? (indices 0-6)
    jge     .done                   ; yes → CRC computation is complete, return result

    movzx   rbx, byte [r12 + r14]  ; rbx ← zero-extended byte[r14] — current 8-bit group to process

    ; Determine how many bits from this byte contribute to the CRC.
    ; Bytes 0-5 contribute all 8 bits (48 total).
    ; Byte 6 contributes only bit7 (1 bit = bit 49 of the 49-bit data field).
    cmp     r14, 6                  ; are we on byte index 6?
    jne     .full_byte              ; no → process all 8 bits
    mov     rcx, 1                  ; yes → only 1 bit (bit7) from byte[6] is a data bit
    jmp     .bit_loop               ; jump directly into the bit processing loop

.full_byte:
    mov     rcx, 8                  ; rcx ← 8 — process all 8 bits of bytes 0-5

.bit_loop:
    ; Inner loop: feed one bit at a time into the LFSR, MSB-first.
    ; The current bit is always extracted from bit7 of rbx (we shift rbx left
    ; by 1 each iteration to bring the next-significant bit into position 7).
    test    rcx, rcx                ; have we processed all bits for this byte?
    jz      .next_byte              ; yes → advance to the next byte

    ; Step 1: extract the current input bit (always from MSB position of rbx).
    mov     rdx, rbx                ; rdx ← copy of current byte so we can isolate bit7
    shr     rdx, 7                  ; rdx ← bit7 of byte, shifted to bit0 position (value 0 or 1)
    and     rdx, 1                  ; rdx ← input_bit (mask to ensure only bit0 survives)

    ; Step 2: compute feedback = (CRC bit14) XOR input_bit.
    ; bit14 of the 15-bit CRC is the "outgoing" bit leaving the shift register.
    mov     rax, r13                ; rax ← current CRC (15-bit value in bits 14-0)
    shr     rax, 14                 ; rax ← CRC bit14 in bit0 position (the feedback tap)
    and     rax, 1                  ; rax ← CRC[14] (isolate single feedback bit)
    xor     rax, rdx                ; rax ← feedback = CRC[14] XOR input_bit (LFSR equation)

    ; Step 3: shift the CRC register left by 1 and mask to 15 bits.
    ; This discards the old bit14 and shifts all bits one position toward MSB.
    shl     r13, 1                  ; r13 ← CRC << 1 (new bit0 is 0; old bit14 is in bit15)
    and     r13, 0x7FFF             ; r13 ← CRC & 0x7FFF — keep only 15 bits (discard old bit14 now in bit15)

    ; Step 4: conditionally apply the polynomial divisor.
    ; G(x) = x^15 + x + 1 — the x^15 term is implicit (it is the register itself);
    ; the lower terms "x + 1" = 0x0003 are XOR'd into the register when feedback = 1.
    test    rax, rax                ; is feedback non-zero?
    jz      .no_poly                ; feedback=0 → no XOR needed, polynomial does not divide here
    xor     r13, BPv2_L1_CRC15_POLY ; feedback=1 → r13 ^= 0x0003 (apply x+1 lower terms of G(x))

.no_poly:
    ; Step 5: advance to the next bit.
    shl     rbx, 1                  ; rbx ← byte << 1 — bring next-significant bit into bit7 for next iteration
    dec     rcx                     ; rcx ← bits remaining − 1
    jmp     .bit_loop               ; process next bit

.next_byte:
    inc     r14                     ; r14 ← byte index + 1 — advance to next byte
    jmp     .byte_loop              ; process next byte

.done:
    mov     rax, r13                ; rax ← final 15-bit CRC result (return value per ABI)

    RESTORE_REGS                    ; pop r15-r12, rbx, rbp — restore callee-saved state
    ret                             ; return to caller; rax holds CRC-15 value


; =============================================================================
; crc15_embed
;
; Computes CRC-15 over bits 1-49 of an already-populated 8-byte Layer 1 buffer
; and writes the 15-bit remainder into the CRC field occupying bits 50-64.
;
; The CRC is split across two storage locations per the Layer 1 layout:
;   byte[6] bits 6-0 = CRC bits  1- 7 (upper 7 bits: crc >> 8)
;   byte[7]          = CRC bits  8-15 (lower 8 bits: crc & 0xFF)
;
; Note: byte[6] bit7 must be preserved — it carries the LSB of the sub-entity
; field (bit 49), which is a data bit, not part of the CRC.  The embed formula
; is therefore:
;   byte[6] = (byte[6] & 0x80) | (crc >> 8)
;   byte[7] =  crc & 0xFF
;
; Inputs:
;   rdi = pointer to 8-byte Layer 1 output buffer (bytes[0..6] filled; byte[7]=0)
;
; Output:
;   (void — modifies buffer in place; no return value)
;
; Clobbers: rax, rsi, rdx, rcx (all caller-saved per ABI)
; =============================================================================
crc15_embed:
    SAVE_REGS                       ; save callee-saved registers and establish stack frame

    ; We need to call crc15_compute(rdi) to obtain the CRC.
    ; crc15_compute takes rdi = pointer to 7-byte buffer (bytes 0-6 of Layer 1).
    ; The Layer 1 buffer pointer in rdi is already correct — bytes 0-6 hold bits 1-49
    ; (and byte 6 bit7 holds bit 49, bits 6-0 of byte[6] are 0 at this stage).
    ; We save rdi across the call because we need it afterward to write back the CRC.

    mov     r12, rdi                ; r12 ← save Layer 1 buffer pointer across the call to crc15_compute

    ; Call crc15_compute with rdi still pointing to the same buffer.
    ; crc15_compute only reads bytes 0-6 so passing an 8-byte buffer is safe.
    call    crc15_compute           ; rax ← 15-bit CRC over bits 1-49

    ; rax now holds the 15-bit CRC.  We must pack it into bytes[6] and [7].

    ; --- Pack upper 7 CRC bits into byte[6] bits 6-0 ---
    ; First isolate the upper 7 bits: crc >> 8 gives bits 14-8 of CRC in positions 6-0.
    mov     rcx, rax                ; rcx ← CRC (work copy so we do not destroy rax)
    shr     rcx, 8                  ; rcx ← CRC >> 8 → bits 14-8 now occupy bits 6-0 of rcx

    ; Preserve bit7 of byte[6] (sub-entity LSB = Layer 1 bit 49 — this is DATA, not CRC).
    movzx   rdx, byte [r12 + 6]    ; rdx ← current value of byte[6] (contains sub-entity bit in bit7)
    and     rdx, 0x80               ; rdx ← byte[6] & 0x80 — keep ONLY bit7, zero the CRC placeholder bits 6-0
    or      rdx, rcx                ; rdx ← (sub-entity bit) | (upper 7 CRC bits) — merge data and CRC fields
    mov     byte [r12 + 6], dl      ; write merged byte back to byte[6] in Layer 1 buffer

    ; --- Pack lower 8 CRC bits into byte[7] ---
    mov     rcx, rax                ; rcx ← CRC (full 15-bit value again)
    and     rcx, 0xFF               ; rcx ← CRC & 0xFF → lower 8 bits (CRC bits 8-15 per protocol)
    mov     byte [r12 + 7], cl      ; write lower 8 CRC bits to byte[7] of Layer 1 buffer

    ; No return value for this void function (rax will be whatever crc15_compute
    ; left; callers of crc15_embed must not rely on rax).

    RESTORE_REGS                    ; restore callee-saved registers
    ret                             ; return to caller
