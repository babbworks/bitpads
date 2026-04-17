; ─────────────────────────────────────────────────────────────────────────────
; syscall.inc — Linux x86-64 native syscall numbers and file-open flags
;
; On Linux x86-64 the native syscall table is accessed directly.  There is no
; BSD class offset — syscall numbers are used as-is.  The kernel is entered via
; the `syscall` instruction.
;
; System V AMD64 ABI calling convention for syscall:
;   rax = syscall number
;   rdi = arg1,  rsi = arg2,  rdx = arg3
;   r10 = arg4,  r8  = arg5,  r9  = arg6
;   Return value in rax; on error rax holds -errno (a negative value).
;   The carry flag is NOT set on error — use `test rax, rax` / `js` to detect.
;
; NOTE: This file replaces the macOS version (which used 0x2000000 BSD class
; offsets).  The SYSCALL macro body is identical; only the SYS_* constants and
; the O_* flag values differ between platforms.
; ─────────────────────────────────────────────────────────────────────────────

%ifndef SYSCALL_INC
%define SYSCALL_INC

; ── Linux native syscall numbers (x86-64) ────────────────────────────────────

SYS_READ  equ 0    ; read(fd, buf, count) — read bytes from a file descriptor
SYS_WRITE equ 1    ; write(fd, buf, count) — write bytes to a file descriptor
SYS_OPEN  equ 2    ; open(path, flags, mode) — open or create a file
SYS_CLOSE equ 3    ; close(fd) — close an open file descriptor
SYS_EXIT  equ 60   ; exit(int status) — terminate the calling process

; ── open() flag bits (fcntl.h, Linux x86-64) ─────────────────────────────────
; NOTE: These differ from macOS. macOS used O_CREAT=0x0200 and O_TRUNC=0x0400.

O_RDONLY  equ 0x0000     ; open for reading only (no write access)
O_WRONLY  equ 0x0001     ; open for writing only (no read access)
O_RDWR    equ 0x0002     ; open for both reading and writing
O_CREAT   equ 0x40       ; create file if it does not already exist (requires mode arg)
O_TRUNC   equ 0x200      ; truncate file to zero length on open

; ── Standard file descriptors ────────────────────────────────────────────────

STDIN     equ 0          ; standard input  — fd 0, typically the terminal keyboard
STDOUT    equ 1          ; standard output — fd 1, typically the terminal display
STDERR    equ 2          ; standard error  — fd 2, typically the terminal display (unbuffered)

; ── SYSCALL convenience macro ─────────────────────────────────────────────────
; Wraps the `syscall` instruction.  The macro body is identical on macOS and
; Linux — both platforms use the same `syscall` instruction to enter the kernel.
; The difference is in the syscall numbers loaded into rax before calling this.
;
; ABI summary (Linux x86-64):
;   rax = syscall number (SYS_* constant, no class offset needed)
;   rdi = first  argument
;   rsi = second argument
;   rdx = third  argument
;   r10 = fourth argument  (NOTE: r10 not rcx — the kernel clobbers rcx/r11)
;   r8  = fifth  argument
;   r9  = sixth  argument
;   Return value in rax.  On error: rax = -errno (negative).  CF is NOT set.
;
; Error detection after SYSCALL on Linux:
;   test  rax, rax
;   js    .error_handler    ; rax negative → error
; ─────────────────────────────────────────────────────────────────────────────
%macro SYSCALL 0
    syscall                 ; enter Linux kernel; rax=number, rdi/rsi/rdx/r10/r8/r9=args, return in rax
%endmacro

%endif ; SYSCALL_INC
