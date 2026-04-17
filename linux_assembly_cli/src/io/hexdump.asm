; ═══════════════════════════════════════════════════════════════════════════════
; hexdump.asm — Annotated Hex Dump Writer
;
; Produces human-readable protocol traces of BitPads binary output.
; Each byte in the output buffer is printed as:
;   0xNN  0xHH  BBBB BBBB\n
; where NN = offset, HH = hex value, BBBB BBBB = binary representation.
;
; Used by the --hex flag to write a .trace companion file alongside every
; saved BitPads binary.
;
; Exports:
;   hexdump_byte_to_hex   — convert byte to 2-char ASCII hex in buffer
;   hexdump_byte_to_bin   — convert byte to "BBBB BBBB" string in buffer
;   hexdump_write_trace   — write full annotated trace file
;
; Dependencies: fileio_write, fileio_write_stdout (extern)
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    extern fileio_write
    extern fileio_write_stdout

    global hexdump_byte_to_hex
    global hexdump_byte_to_bin
    global hexdump_write_trace

section .data

    ; ASCII hex digit lookup table — maps nibble values 0-15 to '0'-'9','A'-'F'
    hex_digits  db "0123456789ABCDEF"

    ; Column header line printed at the top of every trace file
    trace_header    db "OFFSET  HEX   BINARY   ", 10
    trace_header_len equ $ - trace_header

    ; Format: "0x" prefix used before offset and hex values
    prefix_0x   db "0x"

    ; Separator between columns
    col_sep     db "  "

    ; Newline
    newline     db 10

section .bss

    ; 8192-byte scratch buffer for building the trace text before writing
    trace_buf   resb 8192
    trace_buf_used  resq 1          ; how many bytes currently in trace_buf

section .text
default rel

; ─────────────────────────────────────────────────────────────────────────────
; hexdump_byte_to_hex
;   Convert one byte to its two-character uppercase hex ASCII representation
;   and write those chars into the caller's buffer.
;
; Input:  al  = byte value to convert
;         rdi = pointer to output buffer (must have room for 2 bytes)
; Output: rdi = advanced by 2 (points past the two hex chars written)
;         al  = preserved (not clobbered by this function)
;
; Example: al=0xC7 → writes 'C','7' at [rdi], [rdi+1]
; ─────────────────────────────────────────────────────────────────────────────
hexdump_byte_to_hex:
    push    rbx                     ; save rbx — we use it as a scratch for the byte value

    movzx   rbx, al                 ; rbx = zero-extended byte value (e.g. 0xC7 → rbx=199)
                                    ; movzx avoids false dependency on upper bits of rbx

    ; ── Extract HIGH nibble (upper 4 bits) ──
    mov     cl, bl                  ; cl = byte value (copy for manipulation)
    shr     cl, 4                   ; cl = upper nibble (e.g. 0xC7 >> 4 = 0x0C = 12)
                                    ; logical right shift: zeros fill from left
    and     cl, 0x0F                ; mask to 4 bits (shr by 4 already makes this safe, but defensive)
    lea     rdx, [rel hex_digits]   ; rdx = pointer to "0123456789ABCDEF" lookup table
    movzx   rcx, cl                 ; zero-extend cl to 64-bit index for table lookup
    mov     al, byte [rdx + rcx]    ; al = hex_digits[upper_nibble] (e.g. hex_digits[12] = 'C')
    mov     byte [rdi], al          ; write first hex char to output buffer
    inc     rdi                     ; advance output pointer past first char

    ; ── Extract LOW nibble (lower 4 bits) ──
    mov     cl, bl                  ; cl = original byte value again
    and     cl, 0x0F                ; mask to lower nibble (e.g. 0xC7 & 0x0F = 0x07 = 7)
    movzx   rcx, cl                 ; zero-extend for table index
    mov     al, byte [rdx + rcx]    ; al = hex_digits[lower_nibble] (e.g. hex_digits[7] = '7')
    mov     byte [rdi], al          ; write second hex char
    inc     rdi                     ; advance output pointer past second char

    movzx   rax, bl                 ; restore original byte value in rax (for caller convenience)
    pop     rbx                     ; restore callee-saved rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; hexdump_byte_to_bin
;   Convert one byte to its 9-character "BBBB BBBB" binary ASCII representation.
;
; Input:  al  = byte value to convert
;         rdi = pointer to output buffer (must have room for 9 bytes)
; Output: rdi = advanced by 9
;
; Example: al=0xC7 = 1100 0111 → writes "1100 0111"
; ─────────────────────────────────────────────────────────────────────────────
hexdump_byte_to_bin:
    push    rbx
    push    r12

    movzx   rbx, al                 ; rbx = byte value to convert
    mov     r12, 7                  ; r12 = bit counter, start at bit 7 (MSB)
                                    ; protocol bit 1 = x86 bit 7 = MSB = most significant

.bit_loop:
    ; Test bit r12 of rbx and write '1' or '0'
    bt      rbx, r12                ; test bit r12 of rbx; result in CF (carry flag)
                                    ; BT = Bit Test: CF = bit[r12] of rbx
    jc      .write_one              ; if CF=1, this bit is set → write '1'

.write_zero:
    mov     byte [rdi], '0'         ; write ASCII '0' for a clear bit
    jmp     .after_bit_write

.write_one:
    mov     byte [rdi], '1'         ; write ASCII '1' for a set bit

.after_bit_write:
    inc     rdi                     ; advance buffer pointer past the written '0' or '1'
    dec     r12                     ; move to next bit (going from MSB down to LSB)

    ; After writing bit 4 (the 5th bit), insert a space separator
    ; This produces "BBBB BBBB" — 4 bits, space, 4 bits
    cmp     r12, 3                  ; have we just written bit 4 (now r12=3)?
    jne     .check_done             ; no — skip space insertion
    mov     byte [rdi], ' '         ; yes — write the separator space between nibbles
    inc     rdi                     ; advance past the space

.check_done:
    cmp     r12, -1                 ; have we processed all 8 bits (bit 7 down to bit 0)?
                                    ; r12 wraps to -1 (0xFFFFFFFFFFFFFFFF) after bit 0
    jge     .bit_loop               ; not done — process next bit

    pop     r12
    pop     rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; hexdump_write_trace
;   Write a complete annotated hex trace of a BitPads binary buffer to a file.
;
;   Each line format: "0xNN  0xHH  BBBB BBBB\n"
;   where: NN = 2-digit hex offset, HH = hex byte value, BBBB BBBB = binary
;
; Input:  rdi = trace filename pointer (null-terminated, e.g. "out.bp.trace")
;         rsi = data buffer pointer
;         rdx = byte count
; Output: void (file is written; errors are silently ignored)
; ─────────────────────────────────────────────────────────────────────────────
hexdump_write_trace:
    push    rbp
    mov     rbp, rsp
    push    rbx                     ; rbx = data buffer pointer (callee-saved)
    push    r12                     ; r12 = byte count remaining
    push    r13                     ; r13 = current offset (byte index)
    push    r14                     ; r14 = filename pointer
    push    r15                     ; r15 = trace_buf write pointer
    sub     rsp, 8                  ; align stack to 16 bytes

    mov     rbx, rsi                ; rbx = source data buffer
    mov     r12, rdx                ; r12 = total bytes to trace
    xor     r13, r13                ; r13 = offset counter, starts at 0
    mov     r14, rdi                ; r14 = filename to write trace to
    lea     r15, [rel trace_buf]    ; r15 = start of trace build buffer

    ; ── Write header line ──
    lea     rsi, [rel trace_header]
    mov     rcx, trace_header_len
.copy_header:
    mov     al, byte [rsi]
    mov     byte [r15], al
    inc     rsi
    inc     r15
    loop    .copy_header

.byte_loop:
    test    r12, r12                ; are there bytes remaining?
    jz      .done                   ; no — flush and exit

    ; ── Write "0x" prefix for offset ──
    mov     byte [r15], '0'         ; '0' char
    inc     r15
    mov     byte [r15], 'x'         ; 'x' char
    inc     r15

    ; ── Write 2-digit offset hex ──
    mov     al, r13b                ; al = current offset (low byte, max 255 for 256-byte buffer)
    mov     rdi, r15                ; rdi = write position in trace buffer
    call    hexdump_byte_to_hex     ; writes 2 hex chars, advances rdi
    mov     r15, rdi                ; save updated trace buffer position

    ; ── Write "  0x" separator + hex prefix ──
    mov     byte [r15], ' '
    inc     r15
    mov     byte [r15], ' '
    inc     r15
    mov     byte [r15], '0'
    inc     r15
    mov     byte [r15], 'x'
    inc     r15

    ; ── Write 2-digit byte value hex ──
    mov     al, byte [rbx + r13]    ; al = current data byte at offset r13
    mov     rdi, r15
    call    hexdump_byte_to_hex     ; writes 2 hex chars
    mov     r15, rdi

    ; ── Write "  " column separator ──
    mov     byte [r15], ' '
    inc     r15
    mov     byte [r15], ' '
    inc     r15

    ; ── Write 9-char binary representation ──
    mov     al, byte [rbx + r13]    ; reload current data byte
    mov     rdi, r15                ; rdi = write position
    call    hexdump_byte_to_bin     ; writes "BBBB BBBB" = 9 chars
    mov     r15, rdi

    ; ── Write newline ──
    mov     byte [r15], 10          ; LF = newline character (ASCII 10)
    inc     r15

    inc     r13                     ; advance to next byte offset
    dec     r12                     ; one fewer byte remaining
    jmp     .byte_loop

.done:
    ; ── Flush trace_buf to file ──
    lea     rax, [rel trace_buf]    ; rax = start of trace buffer
    sub     r15, rax                ; r15 = total bytes written to trace buffer

    mov     rdi, r14                ; rdi = filename
    lea     rsi, [rel trace_buf]    ; rsi = trace buffer start
    mov     rdx, r15                ; rdx = byte count
    sub     rsp, 8
    call    fileio_write            ; write entire trace to file
    add     rsp, 8

    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
