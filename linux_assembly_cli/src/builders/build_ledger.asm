; ═══════════════════════════════════════════════════════════════════════════════
; build_ledger.asm — Full BitLedger Record Frame Builder
;
; Reference: BitPads Protocol v2 §3 (Layer 3 section)
;            BitLedger Compound Mode Design Note §1–3
;
; A BitLedger frame is the complete double-entry accounting transmission:
; 28+ bytes. It extends the Record frame by adding Layer 3 — the 40-bit
; (5-byte) account routing record.
;
; BITLEDGER FRAME STRUCTURE (transmission order):
;
;   [8 bytes]  Layer 1 — Session Header (layer1_build)
;   [6 bytes]  Layer 2 — Batch Context Header (layer2_build) [if BP_CTX_LAYER2_PRES]
;   [5 bytes]  Layer 3 — BitLedger Record (layer3_build)
;                        Account pair code, direction, completeness, extension
;   [1 byte]   Meta Byte 1 — Record mode, SysCtx, Role C optional-block flags
;   [1 byte]   Meta Byte 2 — Archetype, time selector, setup flag, slots flag
;   [optional] Signal Slot Presence byte
;   [optional] P4 signal (pre-value)
;   [optional] Setup Byte
;   [optional] Value Block (1-4 bytes)
;   [optional] P5 signal (post-value)
;   [optional] Time Field (0-2 bytes)
;   [optional] P6 signal (post-time)
;   [optional] Task Block (1-3 bytes)
;   [optional] P7 signal (post-task)
;   [optional] Note Block (1-64 bytes)
;   [optional] P8 signal (post-record)
;
; COMPOUND ENTRIES:
;   A compound entry spans two consecutive BitLedger frames:
;     Frame 1: normal account pair (e.g. 0x01 = Debtor/Creditor) + Completeness=1
;              This signals "compound watch: hold record, more follows"
;     Frame 2: account pair 1111 (BP_ACCT_COMPOUND) + Completeness=0
;              This is the continuation marker. Both frames are posted atomically.
;   REQUIREMENT: BP_CTX_COMPOUND must be set AND compound_prefix in Layer 2 must
;                be non-zero for pair 1111 to be valid.
;
; Exports: build_ledger
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    extern layer1_build
    extern layer2_build
    extern layer3_build
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

    global build_ledger

section .bss
    ledger_buf  resb BP_OUTBUF_SIZE  ; output buffer for complete BitLedger frame

section .text
default rel

; ─────────────────────────────────────────────────────────────────────────────
; build_ledger
;   Assemble and write a complete BitLedger transmission.
;
; Input:  rdi = pointer to bp_ctx
; Output: rax = 0 on success, -1 on error (also -1 if Layer 3 protocol violation)
; ─────────────────────────────────────────────────────────────────────────────
build_ledger:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14                     ; r14 = ledger_buf base address
    sub     rsp, 16                 ; local spill space, keep 16-byte alignment

    mov     rbx, rdi                ; rbx = bp_ctx pointer
    xor     r12d, r12d              ; r12d = current byte offset into ledger_buf
    lea     r14, [rel ledger_buf]   ; r14 = base address of output buffer

    ; ═══════════════════════════════════════════════════════════════════════
    ; LAYER 1: Session Header (8 bytes, always present)
    ; "Layer 1 is the 64-bit session identification header."
    ; ═══════════════════════════════════════════════════════════════════════
    mov     rdi, rbx
    mov     rsi, r14
    call    layer1_build            ; rax = 8
    add     r12d, eax               ; r12 = 8

    ; ═══════════════════════════════════════════════════════════════════════
    ; LAYER 2: Batch Context Header (6 bytes, conditional)
    ; ═══════════════════════════════════════════════════════════════════════
    cmp     byte [rbx + BP_CTX_LAYER2_PRES], 0
    je      .no_layer2_l

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    layer2_build            ; rax = 6
    add     r12d, eax               ; r12 = 8 + 6 = 14

.no_layer2_l:
    ; ═══════════════════════════════════════════════════════════════════════
    ; LAYER 3: BitLedger Record (5 bytes)
    ;
    ; This is what distinguishes a Ledger frame from a plain Record frame.
    ; Carries the double-entry routing: account pair, direction, completeness.
    ;
    ; COMPOUND PROTOCOL CHECK (enforced inside layer3_build):
    ;   If account pair = 0x0F (1111) and compound mode is OFF → returns -1.
    ;   The 1111 pair is ONLY valid as a compound continuation marker.
    ;   "When compound mode = OFF: 1111 is ALWAYS a protocol error." (§3)
    ; ═══════════════════════════════════════════════════════════════════════
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    layer3_build            ; rax = 5 on success, -1 on protocol error

    cmp     rax, 0
    jl      .proto_error            ; Layer 3 rejected the frame → abort

    add     r12d, eax               ; r12 = 14 + 5 = 19 (or 8+5=13 without L2)

    ; ═══════════════════════════════════════════════════════════════════════
    ; META BYTE 1 (Record mode, bit7=1)
    ; ═══════════════════════════════════════════════════════════════════════
    mov     rdi, rbx
    call    meta1_build
    mov     byte [r14 + r12], al
    inc     r12d
    mov     r13b, al                ; r13b = Meta Byte 1

    ; ═══════════════════════════════════════════════════════════════════════
    ; META BYTE 2
    ; ═══════════════════════════════════════════════════════════════════════
    mov     rdi, rbx
    call    meta2_build
    mov     byte [r14 + r12], al
    inc     r12d
    mov     byte [rsp], al          ; spill Meta Byte 2

    ; ── Signal Slot Presence Byte ──────────────────────────────────────────
    test    byte [rsp], BPv2_META2_SLOTS
    jz      .no_ssp_l

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    signals_build_ssp
    add     r12d, eax

.no_ssp_l:
    ; ── P4 pre-value signal ────────────────────────────────────────────────
    test    byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P4
    jz      .no_p4_l
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    mov     edx, BP_SLOT_P4
    call    signals_emit_slot
    add     r12d, eax
.no_p4_l:

    ; ── Setup Byte ─────────────────────────────────────────────────────────
    test    byte [rsp], BPv2_META2_SETUP
    jz      .no_setup_l

    mov     rdi, rbx
    call    setup_build
    mov     byte [r14 + r12], al
    inc     r12d

.no_setup_l:
    ; ── Value Block ────────────────────────────────────────────────────────
    test    r13b, BPv2_META1_ROLC_VAL
    jz      .no_value_l

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    value_encode
    add     r12d, eax

.no_value_l:
    ; ── P5 post-value signal ───────────────────────────────────────────────
    test    byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P5
    jz      .no_p5_l
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    mov     edx, BP_SLOT_P5
    call    signals_emit_slot
    add     r12d, eax
.no_p5_l:

    ; ── Time Field ─────────────────────────────────────────────────────────
    test    r13b, BPv2_META1_ROLC_TIME
    jz      .no_time_l

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    time_build
    add     r12d, eax

.no_time_l:
    ; ── P6 post-time signal ────────────────────────────────────────────────
    test    byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P6
    jz      .no_p6_l
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    mov     edx, BP_SLOT_P6
    call    signals_emit_slot
    add     r12d, eax
.no_p6_l:

    ; ── Task Block ─────────────────────────────────────────────────────────
    test    r13b, BPv2_META1_ROLC_TASK
    jz      .no_task_l

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    task_build
    add     r12d, eax

.no_task_l:
    ; ── P7 post-task signal ────────────────────────────────────────────────
    test    byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P7
    jz      .no_p7_l
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    mov     edx, BP_SLOT_P7
    call    signals_emit_slot
    add     r12d, eax
.no_p7_l:

    ; ── Note Block ─────────────────────────────────────────────────────────
    test    r13b, BPv2_META1_ROLC_NOTE
    jz      .no_note_l

    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    call    note_build
    add     r12d, eax

.no_note_l:
    ; ── P8 post-record signal ──────────────────────────────────────────────
    test    byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P8
    jz      .no_p8_l
    mov     rdi, rbx
    lea     rsi, [r14 + r12]
    mov     edx, BP_SLOT_P8
    call    signals_emit_slot
    add     r12d, eax
.no_p8_l:
    mov     edx, r12d
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_DRYRUN
    je      .success
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_HEX
    je      .stdout_raw
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_HEX_RAW
    je      .stdout_raw

    ; ═══════════════════════════════════════════════════════════════════════
    ; Write completed BitLedger frame to output file
    ; ═══════════════════════════════════════════════════════════════════════
    lea     rdi, [rbx + BP_CTX_OUTFILE]
    mov     rsi, r14
    mov     edx, r12d
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

.proto_error:
    ; Layer 3 detected a protocol violation (e.g. 1111 without compound mode)
    ; Error message was already printed to stderr by layer3_build.
    mov     eax, -1
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
