; ═══════════════════════════════════════════════════════════════════════════════
; layer2.asm — Layer 2 Batch Header Builder
;
; Reference: BitPads Protocol v2 §2.5 (Enhancement Sub-Protocol preamble §2.5)
;
; Layer 2 is the 48-bit (6-byte) batch context header. It is transmitted once
; per batch and inherited by every record within that batch. It carries:
;   - Transmission type (pre-converted / copy / represented)
;   - Scaling Factor (SF): magnitude multiplier for value encoding
;   - Optimal Split (S): value block split parameter
;   - Decimal Position (D): number of decimal places for the value
;   - Bells: enquiry and acknowledge bell flags
;   - Separator counters: Group (4-bit) / Record (5-bit) / File (3-bit)
;   - Entity ID: 5-bit sub-entity within the sender
;   - Currency/Quantity Type Code: 6-bit currency index or physical qty type
;   - Rounding Balance: 4-bit net rounding accumulator for the batch
;   - Compound Prefix: 2-bit ceiling on compound groups in this batch
;   - Reserved: bit 48 always = 1
;
; Bit layout across 6 bytes:
;   byte[0] bits7-6: Transmission Type (2 bits)
;   byte[0] bits5-0: Scaling Factor index bits[5:0] (6 of 7 total SF bits)
;   byte[1] bit7:    Scaling Factor index bit[6]
;   byte[1] bits6-3: Optimal Split (4 bits, default=8)
;   byte[1] bits2-0: Decimal Position code (3 bits: 000=0, 010=2, 100=4, 110=6)
;   byte[2] bits7-6: Bells (Enquiry + Acknowledge)
;   byte[2] bits5-0: Group Separator counter bits[5:0]
;   byte[3] bits7-6: Group Separator counter bits[7:6] (overflow)
;     actually Group=4bit, Record=5bit, File=3bit → 12 bits total across bytes[2..3]
;   byte[3] bits5-1: Entity ID (5 bits)
;   byte[3] bit0:    Currency/QType upper bit
;   byte[4] bits7-2: Currency/QType lower 5 bits
;   byte[4] bits1-0: Rounding Balance upper 2 bits
;   byte[5] bits7-6: Rounding Balance lower 2 bits
;   byte[5] bits5-4: Compound Prefix (2 bits)
;   byte[5] bit3:    (padding / reserved space)
;   byte[5] bit0:    Reserved = 1 (always transmit as 1)
;
; Exports: layer2_build
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global layer2_build

section .text

; ─────────────────────────────────────────────────────────────────────────────
; layer2_build
;   Construct the 6-byte Layer 2 Batch Header from bp_ctx.
;
; Input:  rdi = pointer to bp_ctx
;         rsi = pointer to 6-byte output buffer
; Output: rax = 6 (always writes exactly 6 bytes)
; ─────────────────────────────────────────────────────────────────────────────
layer2_build:
    push    rbp
    mov     rbp, rsp
    push    rbx                     ; rbx = bp_ctx pointer (callee-saved)
    push    r12                     ; r12 = output buffer pointer

    mov     rbx, rdi                ; save bp_ctx
    mov     r12, rsi                ; save output buffer

    ; ── Zero the 6-byte output buffer ─────────────────────────────────────
    xor     eax, eax
    mov     dword [r12 + 0], eax    ; zero bytes 0-3
    mov     word  [r12 + 4], ax     ; zero bytes 4-5

    ; ═══════════════════════════════════════════════════════════════════════
    ; BYTE[0]: Transmission Type (bits7-6) + Scaling Factor low 6 bits (bits5-0)
    ;
    ; Transmission Type:
    ;   01 (0x40) = Pre-converted  — values already in declared denomination
    ;   10 (0x80) = Copy          — raw copy of source values
    ;   11 (0xC0) = Represented   — values represent another entity's records
    ;   00        = INVALID (protocol error)
    ; We default to Pre-converted (01).
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   eax, byte [rbx + BP_CTX_L2_TXTYPE]   ; CLI enum in ctx
    cmp     al, BP_L2_TXTYPE_CLI_COPY
    je      .txtype_copy
    cmp     al, BP_L2_TXTYPE_CLI_REP
    je      .txtype_rep
    mov     byte [r12 + 0], BPv2_L2_TXTYPE_PREC  ; default/pre-converted
    jmp     .txtype_done
.txtype_copy:
    mov     byte [r12 + 0], 0x80                 ; wire bits7-6 = 10 (copy/raw)
    jmp     .txtype_done
.txtype_rep:
    mov     byte [r12 + 0], 0xC0                 ; wire bits7-6 = 11 (represented)
.txtype_done:

    ; Scaling Factor (7-bit index, 0-127):
    ;   0 = x1, 1 = x1,000, 2 = x1,000,000, 3 = x1,000,000,000
    ;   (We only use indices 0-3 for the 4 common magnitudes)
    ; Lower 6 bits go in byte[0] bits5-0; bit6 goes in byte[1] bit7.
    movzx   eax, byte [rbx + BP_CTX_SF_INDEX]    ; eax = SF index (0-3 from ctx)
    and     al, 0x3F                             ; mask to 6 bits (lower 6 of 7 SF bits)
    or      byte [r12 + 0], al                   ; merge SF low bits into byte[0]
                                                ; byte[0] = 0x40 | sf[5:0]

    ; ═══════════════════════════════════════════════════════════════════════
    ; BYTE[1]: SF bit6 (bit7) + Optimal Split (bits6-3) + Decimal Pos (bits2-0)
    ; ═══════════════════════════════════════════════════════════════════════

    ; SF bit 6 → byte[1] bit7
    movzx   eax, byte [rbx + BP_CTX_SF_INDEX]    ; reload SF index
    shr     al, 6                                ; isolate SF bit6 (will be 0 for indices 0-3)
    and     al, 0x01                             ; mask to 1 bit
    shl     al, 7                                ; shift to bit7 position of byte[1]
    or      byte [r12 + 1], al                   ; merge SF bit6 into byte[1]

    ; Optimal Split (4 bits, default = 8 = 0b1000):
    ; "Default 8. Value block split parameter." (Layer 2 bits 10-13)
    mov     al, 8                                ; default optimal split = 8
    shl     al, 3                                ; shift to bits 6-3 position = 0b0100_0000... wait
                                                ; bits6-3 of byte[1]: 8 = 0b1000, shifted left 3 = 0b0100_0000
    or      byte [r12 + 1], al                   ; merge optimal split: 8 << 3 = 0x40

    ; Decimal Position (3 bits): 000=0, 010=2, 100=4, 110=6
    ; Convert dp value to 3-bit code:
    ;   dp=0 → 0b000 → 0x00
    ;   dp=2 → 0b010 → write as 1 (since bits2-0 of byte[1] = dp/2)
    ;   dp=4 → 0b100
    ;   dp=6 → 0b110
    movzx   eax, byte [rbx + BP_CTX_DP]          ; eax = decimal position (0, 2, 4, or 6)
    shr     al, 1                                ; dp/2: 0→0, 2→1, 4→2, 6→3
                                                ; this gives us the correct 2-bit index
    ; But the spec uses 3 bits where the pattern is dp/2 in the top 2 bits, LSB=0:
    ; dp=2 → 010 → shift: 1 left 1 = 0b010 = 0x02... let's just use dp >> 1 as the value
    ; Actually the spec says: 000=integer, 010=2places, 100=4places, 110=6places
    ; So the 3-bit field = dp itself interpreted as bits, just take dp's representation:
    ; dp=0 → 000, dp=2 → 010, dp=4 → 100, dp=6 → 110
    ; The 3-bit value = (dp / 2) << 1 = dp itself right-shifted? No:
    ; We want to encode dp=2 as binary 010. dp/2 = 1 = 0b001, then shift left 1 = 0b010. Correct.
    shl     al, 1                                ; (dp/2) << 1 gives us the 3-bit encoding
    and     al, 0x07                             ; mask to 3 bits
    or      byte [r12 + 1], al                   ; merge DP code into byte[1] bits2-0

    ; BYTE[2]: bells (bits7-6) + group separator (bits5-0)
    movzx   eax, byte [rbx + BP_CTX_L2_BELLS]
    and     al, 0x03                             ; bells is stored as 0-3 in ctx
    shl     al, 6                                ; shift to bits7-6 of byte[2]
    or      byte [r12 + 2], al
    movzx   eax, byte [rbx + BP_CTX_L2_GROUP_SEP]
    and     al, 0x3F
    or      byte [r12 + 2], al

    ; ═══════════════════════════════════════════════════════════════════════
    ; BYTE[3]: Separators continued + Entity ID (bits5-1) + Currency upper bit
    ; Entity ID = sub-entity of this batch's sender
    ; ═══════════════════════════════════════════════════════════════════════
    ; record/file separator nibble is packed into byte[3] bits7-6 and byte[4] bit7
    movzx   eax, byte [rbx + BP_CTX_L2_REC_SEP]
    and     al, 0x1F
    mov     dl, al
    shr     al, 3
    and     al, 0x03
    shl     al, 6
    or      byte [r12 + 3], al
    mov     al, dl
    and     al, 0x07
    shl     al, 5
    or      byte [r12 + 4], al

    movzx   eax, byte [rbx + BP_CTX_SUB_ENTITY]  ; eax = 5-bit sub-entity/entity ID
    and     al, 0x1F                             ; mask to 5 bits (0-31)
    shl     al, 1                                ; shift to bits5-1 position of byte[3]
    or      byte [r12 + 3], al                   ; merge entity ID

    ; currency/qtype upper bit (bit5) -> byte[3] bit0
    movzx   eax, byte [rbx + BP_CTX_L2_CURRENCY]
    and     al, 0x3F
    mov     dl, al
    shr     al, 5
    and     al, 0x01
    or      byte [r12 + 3], al

    ; ═══════════════════════════════════════════════════════════════════════
    ; BYTE[4]: Currency/QType lower 5 bits (bits7-3) + Rounding Balance upper 2 (bits1-0)
    mov     al, dl
    and     al, 0x1F
    shl     al, 2
    or      byte [r12 + 4], al
    movzx   eax, byte [rbx + BP_CTX_L2_FILE_SEP]
    and     al, 0x07
    or      byte [r12 + 4], al
    ; ═══════════════════════════════════════════════════════════════════════

    ; ═══════════════════════════════════════════════════════════════════════
    ; BYTE[5]: Rounding Balance lower 2 (bits7-6) + Compound Prefix (bits5-4) + Reserved (bit0=1)
    ;
    ; Compound Prefix (2 bits): ceiling on compound groups in this batch
    ;   00 = No compound groups (1111 is a protocol error even if session mode ON)
    ;   01 = Up to 3 compound groups
    ;   10 = Up to 7 compound groups
    ;   11 = Unlimited compound groups
    ;
    ; Reserved bit 0 = always 1 (per protocol spec)
    ; ═══════════════════════════════════════════════════════════════════════
    mov     byte [r12 + 5], BPv2_L2_RESERVED

    movzx   eax, byte [rbx + BP_CTX_L2_ROUND_BAL]
    and     al, 0x0F
    shl     al, 6
    or      byte [r12 + 5], al

    ; Compound prefix from ctx (bits5-4):
    ;   00=none, 01=max3, 10=max7, 11=unlimited
    movzx   eax, byte [rbx + BP_CTX_COMPOUND_MAX]
    and     al, 0x03
    shl     al, 4
    or      byte [r12 + 5], al

    ; Backward compatibility: legacy --compound promotes "none" to "unlimited"
    cmp     byte [rbx + BP_CTX_COMPOUND], 0
    je      .compound_done
    movzx   eax, byte [rbx + BP_CTX_COMPOUND_MAX]
    and     al, 0x03
    jne     .compound_done
    or      byte [r12 + 5], 0x30

.compound_done:
    mov     rax, BPv2_L2_SIZE                  ; return value = 6 (Layer 2 = 6 bytes always)

    pop     r12
    pop     rbx
    pop     rbp
    ret
