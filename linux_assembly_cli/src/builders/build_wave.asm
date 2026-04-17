; ═══════════════════════════════════════════════════════════════════════════════
; build_wave.asm — Wave Frame Builder
;
; Reference: BitPads Protocol v2 §2 (Wave Transmission)
;
; A Wave is a lightweight 2-6 byte BitPads frame. It is the most common
; transmission mode for sensor readings, status updates, and data pushes.
; It carries no Layer 1 session header and no Layer 3 ledger record.
;
; WAVE FRAME STRUCTURE (all bytes in transmission order):
;
;   [Byte 0]  Meta Byte 1 — mode=Wave, optional ACK, continuation, treatment,
;                           Role A flags or Role B category (meta1_build)
;   [Byte 1]  Meta Byte 2 — archetype code, time selector, setup/slot flags (meta2_build)
;   [optional] Signal Slot Presence byte (if Meta2 bit 8 set)
;   [optional] P12 signal slot (pre-content, if SSP has P12 configured)
;   [optional] Setup Byte (if Meta2 bit 7 set) — value tier/SF/DP override
;   [optional] Time Field (if Meta2 bits 5-6 ≠ 00) — Tier 1 or Tier 2 timestamp
;   [payload]  Category-specific payload:
;                 0x0C (1100) → cmd1100_build
;                 0x0D (1101) → ctx1101_build
;                 0x0E (1110) → tel1110_build
;                 otherwise   → value_encode (plain numeric value)
;   [optional] P13 signal slot (post-content, if SSP has P13 configured)
;
; Total size: 2 bytes minimum, up to ~6 bytes typical.
;
; Exports: build_wave
; Requires: meta1_build, meta2_build, setup_build, value_encode, time_build,
;           cmd1100_build, ctx1101_build, tel1110_build,
;           signals_build_ssp, signals_emit_slot,
;           fileio_write, hexdump_write_trace
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    extern meta1_build
    extern meta2_build
    extern setup_build
    extern value_encode
    extern time_build
    extern cmd1100_build
    extern ctx1101_build
    extern tel1110_build
    extern signals_build_ssp
    extern signals_emit_slot
    extern fileio_write
    extern fileio_write_stdout
    extern hexdump_write_trace

    global build_wave

section .bss
    wave_buf    resb BP_OUTBUF_SIZE  ; output buffer for the complete Wave frame

section .text
default rel

; ─────────────────────────────────────────────────────────────────────────────
; build_wave
;   Assemble and write a complete Wave transmission.
;
; Input:  rdi = pointer to bp_ctx
; Output: rax = 0 on success, -1 on error
; ─────────────────────────────────────────────────────────────────────────────
build_wave:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14                     ; r14 = wave_buf base address

    mov     rbx, rdi                ; rbx = bp_ctx pointer (preserved across calls)
    xor     r12d, r12d              ; r12d = byte offset into wave_buf (starts at 0)
    lea     r14, [rel wave_buf]     ; r14 = base address of output buffer

    ; ═══════════════════════════════════════════════════════════════════════
    ; META BYTE 1
    ; The first byte of every BitPads frame. For Wave mode, bit 7 = 0.
    ; Encodes: mode=Wave(0), ACK request, continuation, treatment, Role flags/category.
    ; ═══════════════════════════════════════════════════════════════════════
    mov     rdi, rbx                ; rdi = bp_ctx
    call    meta1_build             ; al = completed Meta Byte 1
    mov     byte [r14 + r12], al   ; store Meta Byte 1 at offset 0
    inc     r12d                        ; advance: r12=1

    ; ═══════════════════════════════════════════════════════════════════════
    ; META BYTE 2
    ; Declares archetype, time selector, and optional-byte flags.
    ; bit 8 (0x01) = signal slots present → SSP byte follows
    ; bit 7 (0x02) = setup byte present   → Setup byte follows payload headers
    ; ═══════════════════════════════════════════════════════════════════════
    mov     rdi, rbx
    call    meta2_build             ; al = completed Meta Byte 2
    mov     byte [r14 + r12], al   ; store Meta Byte 2 at offset 1
    inc     r12d                        ; advance: r12=2
    mov     r13b, al                    ; r13b = Meta Byte 2 (save for flag inspection)

    ; ═══════════════════════════════════════════════════════════════════════
    ; SIGNAL SLOT PRESENCE BYTE (optional — only if Meta2 bit 8 = 0x01)
    ; Declares which per-record signal slots (P4-P8) are active.
    ; For Waves, we also check for P12 (pre-content) here.
    ; ═══════════════════════════════════════════════════════════════════════
    test    r13b, BPv2_META2_SLOTS  ; is the signal slots flag set?
    jz      .no_ssp                 ; no → skip SSP byte

    mov     rdi, rbx
    lea     rsi, [r14 + r12]   ; rsi = next buffer position
    call    signals_build_ssp       ; write SSP byte (always 1 byte)
    add     r12d, eax               ; advance by bytes written (should be 1)

.no_ssp:
    ; ═══════════════════════════════════════════════════════════════════════
    ; SETUP BYTE (optional — only if Meta2 bit 7 = 0x02)
    ; Overrides the default value tier, scaling factor, and decimal position.
    ; Written before the time field and payload per protocol ordering.
    ; ═══════════════════════════════════════════════════════════════════════
    test    r13b, BPv2_META2_SETUP  ; is the setup byte flag set?
    jz      .no_setup               ; no → skip setup byte, use session defaults

    mov     rdi, rbx
    call    setup_build             ; al = completed Setup Byte
    mov     byte [r14 + r12], al   ; write Setup Byte
    inc     r12d                        ; advance: one byte written

.no_setup:
    ; ═══════════════════════════════════════════════════════════════════════
    ; TIME FIELD (optional — only if Meta2 bits 5-6 ≠ 00)
    ; Tier 1 session offset: 1 byte. Tier 2 Time Block: 2+ bytes.
    ; ═══════════════════════════════════════════════════════════════════════
    mov     al, r13b
    and     al, BPv2_META2_TIMESEL  ; isolate time selector bits (0x0C mask)
    cmp     al, BPv2_META2_TIMESEL_NONE  ; is time selector = 00 (no time)?
    je      .no_time                ; yes → skip time field

    mov     rdi, rbx
    lea     rsi, [r14 + r12]   ; rsi = next buffer position
    call    time_build              ; rax = bytes written (1 or 2)
    add     r12d, eax               ; advance by bytes written

.no_time:
    ; ═══════════════════════════════════════════════════════════════════════
    ; PAYLOAD: Dispatch on category code in BP_CTX_CATEGORY
    ; Category 1100 = Compact Command  → cmd1100_build
    ; Category 1101 = Context Decl     → ctx1101_build
    ; Category 1110 = Telegraph        → tel1110_build
    ; Anything else = plain value      → value_encode
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   eax, byte [rbx + BP_CTX_CATEGORY]  ; eax = 4-bit category code

    cmp     al, BP_CAT_COMPACT_CMD  ; category 1100?
    je      .cmd_payload

    cmp     al, BP_CAT_CTX_DECL     ; category 1101?
    je      .ctx_payload

    cmp     al, BP_CAT_TELEGRAPH    ; category 1110?
    je      .tel_payload

    ; Default: plain value payload (any other category)
.value_payload:
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    value_encode            ; rax = bytes written (1-4 per tier)
    add     r12d, eax
    jmp     .post_payload

.cmd_payload:
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    cmd1100_build           ; rax = bytes written
    add     r12d, eax
    jmp     .post_payload

.ctx_payload:
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    ctx1101_build           ; rax = bytes written
    add     r12d, eax
    jmp     .post_payload

.tel_payload:
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    tel1110_build           ; rax = bytes written
    add     r12d, eax

.post_payload:
    mov     edx, r12d
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_DRYRUN
    je      .success
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_HEX
    je      .stdout_raw
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_HEX_RAW
    je      .stdout_raw

    ; ═══════════════════════════════════════════════════════════════════════
    ; Write output file
    ; ═══════════════════════════════════════════════════════════════════════
    lea     rdi, [rbx + BP_CTX_OUTFILE]  ; rdi = output filename
    mov     rsi, r14              ; rsi = assembled Wave frame buffer
    mov     edx, r12d                    ; rdx = total bytes written into buffer (mov zero-extends)
    call    fileio_write                 ; write entire Wave frame to file
    cmp     rax, 0
    jl      .error

    ; Optional trace dump
    cmp     byte [rbx + BP_CTX_HEX_TRACE], 0
    je      .success

    lea     rdi, [rbx + BP_CTX_OUTFILE]
    mov     rsi, r14
    mov     edx, r12d
    call    hexdump_write_trace

.success:
    xor     eax, eax
    jmp     .done

.stdout_raw:
    mov     rsi, r14
    mov     rdx, r12
    call    fileio_write_stdout
    xor     eax, eax
    jmp     .done

.error:
    mov     eax, -1

.done:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
