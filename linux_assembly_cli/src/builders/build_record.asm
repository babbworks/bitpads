; ═══════════════════════════════════════════════════════════════════════════════
; build_record.asm — Full Record Frame Builder
;
; Reference: BitPads Protocol v2 §3 (Record Transmission)
;
; A Record is the primary structured BitPads frame: 12-21 bytes typically.
; It carries the complete protocol header stack (Layer 1 session identification)
; plus optional Layer 2 batch context, followed by the record body consisting of
; optional blocks: value, time, task, and note.
;
; RECORD FRAME STRUCTURE (transmission order):
;
;   [8 bytes]  Layer 1 — Session Header (layer1_build)
;                        SOH, version, domain, permissions, sender ID, CRC-15
;   [6 bytes]  Layer 2 — Batch Context Header (layer2_build)  [if BP_CTX_LAYER2_PRES]
;                        TX type, scaling factor, decimal pos, separators, currency
;   [1 byte]   Meta Byte 1 — Record mode (bit7=1), SysCtx, continuation, Role C flags
;   [1 byte]   Meta Byte 2 — Archetype, time selector, setup flag, slots flag
;   [optional] Signal Slot Presence byte (if Meta2 bit8 set)
;   [optional] P4 signal (pre-value, if declared in SSP)
;   [optional] Setup Byte (if Meta2 bit7 set)
;   [optional] Value Block — 1-4 bytes (if Meta1 bit5=BPv2_META1_ROLC_VAL set)
;   [optional] P5 signal  (post-value)
;   [optional] Time Field — 0-2 bytes (if Meta1 bit6=BPv2_META1_ROLC_TIME set)
;   [optional] P6 signal  (post-time)
;   [optional] Task Block — 1-3 bytes (if Meta1 bit7=BPv2_META1_ROLC_TASK set)
;   [optional] P7 signal  (post-task)
;   [optional] Note Block — 1-64 bytes (if Meta1 bit8=BPv2_META1_ROLC_NOTE set)
;   [optional] P8 signal  (post-record)
;
; Exports: build_record
; Requires: layer1_build, layer2_build, meta1_build, meta2_build, setup_build,
;           value_encode, time_build, task_build, note_build,
;           signals_build_ssp, signals_emit_slot,
;           fileio_write, hexdump_write_trace
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    extern layer1_build
    extern layer2_build
    extern meta1_build
    extern meta2_build
    extern setup_build
    extern value_encode
    extern time_build
    extern task_build
    extern note_build
    extern signals_build_ssp
    extern signals_emit_slot
    extern fileio_write
    extern fileio_write_stdout
    extern hexdump_write_trace

    global build_record

section .bss
    rec_buf     resb BP_OUTBUF_SIZE  ; output buffer for the complete Record frame

section .text
default rel

; ─────────────────────────────────────────────────────────────────────────────
; build_record
;   Assemble and write a complete Record transmission.
;
; Input:  rdi = pointer to bp_ctx
; Output: rax = 0 on success, -1 on error
; ─────────────────────────────────────────────────────────────────────────────
build_record:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14                     ; r14 = rec_buf base address
    sub     rsp, 16                 ; local spill space, keep 16-byte alignment

    mov     rbx, rdi                ; rbx = bp_ctx pointer
    xor     r12d, r12d              ; r12d = current byte offset into rec_buf
    lea     r14, [rel rec_buf]      ; r14 = base address of output buffer

    ; ═══════════════════════════════════════════════════════════════════════
    ; LAYER 1: Session Header (8 bytes, always present in a Record frame)
    ; Carries: SOH, version, domain, permissions, 32-bit sender ID, CRC-15.
    ; "Layer 1 is the 64-bit session identification header." (Protocol v2 §4)
    ; ═══════════════════════════════════════════════════════════════════════
    mov     rdi, rbx
    mov     rsi, r14          ; rsi = start of output buffer
    call    layer1_build            ; rax = 8 (always writes 8 bytes)
    add     r12d, eax               ; advance offset: r12 = 8

    ; ═══════════════════════════════════════════════════════════════════════
    ; LAYER 2: Batch Context Header (6 bytes, conditional)
    ; Present when BP_CTX_LAYER2_PRES is set (batch session has been opened).
    ; "Layer 2 is transmitted once per batch and inherited by every record."
    ; ═══════════════════════════════════════════════════════════════════════
    cmp     byte [rbx + BP_CTX_LAYER2_PRES], 0  ; is Layer 2 present?
    je      .no_layer2              ; no → skip to meta bytes

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    layer2_build            ; rax = 6 (always writes 6 bytes)
    add     r12d, eax               ; advance: r12 = 14

.no_layer2:
    ; ═══════════════════════════════════════════════════════════════════════
    ; META BYTE 1 (1 byte)
    ; For Record mode, bit 7 = 1 (BPv2_META1_MODE is set by meta1_build).
    ; Lower bits declare which optional blocks (value/time/task/note) follow.
    ; ═══════════════════════════════════════════════════════════════════════
    mov     rdi, rbx
    call    meta1_build             ; al = Meta Byte 1
    mov     byte [r14 + r12], al
    inc     r12d                    ; advance 1 byte
    mov     r13b, al                ; r13b = Meta Byte 1 (save for block-present checks)

    ; ═══════════════════════════════════════════════════════════════════════
    ; META BYTE 2 (1 byte)
    ; ═══════════════════════════════════════════════════════════════════════
    mov     rdi, rbx
    call    meta2_build             ; al = Meta Byte 2
    mov     byte [r14 + r12], al
    inc     r12d
    mov     byte [rsp], al          ; spill Meta Byte 2 (stable across calls)

    ; ═══════════════════════════════════════════════════════════════════════
    ; SIGNAL SLOT PRESENCE BYTE (optional — if Meta2 bit8 = BPv2_META2_SLOTS)
    ; ═══════════════════════════════════════════════════════════════════════
    test    byte [rsp], BPv2_META2_SLOTS
    jz      .no_ssp_rec

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    signals_build_ssp       ; rax = 1
    add     r12d, eax

.no_ssp_rec:
    ; ═══════════════════════════════════════════════════════════════════════
    ; P4 SIGNAL (pre-value, optional)
    ; If slot P4 is declared in the SSP, emit it before the value block.
    ; "P4 fires before the value block of a record." (Enhancement §6)
    ; ═══════════════════════════════════════════════════════════════════════
    cmp     byte [rbx + BP_CTX_SIGNAL_SLOTS], 0  ; any signals declared?
    je      .no_p4

    mov     al, byte [rbx + BP_CTX_SIGNAL_SLOTS]
    test    al, BP_SSP_P4           ; is P4 active?
    jz      .no_p4

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    mov     edx, BP_SLOT_P4
    call    signals_emit_slot
    add     r12d, eax

.no_p4:
    ; ═══════════════════════════════════════════════════════════════════════
    ; SETUP BYTE (optional — if Meta2 bit7 = BPv2_META2_SETUP)
    ; ═══════════════════════════════════════════════════════════════════════
    test    byte [rsp], BPv2_META2_SETUP
    jz      .no_setup_rec

    mov     rdi, rbx
    call    setup_build             ; al = Setup Byte
    mov     byte [r14 + r12], al
    inc     r12d

.no_setup_rec:
    ; ═══════════════════════════════════════════════════════════════════════
    ; VALUE BLOCK (optional — if Meta1 bit5 = BPv2_META1_ROLC_VAL = 0x08)
    ; "Value block is present in this record." (Protocol v2 §6)
    ; ═══════════════════════════════════════════════════════════════════════
    test    r13b, BPv2_META1_ROLC_VAL
    jz      .no_value

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    value_encode            ; rax = 1-4 bytes
    add     r12d, eax

.no_value:
    ; P5 post-value signal
    test    byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P5
    jz      .no_p5
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    mov     edx, BP_SLOT_P5
    call    signals_emit_slot
    add     r12d, eax
.no_p5:

    ; ═══════════════════════════════════════════════════════════════════════
    ; TIME FIELD (optional — if Meta1 bit6 = BPv2_META1_ROLC_TIME = 0x04)
    ; ═══════════════════════════════════════════════════════════════════════
    test    r13b, BPv2_META1_ROLC_TIME
    jz      .no_time_rec

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    time_build
    add     r12d, eax

.no_time_rec:
    ; P6 post-time signal
    test    byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P6
    jz      .no_p6
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    mov     edx, BP_SLOT_P6
    call    signals_emit_slot
    add     r12d, eax
.no_p6:

    ; ═══════════════════════════════════════════════════════════════════════
    ; TASK BLOCK (optional — if Meta1 bit7 = BPv2_META1_ROLC_TASK = 0x02)
    ; ═══════════════════════════════════════════════════════════════════════
    test    r13b, BPv2_META1_ROLC_TASK
    jz      .no_task

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    task_build
    add     r12d, eax

.no_task:
    ; P7 post-task signal
    test    byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P7
    jz      .no_p7
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    mov     edx, BP_SLOT_P7
    call    signals_emit_slot
    add     r12d, eax
.no_p7:

    ; ═══════════════════════════════════════════════════════════════════════
    ; NOTE BLOCK (optional — if Meta1 bit8 = BPv2_META1_ROLC_NOTE = 0x01)
    ; ═══════════════════════════════════════════════════════════════════════
    test    r13b, BPv2_META1_ROLC_NOTE
    jz      .no_note

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    note_build
    add     r12d, eax

.no_note:
    ; P8 post-record signal
    test    byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P8
    jz      .no_p8
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    mov     edx, BP_SLOT_P8
    call    signals_emit_slot
    add     r12d, eax
.no_p8:
    mov     edx, r12d
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_DRYRUN
    je      .success
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_HEX
    je      .stdout_raw
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_HEX_RAW
    je      .stdout_raw

    ; ═══════════════════════════════════════════════════════════════════════
    ; Write completed Record frame to output file
    ; ═══════════════════════════════════════════════════════════════════════
    lea     rdi, [rbx + BP_CTX_OUTFILE]
    mov     rsi, r14
    mov     edx, r12d               ; rdx = total frame size (mov zero-extends)
    call    fileio_write
    cmp     rax, 0
    jl      .error

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
    add     rsp, 16
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
