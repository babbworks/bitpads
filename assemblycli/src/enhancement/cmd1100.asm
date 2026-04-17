; ═══════════════════════════════════════════════════════════════════════════════
; cmd1100.asm — Category 1100: Compact Command Encoder
; Ultra-safe version for macOS NASM
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global cmd1100_build

; Command class codes
CMD_CLASS_LIFECYCLE  equ 0x00
CMD_CLASS_QUERY      equ 0x10
CMD_CLASS_CONFIGURE  equ 0x20
CMD_CLASS_SYNC       equ 0x30
CMD_CLASS_DIAG       equ 0x40
CMD_CLASS_SECURITY   equ 0x50
CMD_CLASS_TRANSFER   equ 0x60
CMD_CLASS_ROUTE      equ 0x70
CMD_CLASS_EXTENDED   equ 0xF0

; Parameter count codes
CMD_PARAMS_NONE      equ 0x00
CMD_PARAMS_1         equ 0x04
CMD_PARAMS_2         equ 0x08
CMD_PARAMS_VAR       equ 0x0C

; Flags
CMD_RESP_REQ         equ 0x02
CMD_CHAINED          equ 0x01

section .text

cmd1100_build:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     rbx, rdi                ; bp_ctx
    mov     r12, rsi                ; output buffer

    ; BYTE 0: Command Byte
    mov     r8b, byte [rbx + BP_CTX_TASK_BYTE]
    mov     byte [r12], r8b
    mov     ecx, 1

    ; Extract parameter count (bits 5-6)
    mov     r9b, r8b
    and     r9b, 0x0C               ; CMD_PARAMS_VAR mask

    cmp     r9b, CMD_PARAMS_NONE
    je      .done

    cmp     r9b, CMD_PARAMS_1
    je      .one_param

    cmp     r9b, CMD_PARAMS_2
    je      .two_params

    ; Variable params (simple case)
.var_params:
    mov     r8b, byte [rbx + BP_CTX_TASK_BYTE + 1]
    mov     byte [r12 + 1], r8b
    inc     ecx

    test    r8b, r8b
    jz      .done

    mov     r8b, byte [rbx + BP_CTX_TASK_BYTE + 2]
    mov     byte [r12 + rcx], r8b
    inc     ecx
    jmp     .done

.one_param:
    mov     r8b, byte [rbx + BP_CTX_TASK_BYTE + 1]
    mov     byte [r12 + 1], r8b
    inc     ecx
    jmp     .done

.two_params:
    mov     r8b, byte [rbx + BP_CTX_TASK_BYTE + 1]
    mov     byte [r12 + 1], r8b
    mov     r8b, byte [rbx + BP_CTX_TASK_BYTE + 2]
    mov     byte [r12 + 2], r8b
    add     ecx, 2

.done:
    mov     rax, rcx                ; return byte count
    pop     r12
    pop     rbx
    pop     rbp
    ret