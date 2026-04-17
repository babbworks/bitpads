; ═══════════════════════════════════════════════════════════════════════════════
; c0gram.asm — C0 Enhancement Grammar Builder (Safe register version)
;
; Reference: BitPads Enhancement Sub-Protocol §4–5
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global c0gram_encode
    global c0gram_decode
    global c0gram_build_slot

section .text

; ─────────────────────────────────────────────────────────────────────────────
; c0gram_encode
; ─────────────────────────────────────────────────────────────────────────────
c0gram_encode:
    movzx   eax, dil                ; C0 code (5 bits)
    and     al, C0_CODE_MASK

    movzx   ecx, sil                ; flags
    and     cl, 0x07
    shl     cl, 5
    or      al, cl
    ret

; ─────────────────────────────────────────────────────────────────────────────
; c0gram_decode
; ─────────────────────────────────────────────────────────────────────────────
c0gram_decode:
    movzx   eax, dil                ; full byte

    mov     ah, al                  ; save full byte
    and     al, C0_CODE_MASK        ; extract C0 code

    shr     ah, 5                   ; extract flags into ah (bits 2-0)
    ret

; ─────────────────────────────────────────────────────────────────────────────
; c0gram_build_slot
; ─────────────────────────────────────────────────────────────────────────────
c0gram_build_slot:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    mov     rbx, rdi                ; source signal bytes
    mov     r12, rsi                ; output buffer
    mov     r13d, edx               ; number of bytes

    ; Clamp to 1-3 bytes
    test    r13d, r13d
    jz      .done_zero
    cmp     r13d, 3
    jle     .count_ok
    mov     r13d, 3
.count_ok:

    xor     ecx, ecx                ; loop index

.slot_loop:
    cmp     ecx, r13d
    jge     .done

    movzx   eax, byte [rbx + rcx]   ; load pre-assembled byte

    ; Enforce CONT flag
    lea     edx, [r13d - 1]
    cmp     ecx, edx
    je      .last_byte

    or      al, C0_FLAG_CONT        ; not last → set CONT
    jmp     .write

.last_byte:
    and     al, ~C0_FLAG_CONT       ; last → clear CONT

.write:
    mov     byte [r12 + rcx], al
    inc     ecx
    jmp     .slot_loop

.done:
    mov     rax, r13
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.done_zero:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret