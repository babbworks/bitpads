; ═══════════════════════════════════════════════════════════════════════════════
; value.asm — Value Block Encoder
;
; Reference: BitPads Protocol v2 §6.1–6.3
;
; The Value Block encodes any conserved scalar quantity as a whole integer N.
; The real-world value is recovered by the receiver using:
;
;   Real_Value = (N × Scaling_Factor) / 10^DecimalPosition
;
; Example: N=124750, SF=x1, D=2 → Real Value = 124750 / 100 = $1,247.50
;
; The integer N is packed into 1, 2, 3, or 4 bytes in BIG-ENDIAN (MSB first)
; order. This is network byte order — the protocol is a transmission format
; and always sends the most significant byte first.
;
; The four tiers and their byte sizes:
;   Tier 1: 1 byte  — N max 255          (status codes, tiny sensor values)
;   Tier 2: 2 bytes — N max 65,535       (small measurements)
;   Tier 3: 3 bytes — N max 16,777,215   (DEFAULT — general purpose)
;   Tier 4: 4 bytes — N max 4,294,967,295 (large assets, high-volume)
;
; At Tier 3, SF=x1B (billion), D=2:  max value = $167 trillion — in 3 bytes.
;
; Exports: value_encode
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global value_encode

section .text

; ─────────────────────────────────────────────────────────────────────────────
; value_encode
;   Encode integer N from bp_ctx into the output buffer, MSB-first.
;
; Input:  rdi = pointer to bp_ctx
;         rsi = pointer to output buffer (1-4 bytes required)
; Output: rax = bytes written (1, 2, 3, or 4)
; ─────────────────────────────────────────────────────────────────────────────
value_encode:
    push    rbp
    mov     rbp, rsp
    push    rbx                     ; rbx = bp_ctx pointer
    push    r12                     ; r12 = output buffer pointer
    push    r13                     ; r13 = integer N (32-bit value from ctx)

    mov     rbx, rdi                ; save bp_ctx
    mov     r12, rsi                ; save output buffer

    ; Load integer N from bp_ctx (stored as 32-bit little-endian dword in ctx)
    mov     r13d, dword [rbx + BP_CTX_VALUE]     ; r13d = N (e.g. 124750 = 0x0001E76E)
                                                ; The CPU stores this LE, but we transmit BE

    ; Load the value tier to determine how many bytes to encode
    movzx   ecx, byte [rbx + BP_CTX_VALUE_TIER]  ; ecx = tier (0=T1, 1=T2, 2=T3, 3=T4)

    ; Dispatch to the appropriate tier encoder
    cmp     cl, 0                                ; Tier 1?
    je      .tier1
    cmp     cl, 1                                ; Tier 2?
    je      .tier2
    cmp     cl, 3                                ; Tier 4?
    je      .tier4
    ; Fall through to Tier 3 (default)

    ; ═══════════════════════════════════════════════════════════════════════
    ; TIER 3: 3 bytes, N max = 16,777,215 (0xFFFFFF)
    ; This is the default and most common case.
    ; Byte order: [N>>16 & 0xFF] [N>>8 & 0xFF] [N & 0xFF]
    ; ═══════════════════════════════════════════════════════════════════════
.tier3:
    mov     eax, r13d               ; eax = N
    shr     eax, 16                 ; eax = N >> 16 = most significant byte
    and     al, 0xFF                ; mask to 8 bits (safety, shr already handles)
    mov     byte [r12 + 0], al      ; byte[0] = most significant byte (protocol bit position = MSB)
                                   ; "MSB-first encoding — network byte order"

    mov     eax, r13d               ; reload N
    shr     eax, 8                  ; eax = N >> 8 = middle byte
    and     al, 0xFF
    mov     byte [r12 + 1], al      ; byte[1] = middle byte

    mov     eax, r13d               ; reload N
    and     al, 0xFF                ; eax = N & 0xFF = least significant byte
    mov     byte [r12 + 2], al      ; byte[2] = least significant byte (LSB)
                                   ; e.g. N=124750=0x01E76E: writes 0x01, 0xE7, 0x6E

    mov     rax, BP_TIER3_BYTES     ; return 3 bytes written
    jmp     .done

    ; ═══════════════════════════════════════════════════════════════════════
    ; TIER 1: 1 byte, N max = 255
    ; Single-byte encoding — no shift needed, just take the low 8 bits of N.
    ; Used for: status codes, 8-bit IoT sensor readings, counts 0-255.
    ; ═══════════════════════════════════════════════════════════════════════
.tier1:
    mov     eax, r13d               ; eax = N
    and     al, 0xFF                ; mask to 8 bits (N must be 0-255 for Tier 1)
    mov     byte [r12 + 0], al      ; write the single byte
                                   ; "Status codes, counts, deep space IoT — every byte counts"

    mov     rax, BP_TIER1_BYTES     ; return 1 byte written
    jmp     .done

    ; ═══════════════════════════════════════════════════════════════════════
    ; TIER 2: 2 bytes, N max = 65,535
    ; Big-endian 16-bit: [N>>8] [N & 0xFF]
    ; ═══════════════════════════════════════════════════════════════════════
.tier2:
    mov     eax, r13d               ; eax = N
    shr     eax, 8                  ; eax = high byte
    and     al, 0xFF
    mov     byte [r12 + 0], al      ; byte[0] = high byte (MSB)

    mov     eax, r13d               ; reload N
    and     al, 0xFF
    mov     byte [r12 + 1], al      ; byte[1] = low byte (LSB)
                                   ; e.g. N=1000=0x03E8: writes 0x03, 0xE8

    mov     rax, BP_TIER2_BYTES     ; return 2 bytes written
    jmp     .done

    ; ═══════════════════════════════════════════════════════════════════════
    ; TIER 4: 4 bytes, N max = 4,294,967,295
    ; Big-endian 32-bit: [N>>24] [N>>16] [N>>8] [N & 0xFF]
    ; Used for: large asset values, high-volume physical quantities.
    ; ═══════════════════════════════════════════════════════════════════════
.tier4:
    mov     eax, r13d               ; eax = N (full 32 bits)

    ; Store byte 0: most significant byte
    mov     ecx, eax
    shr     ecx, 24                 ; ecx = bits 31-24 (most significant byte)
    mov     byte [r12 + 0], cl      ; byte[0] = N >> 24

    ; Store byte 1
    mov     ecx, eax
    shr     ecx, 16
    and     cl, 0xFF
    mov     byte [r12 + 1], cl      ; byte[1] = (N >> 16) & 0xFF

    ; Store byte 2
    mov     ecx, eax
    shr     ecx, 8
    and     cl, 0xFF
    mov     byte [r12 + 2], cl      ; byte[2] = (N >> 8) & 0xFF

    ; Store byte 3: least significant byte
    and     al, 0xFF
    mov     byte [r12 + 3], al      ; byte[3] = N & 0xFF (LSB)
                                   ; e.g. N=0xDEADBEEF: 0xDE, 0xAD, 0xBE, 0xEF

    mov     rax, BP_TIER4_BYTES     ; return 4 bytes written

.done:
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
