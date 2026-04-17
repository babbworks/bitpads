; ═══════════════════════════════════════════════════════════════════════════════
; time_comp.asm — Time Field Encoder
;
; Reference: BitPads Protocol v2 §7 — Time System, Two-Tier Architecture
;
; The Time System uses two tiers to handle everything from the common case
; (a single byte session offset) to complex temporal requirements (task deadlines,
; validity windows, deep-space light-travel-time expiry).
;
; The tier is declared in Meta Byte 2 bits 5-6:
;   00 = No timestamp (this function returns 0, no bytes written)
;   01 = Tier 1, session offset — 8-bit unsigned integer, offset from session open
;   10 = Tier 1, external reference — 8-bit offset from declared mission epoch
;   11 = Tier 2 Time Block — variable length, full temporal specification
;
; TIER 1 (1 byte):
;   A pure 8-bit unsigned integer. Unit is defined by the session profile
;   (seconds, minutes, hours, 10ms ticks — declared at session open).
;   Range: 0-255 units from the reference point.
;   "Most common. Assumed when Meta byte 2 bits5-6 = 01."
;
; TIER 2 (variable, 2+ bytes):
;   Header byte declares which temporal fields are present:
;     bit 1: Record timestamp (when this record occurred)
;     bit 2: Task execution time (when declared Task should be performed)
;     bit 3: Task duration (task window end or duration)
;     bit 4: Validity/expiry (after this time, discard as stale)
;     bit 5: Quality (0=estimated, 1=verified/synced)
;     bits 6-7: Shared unit (00=ms, 01=seconds, 10=minutes, 11=next byte)
;     bit 8: Mixed references (0=all same reference, 1=per-field selectors)
;   Followed by: reference byte, then time values for each declared field.
;
; Exports: time_build
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global time_build

section .text

; ─────────────────────────────────────────────────────────────────────────────
; time_build
;   Encode the time field into the output buffer based on bp_ctx.
;
; Input:  rdi = pointer to bp_ctx
;         rsi = pointer to output buffer
; Output: rax = bytes written (0 = no time, 1 = Tier 1, 2+ = Tier 2)
; ─────────────────────────────────────────────────────────────────────────────
time_build:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     rbx, rdi                ; rbx = bp_ctx pointer
    mov     r12, rsi                ; r12 = output buffer pointer

    ; Load the time tier selection from ctx
    movzx   ecx, byte [rbx + BP_CTX_TIME_TIER]  ; ecx = time tier (0-3)

    ; Dispatch based on tier
    test    cl, cl                              ; is tier 0 (no timestamp)?
    jz      .no_time                            ; yes → return 0 immediately

    cmp     cl, 1                               ; Tier 1 session offset?
    je      .tier1

    cmp     cl, 2                               ; Tier 1 external reference?
    je      .tier1                              ; same 1-byte encoding, reference declared by Meta2

    cmp     cl, 3                               ; Tier 2 Time Block?
    je      .tier2

    ; Unknown tier — treat as no time
.no_time:
    xor     eax, eax                ; return 0 (no bytes written)
    jmp     .done

    ; ═══════════════════════════════════════════════════════════════════════
    ; TIER 1: Write a single 8-bit time value
    ; The value is the session-relative or epoch-relative offset in session units.
    ; "8-bit offset from session open. Most common."
    ; ═══════════════════════════════════════════════════════════════════════
.tier1:
    movzx   eax, byte [rbx + BP_CTX_TIME_VAL]   ; eax = 8-bit time value (0-255)
    mov     byte [r12], al                       ; write the time byte to output buffer
                                                ; e.g. 23 = 23 seconds after session open
    mov     rax, 1                              ; return 1 byte written
    jmp     .done

    ; ═══════════════════════════════════════════════════════════════════════
    ; TIER 2: Write a 2-byte minimal Tier 2 Time Block
    ; We emit a simple Tier 2 block with only the record timestamp field
    ; active, using seconds as the unit, session reference.
    ;
    ; Tier 2 Header byte encoding (what we emit):
    ;   bit 1 = 1 (record timestamp present)
    ;   bit 2 = 0 (no task execution time)
    ;   bit 3 = 0 (no task duration)
    ;   bit 4 = 0 (no validity/expiry)
    ;   bit 5 = 1 (quality = verified)
    ;   bits 6-7 = 01 (unit = seconds)
    ;   bit 8 = 0 (all fields share same reference)
    ;   → header = 1000 0001b rearranged per bit numbering...
    ;   bit1(MSB)=1: timestamp, bit5=1: verified, bits6-7=01: seconds
    ;   = 1000 0110b = 0x86? Let me compute:
    ;   bit7(prot bit1)=1 → 0x80
    ;   bit2(prot bit5)=1 → quality verified → 0x04...
    ;   Actually protocol bits 1-8 map to x86 bits 7-0:
    ;   prot bit1=bit7=0x80: record timestamp
    ;   prot bit5=bit3=0x08: quality verified
    ;   prot bits6-7=bits2-1=0x06: unit=01=seconds → 0x02
    ;   header = 0x80 | 0x08 | 0x02 = 0x8A
    ; ═══════════════════════════════════════════════════════════════════════
.tier2:
    ; Strict compact Tier2 form for this CLI: 16-bit value big-endian
    movzx   eax, word [rbx + BP_CTX_TIME_EXT]
    mov     ecx, eax
    shr     ecx, 8
    mov     byte [r12 + 0], cl
    mov     byte [r12 + 1], al
    mov     rax, 2

.done:
    pop     r12
    pop     rbx
    pop     rbp
    ret
