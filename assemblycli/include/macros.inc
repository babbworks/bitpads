; ─────────────────────────────────────────────────────────────────────────────
; macros.inc — NASM utility macros for the BitPads assembler
;
; All macros expand inline at each use site — there is no call/ret overhead.
; Include this file after syscall.inc and bitpads.inc so their constants are
; available inside macro bodies.
;
; Guard against double-inclusion: the %ifndef block at the top ensures this
; file is processed only once even if %include'd by multiple translation units.
; ─────────────────────────────────────────────────────────────────────────────

%ifndef MACROS_INC
%define MACROS_INC

; ─────────────────────────────────────────────────────────────────────────────
; SAVE_REGS / RESTORE_REGS
;
; Save and restore every callee-saved register in a function prologue/epilogue.
;
; System V AMD64 ABI: rbx, rbp, r12, r13, r14, r15 are callee-saved.
; The caller expects all six registers to hold their original values after
; the function returns, so every leaf or non-leaf function that uses them must
; spill them to the stack on entry and reload on exit.
;
; SAVE_REGS additionally establishes a standard stack frame (rbp = rsp after
; saving rbp) so that debuggers and stack-unwinders (DWARF, lldb) can walk
; the call chain correctly.
;
; Stack alignment:
;   The System V AMD64 ABI requires rsp to be 16-byte aligned immediately
;   BEFORE a call instruction.  On function entry rsp is already 8-byte
;   aligned (the call pushed an 8-byte return address).  Each push is 8 bytes,
;   so after 5 pushes (rbp + rbx + r12 + r13 + r14) we have pushed 48 bytes
;   (return address + 6 pushes = 56 bytes total from original rsp), and then
;   r15 makes it 64 bytes — which restores 16-byte alignment.  The final
;   `and rsp, -16` guarantees alignment even if the call site deviated.
;
; Usage:
;   my_function:
;       SAVE_REGS
;       ; ... function body using rbx, r12-r15 freely ...
;       RESTORE_REGS
;       ret
; ─────────────────────────────────────────────────────────────────────────────
%macro SAVE_REGS 0
    push    rbp
    mov     rbp, rsp        ; establish frame pointer — debuggers use this to unwind the stack
    push    rbx             ; callee-saved: general-purpose base register
    push    r12             ; callee-saved: general-purpose extended register
    push    r13             ; callee-saved: general-purpose extended register
    push    r14             ; callee-saved: general-purpose extended register
    push    r15             ; callee-saved: general-purpose extended register
    and     rsp, -16        ; align stack to 16-byte boundary (required before any `call` instruction)
%endmacro

%macro RESTORE_REGS 0
    ; rbp was set to rsp AFTER push rbp (before the other 5 pushes), so:
    ;   [rbp]     = saved old rbp
    ;   [rbp- 8]  = saved rbx
    ;   [rbp-16]  = saved r12
    ;   [rbp-24]  = saved r13
    ;   [rbp-32]  = saved r14
    ;   [rbp-40]  = saved r15
    ; Point rsp at saved r15 first, then pop in reverse push order.
    lea     rsp, [rbp - 40] ; skip alignment padding; land at saved r15
    pop     r15             ; restore in reverse push order
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp             ; restore frame pointer; rsp now points at the saved return address
%endmacro

; ─────────────────────────────────────────────────────────────────────────────
; SET_BIT reg, mask
;
; Set one or more bits in a register using a bitmask.  Expands to a single
; OR instruction.  Does not modify any other bits in the register.
;
; Parameters:
;   %1  — destination register (any size: al, ax, eax, rax, etc.)
;   %2  — bitmask immediate or register of matching size
;
; Example:
;   SET_BIT al, BPv2_META1_MODE      ; sets bit 7 of al (protocol bit 1, Wave/Record mode)
;   SET_BIT al, BPv2_META1_ACK_SYSCTX | BPv2_META1_CONT  ; set two bits at once
; ─────────────────────────────────────────────────────────────────────────────
%macro SET_BIT 2
    or      %1, %2
%endmacro

; ─────────────────────────────────────────────────────────────────────────────
; CLEAR_BIT reg, mask
;
; Clear one or more bits in a register using the bitwise complement of a mask.
; Expands to a single AND instruction with the inverted mask.
; Does not modify any bits not covered by the mask.
;
; Parameters:
;   %1  — destination register
;   %2  — bitmask immediate (NASM evaluates ~(mask) at assembly time)
;
; Example:
;   CLEAR_BIT al, BPv2_META1_MODE    ; clears bit 7 of al (forces Wave mode)
;   CLEAR_BIT al, BPv2_META1_BITS5_8 ; clears bits 5-8 before writing category
; ─────────────────────────────────────────────────────────────────────────────
%macro CLEAR_BIT 2
    and     %1, ~(%2)
%endmacro

; ─────────────────────────────────────────────────────────────────────────────
; TEST_CTX_FLAG ctx_reg, offset, label
;
; Test a single-byte boolean flag stored in a bp_ctx structure field.
; If the byte at [ctx_reg + offset] is non-zero (flag is set), jump to label.
; Uses CMP + JNZ so it does not modify any register or the flag field itself.
;
; Parameters:
;   %1  — register holding pointer to bp_ctx (typically rdi)
;   %2  — byte offset of the flag field (BP_CTX_* constant from bitpads.inc)
;   %3  — label to jump to when the flag is set (non-zero)
;
; Example:
;   TEST_CTX_FLAG rdi, BP_CTX_ACK_REQ, .set_ack_bit
;   TEST_CTX_FLAG rdi, BP_CTX_VALUE_PRES, .encode_value
; ─────────────────────────────────────────────────────────────────────────────
%macro TEST_CTX_FLAG 3
    cmp     byte [%1 + %2], 0   ; compare flag byte against zero
    jnz     %3                  ; jump to %3 if flag is set (non-zero = true)
%endmacro

; ─────────────────────────────────────────────────────────────────────────────
; WRITE_BYTE buf_reg, byte_val, len_reg
;
; Write a single byte to an output buffer, advance the buffer write pointer,
; and increment the bytes-written counter.  Expands to three instructions.
;
; Parameters:
;   %1  — register holding the current write pointer into the output buffer
;          (will be incremented by 1 after the write)
;   %2  — the byte value to write: an 8-bit immediate constant, or a byte
;          register such as al, bl, cl, dl, r8b, etc.
;   %3  — register holding the running count of bytes written
;          (will be incremented by 1 after the write)
;
; Note: buf_reg and len_reg must be 64-bit registers (rXX) on x86-64 because
; INC on a memory pointer uses the 64-bit form.  byte_val must fit in 8 bits.
;
; Example:
;   WRITE_BYTE r12, al, r13      ; write al to [r12], r12++, r13++
;   WRITE_BYTE rbx, BPv2_L1_SOH, rcx  ; write the SOH constant byte, advance both
; ─────────────────────────────────────────────────────────────────────────────
%macro WRITE_BYTE 3
    mov     byte [%1], %2       ; store the byte at the current buffer write position
    inc     %1                  ; advance write pointer to next byte slot
    inc     %3                  ; increment bytes-written counter
%endmacro

; ─────────────────────────────────────────────────────────────────────────────
; ALIGN_STACK / UNALIGN_STACK
;
; Temporarily adjust rsp to maintain the 16-byte stack alignment that the
; System V AMD64 ABI requires immediately before any `call` instruction.
;
; When to use:
;   After SAVE_REGS the stack is 16-byte aligned.  If any additional pushes,
;   local variable space, or odd-numbered register saves have shifted rsp by
;   a non-16-byte-aligned amount, call ALIGN_STACK to re-align before a call,
;   then UNALIGN_STACK to release the padding afterward.
;
; Implementation note:
;   Subtracts 8 from rsp (reserves one 8-byte slot).  Because a `call`
;   instruction will push another 8 bytes, the combined adjustment of 16 bytes
;   maintains alignment.  Always pair ALIGN_STACK with UNALIGN_STACK to avoid
;   corrupting the stack.
;
; Example:
;   ALIGN_STACK
;   call    some_c_function
;   UNALIGN_STACK
; ─────────────────────────────────────────────────────────────────────────────
%macro ALIGN_STACK 0
    sub     rsp, 8          ; reserve 8 bytes so that rsp+8 (after call pushes return addr) = 16-byte aligned
%endmacro

%macro UNALIGN_STACK 0
    add     rsp, 8          ; release the 8-byte alignment padding reserved by ALIGN_STACK
%endmacro

%endif ; MACROS_INC
