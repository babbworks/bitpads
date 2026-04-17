; ═══════════════════════════════════════════════════════════════════════════════
; task.asm — Task Block Encoder
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global task_build

section .text

task_build:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     rbx, rdi                ; bp_ctx
    mov     r12, rsi                ; output buffer

    ; Byte 0: Task Short-Form Byte
    movzx   ecx, byte [rbx + BP_CTX_TASK_BYTE]
    mov     byte [r12], cl
    mov     edx, 1                  ; bytes written

    ; Target Entity Byte?
    test    cl, BP_TASK_TARGET
    jz      .no_target
    movzx   eax, byte [rbx + BP_CTX_TASK_BYTE + 1]
    mov     byte [r12 + rdx], al
    inc     edx
.no_target:

    ; Timing Offset Byte?
    movzx   ecx, byte [rbx + BP_CTX_TASK_BYTE]
    test    cl, BP_TASK_TIMING
    jz      .no_timing
    movzx   eax, byte [rbx + BP_CTX_TASK_BYTE + 2]
    mov     byte [r12 + rdx], al
    inc     edx
.no_timing:

    mov     rax, rdx                ; return byte count

    pop     r12
    pop     rbx
    pop     rbp
    ret