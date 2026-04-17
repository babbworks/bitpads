; ═══════════════════════════════════════════════════════════════════════════════
; build_signal.asm — Pure Signal Frame Builder
;
; Reference: BitPads Protocol v2 §1 (Pure Signal / Minimal Transmission)
;
; A Pure Signal is the smallest possible BitPads transmission: 1 byte.
; It carries no record body, no Layer 2, no Layer 3 — just a single enhanced
; C0 byte. The entire semantic content is packed into 8 bits:
;
;   bit 1 (0x80): Priority flag   — elevate urgency of this signal
;   bit 2 (0x40): ACK Request     — receiver must confirm receipt
;   bit 3 (0x20): Continuation    — another signal byte follows (multi-byte signal)
;   bits 4-8 (0x1F): C0 identity  — which C0 signal this is (NUL, SOH, BEL, etc.)
;
; USE CASES:
;   - SOH signal (C0_SOH=1): session open / bootstrap handshake
;   - EOT signal (C0_EOT=4): orderly session close
;   - BEL signal (C0_BEL=7): alert / attention request
;   - SYN signal (C0_SYN=22): heartbeat / keepalive
;   - CAN signal (C0_CAN=24): abort current transmission
;
; OUTPUT:
;   A single byte written to the output buffer.
;   Total transmission size: 1 byte.
;
; Exports: build_signal
; Requires: c0gram_encode (extern), fileio_write (extern), hexdump_write_trace (extern)
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    extern c0gram_encode
    extern fileio_write
    extern fileio_write_stdout
    extern hexdump_write_trace

    global build_signal

section .bss
    signal_buf  resb 4          ; output buffer (1 byte signal + 3 byte safety margin)

section .text
default rel

; ─────────────────────────────────────────────────────────────────────────────
; build_signal
;   Build and write a 1-byte Pure Signal transmission.
;
; Input:  rdi = pointer to bp_ctx
; Output: rax = 0 on success, -1 on write error
; ─────────────────────────────────────────────────────────────────────────────
build_signal:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    sub     rsp, 8                  ; align stack to 16 bytes

    mov     rbx, rdi                ; rbx = bp_ctx pointer

    ; ═══════════════════════════════════════════════════════════════════════
    ; Build the signal byte using the C0 grammar encoder.
    ;
    ; We need:
    ;   C0 identity = the specific C0 code to transmit
    ;   flags       = PRIO, ACK, CONT derived from ctx fields
    ;
    ; BP_CTX_CATEGORY holds the C0 code identity (reused field; signal mode
    ; uses the lower 5 bits of category as the C0 identity).
    ; BP_CTX_PRIO     holds the priority flag (1 = set Priority bit).
    ; BP_CTX_ACK_REQ  holds the ACK request flag.
    ; ═══════════════════════════════════════════════════════════════════════

    ; Build the flags argument for c0gram_encode
    xor     ecx, ecx                ; ecx = flags accumulator

    ; Priority flag: if BP_CTX_PRIO is set, set bit 2 of flags
    cmp     byte [rbx + BP_CTX_PRIO], 0
    je      .no_prio
    or      cl, 0x04                ; bit 2 = Priority flag
                                    ; "Priority flag — elevate urgency"
.no_prio:
    ; ACK Request flag: if BP_CTX_ACK_REQ is set, set bit 1 of flags
    cmp     byte [rbx + BP_CTX_ACK_REQ], 0
    je      .no_ack
    or      cl, 0x02                ; bit 1 = ACK Request flag
                                    ; "ACK Request — receiver must confirm"
.no_ack:
    ; Continuation flag: never set for a pure signal (single byte)
    ; (If continuation were needed, caller would build a multi-byte signal manually)

    ; Load C0 code identity from ctx (lower 5 bits of BP_CTX_CATEGORY)
    movzx   edi, byte [rbx + BP_CTX_CATEGORY]  ; edi = C0 code identity (0-31)
    movzx   esi, cl                              ; esi = flags byte

    call    c0gram_encode           ; al = encoded signal byte
                                    ; e.g. C0_SOH + Priority = 0x01 | 0x80 = 0x81

    ; Write the single encoded byte to the output buffer
    mov     byte [signal_buf], al   ; store signal byte in local buffer

    ; ═══════════════════════════════════════════════════════════════════════
    ; Write the output file
    ; fileio_write(rdi=filename, rsi=buffer, rdx=length)
    ; ═══════════════════════════════════════════════════════════════════════
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_DRYRUN
    je      .success
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_HEX
    je      .stdout_raw
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_HEX_RAW
    je      .stdout_raw

    lea     rdi, [rbx + BP_CTX_OUTFILE]  ; rdi = output filename from ctx
    lea     rsi, [signal_buf]            ; rsi = signal byte buffer
    mov     rdx, 1                       ; rdx = 1 byte to write
    call    fileio_write                 ; write the 1-byte signal transmission
                                         ; rax = 0 on success, -1 on error

    cmp     rax, 0
    jl      .error                       ; write failed → return -1

    ; ═══════════════════════════════════════════════════════════════════════
    ; Optional hex trace dump (if BP_CTX_HEX_TRACE is set)
    ; Writes a human-readable annotation file showing the byte breakdown.
    ; ═══════════════════════════════════════════════════════════════════════
    cmp     byte [rbx + BP_CTX_HEX_TRACE], 0
    je      .success

    lea     rdi, [rbx + BP_CTX_OUTFILE]  ; rdi = output filename (trace appends .trace)
    lea     rsi, [signal_buf]            ; rsi = buffer
    mov     rdx, 1                       ; rdx = byte count
    call    hexdump_write_trace          ; write human-readable hex+binary trace file
                                         ; "also write a .trace annotation file"

.success:
    xor     eax, eax                ; rax = 0 (success)
    jmp     .done

.stdout_raw:
    lea     rsi, [signal_buf]
    mov     rdx, 1
    call    fileio_write_stdout
    xor     eax, eax
    jmp     .done

.error:
    mov     eax, -1                 ; rax = -1 (write error)

.done:
    add     rsp, 8
    pop     r12
    pop     rbx
    pop     rbp
    ret
