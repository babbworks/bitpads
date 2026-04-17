; =============================================================================
; fileio.asm — File I/O using macOS BSD syscalls for BitPads CLI output
;
; All I/O in the BitPads assembler CLI goes through this module.  Every
; function issues raw BSD syscalls via the `syscall` instruction; there is
; no libc dependency.
;
; macOS x86-64 BSD syscall ABI (see syscall.inc for details):
;   rax  = syscall number (SYS_* constant | 0x2000000 BSD class)
;   rdi  = argument 1
;   rsi  = argument 2
;   rdx  = argument 3
;   r10  = argument 4  (NOT rcx — the kernel clobbers rcx and r11)
;   Return value in rax.  On error: carry flag set, rax = errno.
;
; Syscalls used:
;   SYS_OPEN  = 0x2000005  open(path, flags, mode)
;   SYS_WRITE = 0x2000004  write(fd, buf, count) → returns bytes written
;   SYS_CLOSE = 0x2000006  close(fd) → returns 0 on success
;
; Exported symbols:
;   fileio_write          — open/write-all/close a named file
;   fileio_write_stdout   — write buffer to fd 1 (stdout)
;   fileio_write_stderr   — write buffer to fd 2 (stderr)
;
; Calling convention: System V AMD64 (rdi,rsi,rdx,rcx,r8,r9 → rax)
; Assembled with:     nasm -f macho64
; =============================================================================

%include "include/bitpads.inc"   ; bp_ctx constants (not directly used but part of standard includes)
%include "include/syscall.inc"   ; SYS_OPEN, SYS_WRITE, SYS_CLOSE, O_WRONLY, O_CREAT, O_TRUNC, STDOUT, STDERR
%include "include/macros.inc"    ; SAVE_REGS / RESTORE_REGS, SYSCALL macro

section .text

global fileio_write           ; export: write a named file (open + write + close)
global fileio_write_stdout    ; export: write to stdout (fd 1)
global fileio_write_stderr    ; export: write to stderr (fd 2)


; =============================================================================
; fileio_write
;
; Opens (or creates/truncates) a file, writes an exact byte count, then
; closes the descriptor.  This is the primary output path for BitPads binary
; and trace files produced by the CLI tool.
;
; Inputs:
;   rdi = pointer to null-terminated filename string
;   rsi = pointer to data buffer to write
;   rdx = number of bytes to write
;
; Output:
;   rax = 0  on complete success (all bytes written, file closed)
;   rax = -1 on any error (open failed, short write, or close error)
;
; The function does NOT retry partial writes; a short write returns -1.
; For the BitPads CLI tool all output buffers are small (≤ 256 bytes for
; one frame + trace), so a single write() call will always complete on a
; local filesystem.
; =============================================================================
fileio_write:
    SAVE_REGS                       ; save rbp/rbx/r12-r15; align stack (macros.inc)

    ; Save incoming arguments across multiple syscalls.
    ; r12 = filename pointer   (arg1 — needed again only for error reporting)
    ; r13 = data buffer pointer (arg2 — passed to SYS_WRITE)
    ; r14 = byte count          (arg3 — passed to SYS_WRITE)
    mov     r12, rdi                ; r12 ← filename pointer (preserve across syscalls)
    mov     r13, rsi                ; r13 ← data buffer pointer
    mov     r14, rdx                ; r14 ← byte count

    ; -----------------------------------------------------------------
    ; Step 1: open(path, O_WRONLY|O_CREAT|O_TRUNC, 0644)
    ;
    ; SYS_OPEN = 0x2000005
    ; ABI:  rdi = path          (null-terminated filename string)
    ;       rsi = flags         (O_WRONLY | O_CREAT | O_TRUNC)
    ;       rdx = mode          (0644 octal = 0x1A4 = rw-r--r--)
    ; Return: rax = file descriptor (>= 0) on success
    ;         rax = errno, CF=1 on failure
    ; -----------------------------------------------------------------
    mov     rax, SYS_OPEN           ; rax ← syscall number for open() (0x2000005)
    mov     rdi, r12                ; rdi ← filename pointer (arg1: path to open/create)
    mov     rsi, O_WRONLY | O_CREAT | O_TRUNC  ; rsi ← flags: write-only, create if absent, truncate existing
    mov     rdx, 0x1A4              ; rdx ← mode 0644 octal (owner rw, group r, other r)
    SYSCALL                         ; invoke kernel: open(filename, flags, mode)
    jc      .open_error             ; CF set → open() failed (rax = errno); jump to error handler

    ; rax now holds a valid file descriptor.  Save it for the close() call.
    mov     r15, rax                ; r15 ← fd (saved across the write syscall below)

    ; -----------------------------------------------------------------
    ; Step 2: write(fd, buf, count)
    ;
    ; SYS_WRITE = 0x2000004
    ; ABI:  rdi = fd            (file descriptor from open())
    ;       rsi = buf           (pointer to data to write)
    ;       rdx = count         (number of bytes to write)
    ; Return: rax = bytes actually written on success
    ;         rax = errno, CF=1 on failure
    ; -----------------------------------------------------------------
    mov     rax, SYS_WRITE          ; rax ← syscall number for write() (0x2000004)
    mov     rdi, r15                ; rdi ← fd (arg1: the file descriptor we just opened)
    mov     rsi, r13                ; rsi ← data buffer pointer (arg2: source of data)
    mov     rdx, r14                ; rdx ← byte count (arg3: how many bytes to write)
    SYSCALL                         ; invoke kernel: write(fd, buf, count)
    jc      .write_error            ; CF set → write() failed; fall through to close, then return -1

    ; Check for a short write — the kernel wrote fewer bytes than requested.
    ; This should not happen for small local-file writes, but we verify anyway.
    cmp     rax, r14                ; did write() return exactly the requested byte count?
    jne     .write_error            ; no → short write; treat as error (partial file is corrupt)

    ; -----------------------------------------------------------------
    ; Step 3: close(fd)
    ;
    ; SYS_CLOSE = 0x2000006
    ; ABI:  rdi = fd
    ; Return: rax = 0 on success; errno+CF on failure
    ; -----------------------------------------------------------------
    mov     rax, SYS_CLOSE          ; rax ← syscall number for close() (0x2000006)
    mov     rdi, r15                ; rdi ← fd (arg1: descriptor to release)
    SYSCALL                         ; invoke kernel: close(fd)
    jc      .close_error            ; CF set → close() failed (rare, but check anyway)

    ; All three operations succeeded.
    xor     rax, rax                ; rax ← 0 (success return code per function contract)
    RESTORE_REGS                    ; restore callee-saved registers
    ret                             ; return 0 to caller

.write_error:
    ; Write failed or was short.  We still need to close the fd to avoid leaking
    ; it before we return the error code.
    mov     rax, SYS_CLOSE          ; rax ← SYS_CLOSE syscall number
    mov     rdi, r15                ; rdi ← fd (the descriptor still open from step 1)
    SYSCALL                         ; close fd even though write failed (ignore close error here)
    ; Fall through into error return.

.open_error:
    ; open() failed — no fd to close; fall straight to error return.
    ; (Label exists so the code path is clear; no instructions needed here.)

.close_error:
    ; close() itself failed; the write already completed correctly, but we report
    ; the close failure as an error since the file may not be fully flushed.
    mov     rax, -1                 ; rax ← -1 (error sentinel per function contract)
    RESTORE_REGS                    ; restore callee-saved registers
    ret                             ; return -1 to caller


; =============================================================================
; fileio_write_stdout
;
; Writes a buffer to standard output (fd 1) using a single write() syscall.
; Used by the CLI to print human-readable output, hex traces, and help text.
;
; Inputs:
;   rsi = pointer to data buffer
;   rdx = number of bytes to write
;
; Output:
;   rax = number of bytes actually written (as returned by write())
;
; Note: rdi is NOT used by this function; fd 1 is hardcoded.  The caller
; need only set rsi and rdx before calling.
; =============================================================================
fileio_write_stdout:
    ; This is a thin leaf function — no callee-saved registers are used, so
    ; we do not need SAVE_REGS/RESTORE_REGS.  We just issue the syscall directly.

    mov     rax, SYS_WRITE          ; rax ← syscall number for write() (0x2000004)
    mov     rdi, STDOUT             ; rdi ← 1 (fd 1 = stdout — the terminal display)
    ; rsi = buffer pointer — already in rsi per the calling convention documented above
    ; rdx = byte count    — already in rdx
    SYSCALL                         ; invoke kernel: write(1, rsi, rdx)
    ; rax ← bytes written (or errno with CF set on error; caller may inspect CF)
    ret                             ; return to caller; rax holds bytes-written count


; =============================================================================
; fileio_write_stderr
;
; Writes a buffer to standard error (fd 2) using a single write() syscall.
; Used by the CLI to print error and diagnostic messages separate from the
; primary output stream, matching Unix convention for error output.
;
; Inputs:
;   rsi = pointer to data buffer
;   rdx = number of bytes to write
;
; Output:
;   rax = number of bytes actually written (as returned by write())
;
; Note: rdi is NOT used; fd 2 is hardcoded.  The caller sets rsi and rdx.
; =============================================================================
fileio_write_stderr:
    ; Leaf function — direct syscall, no frame needed.

    mov     rax, SYS_WRITE          ; rax ← syscall number for write() (0x2000004)
    mov     rdi, STDERR             ; rdi ← 2 (fd 2 = stderr — error output channel)
    ; rsi = buffer pointer — already in rsi
    ; rdx = byte count    — already in rdx
    SYSCALL                         ; invoke kernel: write(2, rsi, rdx)
    ; rax ← bytes written (negative errno with CF on error)
    ret                             ; return; rax = bytes written
