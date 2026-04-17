; ═══════════════════════════════════════════════════════════════════════════════
; signals.asm — Signal Slot Presence Byte and Slot Emission
;
; Reference: BitPads Enhancement Sub-Protocol §6
;            "Signal Slots — Positional Architecture"
;
; Signal slots are 13 declared positions (P1-P13) within a BitPads frame where
; enhanced C0 bytes may be injected. Each slot fires at a specific protocol
; position (before Layer 1, before Layer 2, post-record, etc.).
;
; For RECORDS (the most common use case), per-record slots P4-P8 are declared
; using the Signal Slot Presence (SSP) byte that follows Meta Byte 2 when
; bit 8 (BPv2_META2_SLOTS = 0x01) is set.
;
; SSP BYTE (8 bits, placed after Meta Byte 2):
;   bit 1 (0x80) = P4 pre-value signal is active in this record
;   bit 2 (0x40) = P5 post-value signal is active
;   bit 3 (0x20) = P6 post-time signal is active
;   bit 4 (0x10) = P7 post-task signal is active
;   bit 5 (0x08) = P8 post-record signal is active
;   bits 6-8 (0x07) = reserved — always transmitted as 1 per protocol
;
; Session-level slots (P1-P3, P9-P13) are negotiated at session open and do not
; appear in the per-record SSP byte. They fire unconditionally when the session
; enhancement flag is active.
;
; This module provides:
;   signals_build_ssp  — build the SSP byte from bp_ctx
;   signals_emit_slot  — write the enhanced C0 bytes for a given slot
;
; Exports: signals_build_ssp, signals_emit_slot
; Requires: c0gram_build_slot (extern)
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    extern c0gram_build_slot

    global signals_build_ssp
    global signals_emit_slot

section .text

; ─────────────────────────────────────────────────────────────────────────────
; signals_build_ssp
;   Build the Signal Slot Presence byte from bp_ctx and write it to the buffer.
;
; Input:  rdi = pointer to bp_ctx
;         rsi = pointer to output buffer (1 byte required)
; Output: rax = 1 (always writes exactly 1 byte)
;         [rsi+0] = SSP byte
;
; The SSP byte is derived from BP_CTX_SIGNAL_SLOTS (already a bitmask).
; We OR in the reserved bits (0x07) which must always be 1.
; ─────────────────────────────────────────────────────────────────────────────
signals_build_ssp:
    push    rbp
    mov     rbp, rsp
    push    rbx

    mov     rbx, rdi                ; rbx = bp_ctx pointer

    ; Load the signal slot presence bitmask from ctx
    movzx   eax, byte [rbx + BP_CTX_SIGNAL_SLOTS]  ; eax = P4-P8 presence bits in upper nibble
                                                    ; "each set bit declares a per-record signal"

    ; The protocol requires bits 6-8 = 0x07 to always be 1 (reserved = 1)
    or      al,  BP_SSP_RES         ; force bits 2-0 on = 0x07 = reserved = always 1
                                    ; "bits 6-8: reserved — must be transmitted as 1"

    mov     byte [rsi + 0], al      ; write the completed SSP byte to output buffer
    mov     rax, 1                  ; return 1 byte written

    pop     rbx
    pop     rbp
    ret

; ─────────────────────────────────────────────────────────────────────────────
; signals_emit_slot
;   Emit the enhanced C0 byte(s) for a specific signal slot.
;   Looks up the slot data from BP_CTX_SIGNALS in bp_ctx.
;
; Input:  rdi = pointer to bp_ctx
;         rsi = pointer to output buffer
;         edx = slot number (BP_SLOT_P4 through BP_SLOT_P8 = 4 through 8)
; Output: rax = bytes written (0 if slot not active, 1-3 if active)
;
; BP_CTX_SIGNALS layout (16 bytes starting at offset 96):
;   Bytes  0- 2: slot P4 data (up to 3 enhanced C0 bytes; byte 0 = count if 0, skip)
;   Bytes  3- 5: slot P5 data
;   Bytes  6- 8: slot P6 data
;   Bytes  9-11: slot P7 data
;   Bytes 12-14: slot P8 data
;   Byte  15:    reserved
;
;   Convention: first byte = count of actual C0 bytes (0=slot unused, 1-3=active)
;               bytes 1-3 = the pre-assembled enhanced C0 bytes
; ─────────────────────────────────────────────────────────────────────────────
signals_emit_slot:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    mov     rbx, rdi                ; rbx = bp_ctx pointer
    mov     r12, rsi                ; r12 = output buffer pointer
    mov     r13d, edx               ; r13d = slot number

    ; ── Map slot number to index within BP_CTX_SIGNALS ──────────────────────
    ; Slots P4-P8 map to indices 0-4 in the signals array.
    ; Each entry is 3 bytes wide (count byte + up to 2 C0 bytes, but caller
    ; may use all 3 for the C0 bytes — count is stored separately).
    ;
    ; Layout change: first byte of each 3-byte entry IS the count.
    ;   P4 → BP_CTX_SIGNALS + 0  (bytes 0,1,2 = count,c0a,c0b)
    ;   P5 → BP_CTX_SIGNALS + 3
    ;   P6 → BP_CTX_SIGNALS + 6
    ;   P7 → BP_CTX_SIGNALS + 9
    ;   P8 → BP_CTX_SIGNALS + 12

    sub     r13d, BP_SLOT_P4        ; convert slot number to 0-based index (P4→0, P5→1, ...)
    cmp     r13d, 4                 ; is index in range 0-4?
    ja      .not_active             ; out of range → nothing to emit

    imul    r13d, 3                 ; multiply by 3 to get byte offset into signals array
                                    ; index 0→0, 1→3, 2→6, 3→9, 4→12

    ; ── Read slot count (byte 0 of this slot's 3-byte entry) ────────────────
    movzx   ecx, byte [rbx + BP_CTX_SIGNALS + r13]  ; ecx = count of C0 bytes in this slot
    test    cl, cl                  ; is count zero?
    jz      .not_active             ; count=0 → slot not active → emit nothing

    ; ── Emit the enhanced C0 bytes for this slot ────────────────────────────
    ; Source: [rbx + BP_CTX_SIGNALS + r13 + 1] = the C0 bytes (count bytes starting at +1)
    ; We delegate to c0gram_build_slot which enforces the CONT flag protocol.
    lea     rdi, [rbx + BP_CTX_SIGNALS + r13 + 1]  ; rdi = pointer to raw C0 bytes
    mov     rsi, r12                                 ; rsi = output buffer
    mov     edx, ecx                                 ; edx = count of bytes
    call    c0gram_build_slot                        ; writes bytes with correct CONT flags
                                                     ; rax = bytes written on return

    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.not_active:
    xor     eax, eax                ; rax = 0 (no bytes written — slot not active)
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
