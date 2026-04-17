; ═══════════════════════════════════════════════════════════════════════════════
; ctx1101.asm — Category 1101: Context Declaration Encoder
;
; Reference: BitPads Enhancement Sub-Protocol §12
;            "Category 1101 — Context Declaration Sub-Protocol"
;
; Category 1101 (BP_CAT_CTX_DECL = 0x0D) is a NEW BitPads v2 category used to
; declare or update session context without carrying a data value. It transmits
; metadata that the receiver uses to correctly interpret subsequent records.
;
; USE CASES:
;   - Declare or change the active currency / unit of measure
;   - Announce sender identity or role change
;   - Broadcast session profile parameters (time unit, scaling defaults)
;   - Set the shared reference epoch for Tier-1 timestamps
;
; CONTEXT DECLARATION FRAME STRUCTURE (after Meta Byte 1 + Meta Byte 2):
;
;   Byte 0: Context Class Byte
;     bits 1-3 (0xE0): Context Class — 8 context categories
;       000 (0x00) = Currency/Unit   — declare the active denomination
;       001 (0x20) = Identity        — declare/update sender entity info
;       010 (0x40) = Time Reference  — set or update epoch anchor
;       011 (0x60) = Session Profile — broadcast session-wide defaults
;       100 (0x80) = Domain Hint     — recommend domain interpretation
;       101-110    = Reserved
;       111 (0xE0) = Extended        — class code in next byte
;     bit 4 (0x10): Acknowledgement Required
;       0 = passive broadcast — receivers update silently
;       1 = receivers must ACK this context update before proceeding
;     bits 5-8 (0x0F): Class-specific sub-code (see per-class notes below)
;
;   Bytes 1..N: Class-specific payload (variable, class-defined)
;
; PER-CLASS SUB-CODES AND PAYLOADS:
;   Currency/Unit (000):
;     sub-code bits 5-8 = currency index (0-15; 0=session default)
;     No payload bytes (sub-code encodes the currency directly)
;
;   Time Reference (010):
;     sub-code bits 5-8 = 0000 (reserved)
;     Payload: 4-byte epoch anchor (UNIX timestamp, big-endian)
;
;   Session Profile (011):
;     sub-code bits 5-8 = profile flags
;     Payload: variable profile bytes (not implemented in v1 CLI)
;
; STORAGE in bp_ctx:
;   BP_CTX_TASK_BYTE    = context class byte (class + ack + sub-code)
;   BP_CTX_TASK_BYTE+1..+4 = optional payload bytes (up to 4)
;
; Exports: ctx1101_build
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global ctx1101_build

; ── Context class codes (upper 3 bits of context byte) ────────────────────────
CTX_CLASS_CURRENCY   equ 0x00   ; 000: currency / unit of measure declaration
CTX_CLASS_IDENTITY   equ 0x20   ; 001: sender identity update
CTX_CLASS_TIMEREF    equ 0x40   ; 010: time reference / epoch anchor
CTX_CLASS_PROFILE    equ 0x60   ; 011: session profile broadcast
CTX_CLASS_DOMAIN     equ 0x80   ; 100: domain interpretation hint
CTX_CLASS_EXTENDED   equ 0xE0   ; 111: extended class code follows

CTX_ACK_REQ          equ 0x10   ; bit 4: acknowledgement required flag

section .text

; ─────────────────────────────────────────────────────────────────────────────
; ctx1101_build
;   Build the Context Declaration payload (class byte + optional payload bytes).
;   Meta bytes are written by the caller before invoking this function.
;
; Input:  rdi = pointer to bp_ctx
;         rsi = pointer to output buffer
; Output: rax = bytes written (1 for currency/identity, 5 for time reference)
; ─────────────────────────────────────────────────────────────────────────────
ctx1101_build:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     rbx, rdi                ; rbx = bp_ctx pointer
    mov     r12, rsi                ; r12 = output buffer pointer

    ; ═══════════════════════════════════════════════════════════════════════
    ; BYTE 0: Context Class Byte
    ;
    ; Pre-assembled by CLI into BP_CTX_TASK_BYTE:
    ;   upper 3 bits = context class (CTX_CLASS_*)
    ;   bit 4        = ACK required flag
    ;   lower 4 bits = class-specific sub-code
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   eax, byte [rbx + BP_CTX_TASK_BYTE]  ; eax = context class byte
    mov     byte [r12 + 0], al                   ; write context class byte

    mov     ecx, 1                  ; ecx = bytes written counter

    ; ═══════════════════════════════════════════════════════════════════════
    ; Dispatch on context class to write optional payload bytes
    ; ═══════════════════════════════════════════════════════════════════════
    movzx   edx, al                 ; edx = class byte for inspection
    and     dl, 0xE0                ; isolate context class (upper 3 bits)

    cmp     dl, CTX_CLASS_CURRENCY  ; Currency/Unit?
    je      .done                   ; sub-code encodes currency inline → no payload bytes

    cmp     dl, CTX_CLASS_IDENTITY  ; Identity?
    je      .done                   ; sub-code encodes entity inline → no payload bytes

    cmp     dl, CTX_CLASS_TIMEREF   ; Time Reference?
    je      .time_ref               ; 4-byte epoch anchor follows

    ; Session Profile, Domain Hint, Extended, Reserved → no payload in this implementation
    jmp     .done

.time_ref:
    ; ═══════════════════════════════════════════════════════════════════════
    ; Time Reference payload: 4-byte big-endian UNIX epoch anchor
    ; Stored little-endian at BP_CTX_TASK_BYTE+1..+4, transmitted big-endian.
    ; "Set or update the epoch anchor for Tier-1 session-relative timestamps"
    ; ═══════════════════════════════════════════════════════════════════════
    mov     eax, dword [rbx + BP_CTX_TASK_BYTE + 1]  ; eax = 32-bit epoch (LE from ctx)
                                                      ; e.g. 0x67A00000 = some UNIX timestamp

    ; Emit in big-endian byte order (MSB first = network byte order)
    mov     edx, eax
    shr     edx, 24                              ; most significant byte
    mov     byte [r12 + 1], dl                   ; write epoch byte 0 (MSB)

    mov     edx, eax
    shr     edx, 16
    and     dl, 0xFF
    mov     byte [r12 + 2], dl                   ; write epoch byte 1

    mov     edx, eax
    shr     edx, 8
    and     dl, 0xFF
    mov     byte [r12 + 3], dl                   ; write epoch byte 2

    and     al, 0xFF
    mov     byte [r12 + 4], al                   ; write epoch byte 3 (LSB)
    add     ecx, 4                               ; 4 payload bytes written

.done:
    mov     eax, ecx                ; rax = total bytes written (mov zero-extends)

    pop     r12
    pop     rbx
    pop     rbp
    ret
