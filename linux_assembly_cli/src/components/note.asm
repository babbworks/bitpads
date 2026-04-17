; ═══════════════════════════════════════════════════════════════════════════════
; note.asm — Note Component Encoder (Safe 8-bit register version)
;
; Reference: BitPads Protocol v2 §8.2
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global note_build

section .text

note_build:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    mov     rbx, rdi                ; rbx = bp_ctx
    mov     r12, rsi                ; r12 = output buffer

    ; Load note length
    mov     r13b, byte [rbx + BP_CTX_NOTE_LEN]

    ; Build header byte
    xor     eax, eax                ; UTF-8 + default language = 0

    cmp     r13b, 14
    ja      .length_overflow

    ; Short length (0-14 bytes)
    or      al, r13b
    mov     byte [r12 + 0], al
    mov     ecx, 1
    jmp     .copy_content

.length_overflow:
    ; Length > 14 → use overflow marker + extra byte
    or      al, 0x0F
    mov     byte [r12 + 0], al
    mov     byte [r12 + 1], r13b
    mov     ecx, 2

.copy_content:
    test    r13b, r13b
    jz      .done

    xor     edx, edx                ; loop counter

.copy_loop:
    cmp     dl, r13b
    jge     .done

    mov     r8b, byte [rbx + BP_CTX_NOTE_DATA + rdx]
    mov     byte [r12 + rcx], r8b
    inc     ecx
    inc     edx
    jmp     .copy_loop

.done:
    mov     rax, rcx                ; return total bytes written

    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret