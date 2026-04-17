; ═══════════════════════════════════════════════════════════════════════════════
; setup.asm — Setup Byte Builder
;
; Reference: BitPads Protocol v2 §6.2
;
; The Setup Byte overrides the session/Layer 2 defaults for a single record's
; value encoding. It is present when Meta Byte 2 bit 7 = 1.
;
; Without a Setup Byte, the decoder assumes:
;   Tier 3 (24-bit value), SF=x1, D=2 decimal places, Layer 2 context active
;
; With a Setup Byte, these can be overridden per-record at the cost of 1 byte.
;
; Bit layout:
;   bits 1-2 (0xC0): Value Tier
;     00 = Tier 1 (8-bit, 1 byte)
;     01 = Tier 2 (16-bit, 2 bytes)
;     10 = Tier 3 (24-bit, 3 bytes) — explicit declaration of default
;     11 = Tier 4 (32-bit, 4 bytes)
;
;   bits 3-4 (0x30): Scaling Factor
;     00 = x1
;     01 = x1,000
;     10 = x1,000,000
;     11 = x1,000,000,000
;
;   bits 5-6 (0x0C): Decimal Position
;     00 = 0 decimal places (integer)
;     01 = 2 decimal places (standard financial)
;     10 = 4 decimal places (high precision)
;     11 = in extension byte (extreme precision)
;
;   bit 7 (0x02): Context Source
;     0 = Override Layer 2 for this record only (Layer 2 context is active)
;     1 = Standalone — no Layer 2 context active, this record has no batch header
;
;   bit 8 (0x01): Rounding Convention
;     0 = Account-type rounding (financial: round half away from zero)
;     1 = Round to nearest (physical quantities: round half to even)
;
; Exports: setup_build
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global setup_build

section .text

; ─────────────────────────────────────────────────────────────────────────────
; setup_build
;   Build the Setup Byte from bp_ctx fields.
;
; Input:  rdi = pointer to bp_ctx
; Output: al  = completed Setup Byte value
;
; The caller writes this byte before the Value Block if Meta Byte 2 bit7 was set.
; ─────────────────────────────────────────────────────────────────────────────
setup_build:
    push    rbp
    mov     rbp, rsp
    push    rbx

    mov     rbx, rdi                ; rbx = bp_ctx pointer (callee-saved)
    xor     eax, eax                ; al = 0x00 — clean setup byte

    ; ═══════════════════════════════════════════════════════════════════════
    ; BITS 1-2 (0xC0): Value Tier
    ; BP_CTX_VALUE_TIER: 0=T1, 1=T2, 2=T3, 3=T4
    ; Map to 2-bit field in upper 2 bits of the byte:
    ;   tier 0 → 00 (0x00)
    ;   tier 1 → 01 (0x40)
    ;   tier 2 → 10 (0x80)
    ;   tier 3 → 11 (0xC0)
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   ecx, byte [rbx + BP_CTX_VALUE_TIER]  ; ecx = tier code (0-3)
    and     cl, 0x03                             ; mask to 2 bits (safety)
    shl     cl, 6                                ; shift to bits7-6 (upper 2 bits = protocol bits 1-2)
                                                ; tier=3 (T4) → 0xC0, tier=0 (T1) → 0x00
    or      al, cl                               ; merge tier into setup byte upper 2 bits

    ; ═══════════════════════════════════════════════════════════════════════
    ; BITS 3-4 (0x30): Scaling Factor
    ; BP_CTX_SF_INDEX: 0=x1, 1=x1000, 2=x1M, 3=x1B
    ; Maps directly to 2-bit field in bits5-4 (protocol bits 3-4):
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   ecx, byte [rbx + BP_CTX_SF_INDEX]    ; ecx = SF index (0-3)
    and     cl, 0x03                             ; mask to 2 bits
    shl     cl, 4                                ; shift to bits5-4 position
                                                ; SF=3 (x1B) → 0x30, SF=0 (x1) → 0x00
    or      al, cl                               ; merge SF code

    ; ═══════════════════════════════════════════════════════════════════════
    ; BITS 5-6 (0x0C): Decimal Position
    ; BP_CTX_DP stores: 0, 2, 4, or 6 (actual decimal places)
    ; Convert to 2-bit code: dp=0→00, dp=2→01, dp=4→10, dp=6→11
    ;   Divide dp by 2 to get the 2-bit index
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   ecx, byte [rbx + BP_CTX_DP]          ; ecx = dp value (0, 2, 4, or 6)
    shr     cl, 1                                ; cl = dp / 2 = 0, 1, 2, or 3
    and     cl, 0x03                             ; mask to 2 bits
    shl     cl, 2                                ; shift to bits3-2 position (protocol bits 5-6)
                                                ; dp=6 → 3 → 0x0C, dp=2 → 1 → 0x04
    or      al, cl                               ; merge DP code

    ; ═══════════════════════════════════════════════════════════════════════
    ; BIT 7 (0x02): Context Source
    ; 0 = Layer 2 batch context is active (override mode)
    ; 1 = Standalone record (no batch header)
    ; Check BP_CTX_LAYER2_PRES (offset 181): if 0 → standalone → set bit7
    ; ═══════════════════════════════════════════════════════════════════════
    cmp     byte [rbx + BP_CTX_LAYER2_PRES], 0   ; is Layer 2 present for this record?
    jne     .has_layer2                           ; yes → context override mode (bit7=0)
    or      al, BP_SETUP_CTX                      ; no Layer 2 → set bit7 (0x02) = standalone
                                                 ; "1=Standalone (no Layer 2 active)"

.has_layer2:
    ; ═══════════════════════════════════════════════════════════════════════
    ; BIT 8 (0x01): Rounding Convention
    ; 0 = Account-type rounding (financial)
    ; 1 = Round-to-nearest (physical quantities, engineering domain)
    ; Check domain: if engineering (BP_DOMAIN_ENG=1), use physical rounding
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   ecx, byte [rbx + BP_CTX_DOMAIN]       ; ecx = domain code
    cmp     cl, BP_DOMAIN_ENG                      ; is it Engineering domain?
    jne     .no_phys_round                         ; no → use financial rounding (bit8=0)
    or      al, BP_SETUP_ROUND                     ; yes → set bit8 (0x01) = round-to-nearest
                                                  ; "1=Round to nearest (physical quantities)"

.no_phys_round:
    ; al = complete Setup Byte

    pop     rbx
    pop     rbp
    ret
