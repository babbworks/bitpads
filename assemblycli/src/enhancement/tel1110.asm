; ═══════════════════════════════════════════════════════════════════════════════
; tel1110.asm — Category 1110: Telegraph Mode Encoder
;
; Reference: BitPads Enhancement Sub-Protocol §13
;            "Category 1110 — Telegraph Emulation Sub-Protocol"
;
; Category 1110 (BP_CAT_TELEGRAPH = 0x0E) is a NEW BitPads v2 category that
; provides ultra-compact messaging inspired by telegraph conventions. It is
; designed for high-latency or extremely bandwidth-constrained links where
; even the two-byte Wave overhead matters.
;
; TELEGRAPH MODE PHILOSOPHY:
;   Every bit counts. A typical telegraph transmission is 2-4 bytes total
;   (Meta1 + Meta2 + 0-2 payload bytes). No session state overhead, no
;   optional blocks, no enhancement grammar unless pre-negotiated.
;
; TELEGRAPH FRAME STRUCTURE (after Meta Byte 1 + Meta Byte 2):
;
;   Byte 0: Telegraph Header
;     bits 1-3 (0xE0): Message Type
;       000 (0x00) = Status    — single-byte status code (OK/WARN/FAIL/etc.)
;       001 (0x20) = Value     — compact numeric value (1-byte N, no setup overhead)
;       010 (0x40) = Command   — single-byte opcode (no params)
;       011 (0x60) = Identity  — sender/target identity assertion
;       100 (0x80) = Free Text — short human-readable message (1-13 bytes UTF-8)
;       101 (0xA0) = Heartbeat — keepalive / alive signal (no payload)
;       110 (0xC0) = Priority  — urgent priority alert (1-byte priority code)
;       111 (0xE0) = Extended  — message type in next byte
;     bits 4-8 (0x1F): Inline payload (type-specific):
;       Status:    bits 4-8 = 5-bit status code (0=OK, 1=WARN, 2=ERR, 3=CRIT, ...)
;       Heartbeat: bits 4-8 = 5-bit sequence number (wrap-around detection)
;       Free Text: bits 4-8 = length of text in bytes (1-13 byte inline text follows)
;       Value:     bits 4-8 = 5-bit compact value (0-31 — sufficient for many sensor readings)
;       Command:   bits 4-8 = 5-bit opcode
;       Priority:  bits 4-8 = 5-bit priority escalation code
;       Identity:  bits 4-8 = 5-bit sub-entity assertion
;
; STATUS CODES (for Message Type=Status):
;   0  = OK        — normal operation
;   1  = WARN      — warning condition
;   2  = ERR       — error state
;   3  = CRIT      — critical failure
;   4  = OFFLINE   — entity is now offline
;   5  = ONLINE    — entity is coming online
;   6  = BUSY      — temporarily unavailable
;   7  = IDLE      — idle, awaiting tasks
;   8-30 = domain-specific status codes
;   31 = EXTENDED  — full status in following byte
;
; STORAGE in bp_ctx:
;   BP_CTX_TASK_BYTE    = telegraph header byte (type + inline payload)
;   BP_CTX_TASK_BYTE+1  = extended payload byte (for free text or extended types)
;   BP_CTX_NOTE_DATA    = free text content (if type = 100 Free Text)
;   BP_CTX_NOTE_LEN     = free text length
;
; Exports: tel1110_build
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global tel1110_build

; ── Telegraph message type codes ──────────────────────────────────────────────
TEL_TYPE_STATUS      equ 0x00   ; status code transmission
TEL_TYPE_VALUE       equ 0x20   ; compact 5-bit value
TEL_TYPE_COMMAND     equ 0x40   ; single opcode
TEL_TYPE_IDENTITY    equ 0x60   ; identity assertion
TEL_TYPE_FREETEXT    equ 0x80   ; short free-text message
TEL_TYPE_HEARTBEAT   equ 0xA0   ; keepalive signal
TEL_TYPE_PRIORITY    equ 0xC0   ; priority alert
TEL_TYPE_EXTENDED    equ 0xE0   ; message type in next byte

; ── Telegraph status codes (5-bit, inline in header) ─────────────────────────
TEL_STAT_OK          equ 0      ; normal operation
TEL_STAT_WARN        equ 1      ; warning
TEL_STAT_ERR         equ 2      ; error
TEL_STAT_CRIT        equ 3      ; critical
TEL_STAT_OFFLINE     equ 4      ; entity offline
TEL_STAT_ONLINE      equ 5      ; entity online
TEL_STAT_BUSY        equ 6      ; temporarily busy
TEL_STAT_IDLE        equ 7      ; idle/waiting

section .text

; ─────────────────────────────────────────────────────────────────────────────
; tel1110_build
;   Build the Telegraph payload (header byte + optional following bytes).
;   Meta bytes are written by the caller.
;
; Input:  rdi = pointer to bp_ctx
;         rsi = pointer to output buffer
; Output: rax = bytes written (1 for most types, 1+N for free text)
; ─────────────────────────────────────────────────────────────────────────────
tel1110_build:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     rbx, rdi                ; rbx = bp_ctx pointer
    mov     r12, rsi                ; r12 = output buffer pointer

    ; ═══════════════════════════════════════════════════════════════════════
    ; BYTE 0: Telegraph Header Byte
    ;
    ; Pre-assembled by CLI parser into BP_CTX_TASK_BYTE:
    ;   upper 3 bits = message type (TEL_TYPE_*)
    ;   lower 5 bits = inline payload (type-dependent: status code,
    ;                  text length, value, sequence number, etc.)
    ;
    ; "Every bit counts — telegraph packs type + payload into one byte."
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   eax, byte [rbx + BP_CTX_TASK_BYTE]  ; eax = telegraph header byte
    mov     byte [r12 + 0], al                   ; write header to output buffer

    mov     ecx, 1                  ; ecx = bytes written counter

    ; ═══════════════════════════════════════════════════════════════════════
    ; Dispatch on message type to write optional following bytes
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   edx, al                 ; edx = header byte
    and     dl, 0xE0                ; isolate message type field (upper 3 bits)

    cmp     dl, TEL_TYPE_STATUS     ; Status — inline code, no following bytes
    je      .done

    cmp     dl, TEL_TYPE_VALUE      ; Value — 5-bit inline, no following bytes
    je      .done

    cmp     dl, TEL_TYPE_COMMAND    ; Command — 5-bit opcode inline, no following bytes
    je      .done

    cmp     dl, TEL_TYPE_IDENTITY   ; Identity — 5-bit sub-entity inline, no following bytes
    je      .done

    cmp     dl, TEL_TYPE_HEARTBEAT  ; Heartbeat — 5-bit sequence inline, no following bytes
    je      .done

    cmp     dl, TEL_TYPE_PRIORITY   ; Priority — 5-bit priority code inline, no following bytes
    je      .done

    cmp     dl, TEL_TYPE_FREETEXT   ; Free Text — N bytes follow (length in lower 5 bits)
    je      .free_text

    ; TEL_TYPE_EXTENDED — extended type byte follows (1 additional byte)
.extended:
    movzx   eax, byte [rbx + BP_CTX_TASK_BYTE + 1]  ; eax = extended type byte
    mov     byte [r12 + 1], al                        ; write extended type byte
    inc     ecx
    jmp     .done

.free_text:
    ; ═══════════════════════════════════════════════════════════════════════
    ; Free Text payload: N bytes of UTF-8 text inline after header.
    ; The lower 5 bits of the header byte encode text length (1-31 bytes).
    ; For this CLI, actual text is in BP_CTX_NOTE_DATA, length in BP_CTX_NOTE_LEN.
    ;
    ; "Short human-readable message — for 1-13 bytes inline text."
    ; The 5-bit length field supports up to 31 characters in the header,
    ; but real usage typically stays under 13 to fit in 2-byte Waves.
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   r8d, byte [rbx + BP_CTX_NOTE_LEN]  ; r8d = actual text length
    test    r8d, r8d                             ; any text to copy?
    jz      .done

    ; Copy text bytes from NOTE_DATA into output buffer
    xor     edx, edx                ; edx = loop index

.text_loop:
    cmp     edx, r8d                ; copied all text bytes?
    jge     .done

    movzx   eax, byte [rbx + BP_CTX_NOTE_DATA + rdx]  ; eax = text byte
    mov     byte [r12 + rcx], al                        ; write text byte to output
    inc     ecx                                          ; advance output position
    inc     edx                                          ; advance source index
    jmp     .text_loop

.done:
    mov     eax, ecx                ; rax = total bytes written (mov zero-extends)

    pop     r12
    pop     rbx
    pop     rbp
    ret
