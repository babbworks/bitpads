; ═══════════════════════════════════════════════════════════════════════════════
; main.asm — Program Entry Point for BitPads CLI
;
; Linux x86-64 entry point (_start)
;
; Differences from the macOS version:
;   - Entry symbol is _start (no underscore prefix, no runtime wrapper)
;   - argc and argv are read from the stack at process entry, not from registers.
;     The kernel places the stack layout as: [rsp]=argc, [rsp+8]=argv[0], ...
;   - No push rbp / mov rbp, rsp frame setup — _start has no caller return address.
;   - rsp is 16-byte aligned at kernel entry. Two pushes (rbx, r12) keep it aligned
;     before the call instruction pushes the return address.
;   - SYS_EXIT = 60 (Linux native), not 0x2000001 (macOS BSD class).
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    extern cli_parse
    extern dispatch_build

    global _start

section .data

msg_ok      db "bitpads: transmission written successfully", 10
msg_ok_len  equ $ - msg_ok

msg_fail    db "bitpads: transmission failed — check arguments and output path", 10
msg_fail_len equ $ - msg_fail

section .text

; ─────────────────────────────────────────────────────────────────────────────
; _start
;   Linux process entry point — invoked directly by the kernel, not by a
;   runtime.  The kernel guarantees rsp is 16-byte aligned at entry.
;
;   Stack layout at entry (per Linux/AMD64 ABI):
;     [rsp+0]  = argc   (64-bit value)
;     [rsp+8]  = argv[0] pointer
;     [rsp+16] = argv[1] pointer
;     ...
;
; Input:  [rsp] = argc,  [rsp+8] = argv  (read before any pushes)
; Output: exits with appropriate code (0=success, 1=arg error, 2=build error)
; ─────────────────────────────────────────────────────────────────────────────
_start:
    ; Read argc and argv from the stack BEFORE any pushes change rsp.
    mov     rdi, [rsp]          ; rdi ← argc
    lea     rsi, [rsp + 8]      ; rsi ← pointer to argv array (argv[0], argv[1], ...)

    ; Save callee-preserved registers.
    ; Two pushes (16 bytes total) keep rsp 16-byte aligned.
    ; The subsequent call instruction pushes the return address (8 bytes),
    ; leaving rsp mod 16 = 8 on entry to cli_parse — the correct ABI alignment.
    push    rbx
    push    r12

    ; ── Parse command-line arguments ──────────────────────────────────────
    ; cli_parse returns:
    ;   rdi = pointer to populated bp_ctx
    ;   rax = 0 on success, -1 if required args missing
    call    cli_parse

    mov     rbx, rdi                ; rbx = &bp_ctx (preserve across calls)

    test    eax, eax
    jl      .parse_fail             ; rax = -1 → usage already printed

    ; ── Dispatch to correct builder based on --type ───────────────────────
    xor     r12d, r12d
    movzx   r12d, byte [rbx + BP_CTX_COUNT]
    test    r12d, r12d
    jnz     .dispatch_loop
    mov     r12d, 1

.dispatch_loop:
    mov     rdi, rbx
    call    dispatch_build          ; rax = 0 success, -1 on build error

    test    eax, eax
    jl      .build_fail
    dec     r12d
    jnz     .dispatch_loop

    ; ── Success path ──────────────────────────────────────────────────────
    cmp     byte [rbx + BP_CTX_PRINT_SIZE], 0
    jne     .ok_quiet
    mov     rax, SYS_WRITE
    mov     rdi, STDOUT
    lea     rsi, [rel msg_ok]
    mov     rdx, msg_ok_len
    syscall
.ok_quiet:

    xor     edi, edi                ; exit code 0 = success
    jmp     .exit

.parse_fail:
    ; cli_parse already printed usage to stderr
    mov     edi, 1                  ; exit code 1 = argument error
    jmp     .exit

.build_fail:
    ; builder already printed specific error
    mov     rax, SYS_WRITE
    mov     rdi, STDERR
    lea     rsi, [rel msg_fail]
    mov     rdx, msg_fail_len
    syscall

    mov     edi, 2                  ; exit code 2 = build/protocol error

.exit:
    ; ── Exit the process cleanly ──────────────────────────────────────────
    ; On Linux _start there is no caller to return to. SYS_EXIT terminates
    ; the process directly. Execution never reaches the instruction after syscall.
    mov     rax, SYS_EXIT
    syscall                         ; kernel exit — never returns
