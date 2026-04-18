# Build Fix Notes: x86-64 NASM on macOS
## Five errors, the theory behind each, and how they were resolved

This document covers every build failure encountered in the BitPads `assemblycli` project and
explains not just the fix but the underlying architecture and assembler theory that explains why
the error occurs in the first place. The goal is that after reading this you can anticipate and
prevent each class of error yourself.

---

## Table of Contents

1. [Background: the macOS / Mach-O execution environment](#1-background-the-macos--mach-o-execution-environment)
2. [Error class 1 — `movzx` with a 32-bit source operand](#2-error-class-1--movzx-with-a-32-bit-source-operand)
3. [Error class 2 — Undefined constant used in `.bss`](#3-error-class-2--undefined-constant-used-in-bss)
4. [Error class 3 — 32-bit absolute addresses in a 64-bit binary](#4-error-class-3--32-bit-absolute-addresses-in-a-64-bit-binary)
5. [Error class 4 — `[symbol + register]` and the limits of `default rel`](#5-error-class-4--symbol--register-and-the-limits-of-default-rel)
6. [Error class 5 — Stack misalignment with mixed push/sub prologues](#6-error-class-5--stack-misalignment-with-mixed-pushsub-prologues)
7. [Summary table](#7-summary-table)
8. [Mental model: writing portable 64-bit NASM from the start](#8-mental-model-writing-portable-64-bit-nasm-from-the-start)

---

## 1. Background: the macOS / Mach-O execution environment

Before any error makes sense, you need a picture of what NASM is actually targeting.

### The object file format

Every `.asm` file is assembled into an **object file** — a binary container that holds machine
code and metadata. On Linux the format is ELF; on macOS it is **Mach-O** (Mach Object). These
formats have different rules about how symbols are resolved and how addresses are encoded.

The key Mach-O rule: **all code and data is position-independent by design**. The dynamic linker
(`dyld`) can load your binary anywhere in the 64-bit address space. It cannot afford to patch
every address reference the way an ELF linker does with 32-bit relocations. As a result,
**Mach-O 64-bit rejects any instruction that encodes a static symbol as a 32-bit absolute
address**. If NASM generates a 32-bit absolute for a BSS or data symbol, `nasm` itself raises:

```
error: Mach-O 64-bit format does not support 32-bit absolute addresses
```

This rules out entire categories of addressing that work fine on Linux ELF.

### The System V AMD64 ABI

Both Linux and macOS use the System V AMD64 calling convention (macOS adds a few Darwin-specific
syscall conventions on top). Key rules that matter for this project:

| Concern | Rule |
|---|---|
| Integer arguments | `rdi rsi rdx rcx r8 r9` (in order) |
| Return value | `rax` (64-bit), `eax` implicitly zero-extends to `rax` |
| Caller-saved | `rax rcx rdx rsi rdi r8 r9 r10 r11` — destroyed by `call` |
| Callee-saved | `rbx rbp r12 r13 r14 r15` — must be preserved across `call` |
| Stack alignment | `rsp` must be **16-byte aligned at the moment a `call` executes** |

The alignment rule is the one most commonly violated. See [Error class 5](#6-error-class-5--stack-misalignment-with-mixed-pushsub-prologues).

---

## 2. Error class 1 — `movzx` with a 32-bit source operand

### Files affected
`ctx1101.asm`, `tel1110.asm`, `build_record.asm`, `build_ledger.asm`, `build_wave.asm`

### The error

```
error: invalid combination of opcode and operands
```

### The instruction in question

```nasm
movzx   rax, ecx        ; INVALID — 32-bit source
movzx   rdx, r12d       ; INVALID — 32-bit source
```

### Theory: what `movzx` actually is

`movzx` stands for **Move with Zero-Extension**. It copies a value from a smaller source into a
larger destination, filling the upper bits of the destination with zeros.

The x86-64 instruction set defines `movzx` for exactly two source sizes:

| Form | Meaning |
|---|---|
| `movzx r16, r/m8` | 8-bit → 16-bit |
| `movzx r32/r64, r/m8` | 8-bit → 32-bit or 64-bit |
| `movzx r32/r64, r/m16` | 16-bit → 32-bit or 64-bit |

There is **no encoding for `movzx reg64, r/m32`**. A 32-bit to 64-bit zero-extension is a
separate concept handled by a completely different mechanism.

### Theory: implicit zero-extension on x86-64

This is one of the most important architectural facts about x86-64: **any instruction that writes
to a 32-bit register automatically zeroes the upper 32 bits of the parent 64-bit register**.

```nasm
mov     eax, ecx        ; writes to eax → upper 32 bits of rax become 0 automatically
mov     edx, r12d       ; writes to edx → upper 32 bits of rdx become 0 automatically
```

This was a deliberate design decision when AMD extended x86 to 64 bits. Writing to the 32-bit
form of a register is the canonical way to zero-extend a 32-bit value into a 64-bit register.
Writing to 8-bit or 16-bit registers does **not** zero-extend — those preserve the upper bits.
That asymmetry is intentional and worth internalising early.

So `movzx rax, ecx` is not just a NASM error — it describes an operation that has no opcode
because `mov eax, ecx` already does exactly what it says.

### The fix

```nasm
; Before (invalid)
movzx   rax, ecx                ; rax = total bytes written
movzx   rdx, r12d               ; rdx = total frame size

; After (correct)
mov     eax, ecx                ; rax = total bytes written (upper 32 bits implicitly zeroed)
mov     edx, r12d               ; rdx = total frame size   (upper 32 bits implicitly zeroed)
```

### Pattern to watch for

Any time you want to promote a 32-bit value to 64-bit for use as a function argument or pointer,
`mov reg32d, src32` is the right tool. `movzx` is for 8→32, 8→64, 16→32, and 16→64 only.

---

## 3. Error class 2 — Undefined constant used in `.bss`

### Files affected
`build_wave.asm`, `build_record.asm`, `build_ledger.asm`

### The error

```
error: forward reference in RESx can have unpredictable results [-w+error=forward]
```

### The symbol in question

```nasm
section .bss
    wave_buf    resb BP_OUTBUF_SIZE   ; BP_OUTBUF_SIZE was never defined
```

### Theory: sections and symbol resolution order

NASM assembles your file in one pass (with some lookahead for labels). Constants defined with
`equ` or `%define` in include files are available immediately — but only if those includes appear
**before** the reference. The three include files (`bitpads.inc`, `syscall.inc`, `macros.inc`)
are included at the top of every source file, so all constants defined there are available
everywhere.

`BP_OUTBUF_SIZE` was simply never defined anywhere in the include files. NASM saw an unresolved
symbol in a `resb` context and treated it as a forward reference to a label (something that might
be defined later in the same translation unit). Since no such label exists, the reserved size was
unpredictably zero or undefined. The `-Werror` flag in the Makefile promotes this warning to a
hard error.

### Theory: what `.bss` is and how `resb` works

The `.bss` section (Block Started by Symbol) is for **uninitialised data**. Unlike `.data` (which
stores actual bytes in the object file), `.bss` only records how many bytes to reserve — the
operating system zero-initialises the memory at load time. This makes object files smaller.

`resb N` means "reserve N bytes". `N` must be a constant known at assembly time.

### The fix

Added to `bitpads.inc`:

```nasm
; ── Buffer Sizes ─────────────────────────────────────────────────────────────
BP_OUTBUF_SIZE  equ 4096    ; max output frame buffer (generous for all frame types)
```

4096 bytes (4 KB) is conservative. The largest possible BitPads frame (full Layer 1 + Layer 2 +
Layer 3 + all optional components + all signal slots) is well under 512 bytes, so 4096 gives a
comfortable margin for future protocol extensions without wasting meaningful memory.

Also added the missing time-selector mask constant:

```nasm
BPv2_META2_TIMESEL      equ 0x0C    ; mask for time selector bits (bits 3-2)
```

This was referenced in `build_wave.asm` to isolate the two time-selector bits from Meta Byte 2,
but only the four specific values (`NONE`, `T1S`, `T1E`, `T2`) were defined, not the bitmask
itself. A mask constant is the correct tool when you want to isolate a bitfield before comparing
it against known values:

```nasm
and     al, BPv2_META2_TIMESEL       ; isolate bits 3-2
cmp     al, BPv2_META2_TIMESEL_NONE  ; compare against the "no time" case
```

---

## 4. Error class 3 — 32-bit absolute addresses in a 64-bit binary

### Files affected
`build_signal.asm`, `build_record.asm`, `build_ledger.asm`, `build_wave.asm`,
`hexdump.asm`, `cli_parse.asm`

### The error

```
error: Mach-O 64-bit format does not support 32-bit absolute addresses
```

### Theory: how NASM encodes symbol references by default

When you write `[symbol]` in NASM without any modifier, NASM encodes the address of `symbol` as
a 32-bit immediate embedded in the instruction. On 32-bit x86 and Linux ELF64, this often works
because the linker can patch those references. On Mach-O 64-bit, it does not — the format simply
refuses to carry 32-bit absolute relocations.

The correct mechanism for accessing static symbols in 64-bit position-independent code is
**RIP-relative addressing** (also called PC-relative, where RIP is the instruction pointer at the
next instruction):

```
effective_address = RIP + displacement
```

The displacement is a 32-bit signed integer, giving a ±2 GB reach from the current instruction.
Since code and data in a single binary are always within that range of each other, this covers
all static symbol accesses. It is also fully position-independent — the displacement between code
and data is fixed regardless of where the OS loads the binary.

### NASM syntax for RIP-relative

```nasm
; Explicit
lea     rsi, [rel my_buffer]     ; rsi = address of my_buffer (RIP-relative)
mov     byte [rel my_buffer], al ; write through RIP-relative address

; Or: set a default so you never have to write 'rel' manually
default rel
lea     rsi, [my_buffer]         ; now implicitly RIP-relative
```

The `default rel` directive tells NASM to generate RIP-relative references for all `[symbol]`
expressions in memory operands from that point forward. It is the standard practice for any
assembly file targeting 64-bit position-independent code on macOS.

### Where to put `default rel`

Place it immediately after `section .text`, before any code:

```nasm
section .text
default rel

my_function:
    lea     rdi, [my_string]    ; RIP-relative, no explicit 'rel' needed
```

It applies to everything that follows in the file. It has no effect on `.data` or `.bss` section
directives — those sections don't contain instructions.

### The fix

Added `default rel` after `section .text` in all six affected files. Each file had at least one
static symbol being loaded via `lea` or accessed via `mov [...], reg`:

```nasm
; Before
lea     rsi, [signal_buf]       ; 32-bit absolute → Mach-O error

; After (with 'default rel' active)
lea     rsi, [signal_buf]       ; RIP-relative → correct
```

---

## 5. Error class 4 — `[symbol + register]` and the limits of `default rel`

### Files affected
`build_wave.asm`, `build_record.asm`, `build_ledger.asm`

### The error (same message as Error class 3)

```
error: Mach-O 64-bit format does not support 32-bit absolute addresses
```

### Why `default rel` is not enough here

After adding `default rel`, the simple `[symbol]` forms were fixed. But many lines looked like:

```nasm
mov     byte [wave_buf + r12], al
lea     rsi, [wave_buf + r12]
```

These still failed. The reason is architectural, not a NASM limitation.

### Theory: RIP-relative cannot have a register index

The x86-64 addressing mode for RIP-relative is encoded as:

```
[RIP + disp32]
```

There is no encoding for `[RIP + disp32 + register]`. The ModRM/SIB byte encoding of x86-64
simply does not provide for a RIP base combined with a scaled index. When you write
`[wave_buf + r12]`, NASM cannot generate a RIP-relative form because the expression requires both
a static displacement (the symbol address) and a runtime register value (the index). NASM falls
back to 32-bit absolute for the static part, which Mach-O then rejects.

This is not a bug or a NASM quirk — it is a fundamental property of the x86-64 instruction set.

### Theory: the correct pattern for indexed buffer access

The standard approach for accessing elements of a statically allocated buffer by a runtime index
is to first load the buffer's base address into a register, then use register-relative addressing:

```nasm
; Step 1: get the base address into a register (one-time cost, RIP-relative)
lea     r14, [rel wave_buf]     ; r14 = &wave_buf[0]

; Step 2: all subsequent accesses use only register arithmetic (no static symbol)
mov     byte [r14 + r12], al   ; wave_buf[r12] = al  ← fully register-relative, always valid
lea     rsi, [r14 + r12]       ; rsi = &wave_buf[r12]
```

This pattern is how compilers handle static array indexing in position-independent code. The
static symbol appears only once (in the `lea` that loads the base), and everything else is
pure register arithmetic. You pay one extra register (r14) to keep the base address, but you
get unlimited, efficient, Mach-O-compatible indexed access.

### The fix

In each of the three builder functions, r14 was chosen as the buffer base register (it is
callee-saved, so it survives the many internal `call` instructions). The `lea` to load the
base was added right after the initial zero of r12:

```nasm
; build_wave.asm
    xor     r12d, r12d              ; r12d = byte offset (starts at 0)
    lea     r14, [rel wave_buf]     ; r14  = base address of output buffer

; build_record.asm
    xor     r12d, r12d              ; r12d = byte offset
    lea     r14, [rel rec_buf]      ; r14  = base address of output buffer

; build_ledger.asm
    xor     r12d, r12d              ; r12d = byte offset
    lea     r14, [rel ledger_buf]   ; r14  = base address of output buffer
```

Then every occurrence of `[wave_buf + r12]` was replaced with `[r14 + r12]`, and every
`lea rsi, [wave_buf]` (the non-indexed form, for passing the buffer start to `fileio_write`)
was replaced with `mov rsi, r14` — which is both correct and slightly more efficient.

---

## 6. Error class 5 — Stack misalignment with mixed push/sub prologues

### Files affected
`build_record.asm`, `build_ledger.asm` (pre-existing latent bug, surfaced during the r14 fix)

### Why this matters

A misaligned stack does not always cause an immediate crash. It causes undefined behavior that
typically manifests only when an SSE or AVX instruction accesses memory with an alignment
requirement (e.g., `movaps` requires 16-byte alignment) or when the OS signal handler trips over
it. It can be silent for simple integer code and then catastrophic in unexpected circumstances.

### Theory: the ABI stack alignment contract

The System V AMD64 ABI states:

> "The end of the input argument area shall be aligned on a 16-byte boundary when the call
> instruction is executed."

In practice this means: **immediately before a `call` instruction executes, `rsp` must be
16-byte aligned**. The `call` instruction then pushes the 8-byte return address, leaving rsp
misaligned by 8 — which is the expected state at function entry.

So the contract for a callee is:
1. At function entry, `rsp` is 8 bytes below a 16-byte boundary (misaligned).
2. The callee must restore 16-byte alignment before any `call` it makes.
3. The callee must restore `rsp` to its entry value before `ret`.

### Counting pushes

Every `push` subtracts 8 from `rsp`. Starting from entry state (`rsp ≡ 8 mod 16`):

| Pushes so far | rsp offset | 16-byte aligned? |
|---|---|---|
| 0 (entry) | −8 | No |
| 1 (`push rbp`) | −16 | **Yes** |
| 2 (`push rbx`) | −24 | No |
| 3 (`push r12`) | −32 | **Yes** |
| 4 (`push r13`) | −40 | No |
| 5 (`push r14`) | −48 | **Yes** |
| 6 (`push r15`) | −56 | No |

The pattern: after an **odd** number of pushes (from entry), rsp is aligned. After an **even**
number, it is not. The `sub rsp, N` padding exists to compensate.

### The bug in build_record.asm / build_ledger.asm

These files had:

```nasm
push    rbp
push    rbx
push    r12
push    r13
push    r14         ; 5 pushes total → rsp is aligned here
sub     rsp, 8      ; misaligns again! now rsp ≡ 8 mod 16 → WRONG
```

The `sub rsp, 8` was correct when there were only 4 pushes. When r14 was added (presumably by
a previous partial fix attempt), the `sub rsp, 8` was not removed. The result: every `call`
instruction in those functions was called with a misaligned stack.

The epilogue had the corresponding `add rsp, 8` which would restore balance — but the mismatch
was still there for every internal call.

### The fix

Remove `sub rsp, 8` (and its matching `add rsp, 8`) when the push count already achieves
alignment:

```nasm
; Correct prologue (5 pushes, no sub needed)
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14         ; rsp is now 16-byte aligned — ready to call

; Correct epilogue
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
```

For `build_wave.asm` (which previously had 4 pushes + `sub rsp, 8`), the fix was to promote
the `sub rsp, 8` into `push r14`, which is both correct and useful since r14 is now needed to
hold the buffer base.

### General rule

Write a small table in a comment at the top of any function that uses many callee-saved registers:

```nasm
; Stack frame:
;   push rbp    → rsp -8  (misaligned at entry, +push = aligned)
;   push rbx    → rsp -16
;   push r12    → rsp -24 ← misaligned
;   push r13    → rsp -32 ← aligned, stop here if no r14 needed
;   push r14    → rsp -40 ← misaligned, need sub rsp, 8
;   sub rsp, 8  → rsp -48 ← aligned ✓
```

Count explicitly. Do not guess.

---

## 7. Summary table

| # | Error message | Root cause | Fix |
|---|---|---|---|
| 1 | `invalid combination of opcode and operands` | `movzx reg64, reg32` — no such encoding | Replace with `mov reg32, reg32` (implicit zero-extension) |
| 2 | `forward reference in RESx` | `BP_OUTBUF_SIZE` undefined; also `BPv2_META2_TIMESEL` undefined | Add both constants to `bitpads.inc` |
| 3 | `Mach-O 64-bit format does not support 32-bit absolute addresses` (simple `[symbol]`) | NASM default addressing is 32-bit absolute; Mach-O forbids it | Add `default rel` after `section .text` in every affected file |
| 4 | `Mach-O 64-bit format does not support 32-bit absolute addresses` (`[symbol + reg]`) | RIP-relative cannot combine with a register index — architectural constraint | Load buffer base into a callee-saved register once; use `[base + offset]` everywhere |
| 5 | (silent misalignment — no assembler error) | 5 pushes + `sub rsp, 8` leaves stack misaligned for all `call`s inside the function | Remove redundant `sub rsp, 8` / `add rsp, 8`; 5 pushes already achieve alignment |

---

## 8. Mental model: writing portable 64-bit NASM from the start

If you start a new `.asm` file for this project, this checklist prevents all five error classes:

### File template

```nasm
    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    extern some_function
    global my_function

section .bss
    my_buf  resb BP_OUTBUF_SIZE     ; use defined constants, never raw numbers

section .text
default rel                         ; ← always add this; makes all [symbol] RIP-relative

my_function:
```

### Register choice rules

- Use `rax`/`eax` only for short-lived results. Never keep a value in `rax` across a `call`.
- Callee-saved registers (`rbx`, `r12`–`r15`, `rbp`) are safe to use as persistent state
  across calls — but you must push them in the prologue and pop them in the epilogue.
- When you need a base address for a static buffer, load it once with `lea reg, [rel buf]` into
  a callee-saved register. r14 is a good choice if r12/r13 are taken.

### Zero-extension rules (memorise these)

| Operation | Zero-extends to 64 bits? |
|---|---|
| Write to `reg64` (e.g. `mov rax, ...`) | Yes — full 64-bit write |
| Write to `reg32` (e.g. `mov eax, ...`) | **Yes — upper 32 bits zeroed** |
| Write to `reg16` (e.g. `mov ax, ...`) | **No** — upper 48 bits preserved |
| Write to `reg8` (e.g. `mov al, ...`) | **No** — upper 56 bits preserved |
| `movzx reg32/64, r/m8` | Yes — explicit zero-extension from 8-bit |
| `movzx reg32/64, r/m16` | Yes — explicit zero-extension from 16-bit |
| `movzx reg64, r/m32` | **Does not exist** — use `mov reg32, r/m32` |

### Stack alignment checklist

Before writing the prologue, count:
- Pushes needed (includes `push rbp`).
- If odd → already aligned after all pushes, no `sub rsp, N` needed.
- If even → need `sub rsp, 8` (or push one more callee-saved register if you actually need it).
- Local variable space: add in multiples of 16 to maintain alignment.

```nasm
; 3 registers preserved (odd) → aligned after last push, no sub needed
push    rbp
push    rbx
push    r12        ; rsp = entry − 24 → misaligned; wait…
; Actually: entry rsp ≡ 8 (mod 16). After 3 pushes: 8 + 24 = 32 ≡ 0 → aligned ✓
```

Think of it as: after function entry rsp needs to travel an additional 8 bytes to become aligned.
Each push contributes 8 bytes. So you need an **odd** total number of 8-byte adjustments
(pushes + sub/8) to reach alignment. One push = 1 (odd) → aligned. Two pushes = 2 (even) → not.
`push rbp` followed by `push rbx` = 2 pushes → not aligned → need `sub rsp, 8`. Three pushes
→ aligned. And so on.

### Addressing mode cheat-sheet for Mach-O 64-bit

| Pattern | Valid? | Note |
|---|---|---|
| `[rbx + offset]` | Yes | Register base + constant offset — always fine |
| `[rel symbol]` | Yes | RIP-relative — explicit, always works |
| `[symbol]` with `default rel` | Yes | Implicit RIP-relative |
| `[symbol]` without `default rel` | **No** | 32-bit absolute — Mach-O rejects |
| `[rel symbol + reg]` | **No** | RIP cannot be combined with index register |
| `[base_reg + index_reg]` | Yes | Pure register arithmetic — always fine |
| `[base_reg + index_reg * scale]` | Yes | Full SIB encoding — always fine |

The takeaway: **keep static symbol references separate from runtime index arithmetic**. Load
the static address once into a register; then index using only registers.
