; ─────────────────────────────────────────────────────────────────────────────
; syscall.inc — macOS BSD syscall numbers and file-open flags for x86-64
;
; On Darwin/macOS the BSD syscall table is accessed by OR-ing the syscall
; number with 0x2000000 (class 2 = BSD).  The kernel is entered via the
; `syscall` instruction.
;
; System V AMD64 ABI calling convention for syscall:
;   rax = syscall number
;   rdi = arg1,  rsi = arg2,  rdx = arg3
;   r10 = arg4,  r8  = arg5,  r9  = arg6
;   Return value in rax; on error CF is set and rax holds errno.
; ─────────────────────────────────────────────────────────────────────────────

%ifndef SYSCALL_INC
%define SYSCALL_INC

; ── BSD syscall numbers (macOS x86-64) ───────────────────────────────────────

SYS_EXIT  equ 0x2000001  ; exit(int status) — terminate the calling process
SYS_READ  equ 0x2000003  ; read(fd, buf, count) — read bytes from a file descriptor
SYS_WRITE equ 0x2000004  ; write(fd, buf, count) — write bytes to a file descriptor
SYS_OPEN  equ 0x2000005  ; open(path, flags, mode) — open or create a file
SYS_CLOSE equ 0x2000006  ; close(fd) — close an open file descriptor

; ── open() flag bits (fcntl.h, macOS) ────────────────────────────────────────

O_RDONLY  equ 0x0000     ; open for reading only (no write access)
O_WRONLY  equ 0x0001     ; open for writing only (no read access)
O_RDWR    equ 0x0002     ; open for both reading and writing
O_CREAT   equ 0x0200     ; create file if it does not already exist (requires mode arg)
O_TRUNC   equ 0x0400     ; truncate file to zero length on open (file must exist or O_CREAT set)

; ── Standard file descriptors ────────────────────────────────────────────────

STDIN     equ 0          ; standard input  — fd 0, typically the terminal keyboard
STDOUT    equ 1          ; standard output — fd 1, typically the terminal display
STDERR    equ 2          ; standard error  — fd 2, typically the terminal display (unbuffered)

; ── SYSCALL convenience macro ─────────────────────────────────────────────────
; Wraps the `syscall` instruction with a comment documenting the ABI so every
; call site is self-documenting.
;
; ABI summary:
;   rax = syscall number (SYS_* constant above, already loaded by caller)
;   rdi = first  argument
;   rsi = second argument
;   rdx = third  argument
;   r10 = fourth argument  (NOTE: r10 not rcx — the kernel clobbers rcx/r11)
;   r8  = fifth  argument
;   r9  = sixth  argument
;   Return value in rax; carry flag set on error (rax = errno).
;
; Usage example:
;   mov   rax, SYS_WRITE
;   mov   rdi, STDOUT
;   mov   rsi, msg
;   mov   rdx, msg_len
;   SYSCALL
; ─────────────────────────────────────────────────────────────────────────────
%macro SYSCALL 0
    syscall                 ; enter macOS BSD kernel; rax=number, rdi/rsi/rdx/r10/r8/r9=args, return in rax
%endmacro

%endif ; SYSCALL_INC
