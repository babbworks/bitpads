# BitPads CLI — Technical Overview

---

## Platform and Toolchain

The CLI is written entirely in x86-64 NASM assembly targeting macOS Mach-O 64-bit. No C runtime is linked. The program calls the macOS kernel directly via BSD syscall numbers (`SYS_WRITE = 0x2000004`, `SYS_OPEN = 0x2000005`, etc.) using the `syscall` instruction with the System V AMD64 calling convention. The entry point is `_main`, called by the macOS runtime after process initialization.

The assembler is NASM. The linker is the macOS `ld` from Xcode Command Line Tools, linked against `-lSystem` for the runtime stub. All source files use `default rel` for RIP-relative addressing, required for correct position-independent data references in Mach-O 64.

---

## Source Layout

```
src/
  main.asm                    — entry point, dispatch loop, exit codes
  cli_parse.asm               — argument parser, populates bp_ctx
  dispatch.asm                — routes bp_ctx to builder by type code

  layers/
    meta1.asm                 — Meta Byte 1 builder
    meta2.asm                 — Meta Byte 2 builder
    layer1.asm                — 8-byte Layer 1 session header builder + CRC embed
    layer2.asm                — 6-byte Layer 2 batch context header builder
    layer3.asm                — 5-byte Layer 3 BitLedger record builder

  components/
    setup.asm                 — Setup Byte builder
    value.asm                 — value block encoder (1–4 byte tiers)
    time_comp.asm             — time field encoder (T1S 1-byte, T2 2-byte)
    task.asm                  — task block encoder (1–3 bytes, expansion flags)
    note.asm                  — note block encoder (length-prefixed UTF-8)

  enhancement/
    c0gram.asm                — C0 grammar handler (signal slot sequencing)
    signals.asm               — signal slot byte writer
    cmd1100.asm               — Compact Command (category 12) payload builder
    ctx1101.asm               — Context Declaration (category 13) payload builder
    tel1110.asm               — Telegraph (category 14) payload builder

  builders/
    build_signal.asm          — Pure Signal frame assembler
    build_wave.asm            — Wave frame assembler
    build_record.asm          — Record frame assembler
    build_ledger.asm          — BitLedger frame assembler

  crypto/
    crc15.asm                 — CRC-15 compute and embed

  io/
    fileio.asm                — file open/write/close, stdout write, stderr write
    hexdump.asm               — hex trace output formatter

include/
  bitpads.inc                 — all protocol constants and bp_ctx offsets
  syscall.inc                 — BSD syscall numbers
  macros.inc                  — SAVE_REGS / RESTORE_REGS stack frame macros
```

---

## Execution Flow

```
_main
  │
  ├─ cli_parse          reads argv, populates bp_ctx, validates required fields
  │
  ├─ dispatch_loop      repeats --count times
  │    │
  │    └─ dispatch_build
  │         │
  │         ├─ build_signal   (type 0)
  │         ├─ build_wave     (type 1)
  │         ├─ build_record   (type 2)
  │         ├─ build_ledger   (type 3)
  │         └─ build_wave     (type 4, telem — category + domain pre-set by dispatch)
  │
  └─ print success / exit
```

Each builder writes into a 4096-byte stack-allocated output buffer, then calls the appropriate I/O function based on `BP_CTX_OUTMODE`. The buffer is not heap-allocated; `BP_OUTBUF_SIZE = 4096` is sized generously above the maximum possible frame size to eliminate bounds checks in the builders.

---

## The Context Block (bp_ctx)

`bp_ctx` is a 256-byte flat structure allocated on the stack in `cli_parse` and passed by pointer (`rdi`) to every subsequent function. It is the single shared data object for the entire lifetime of one frame assembly pass.

The parser writes all flag values into it. The builders read from it. No global state is used. The context block is the complete specification of one transmission, in unpacked canonical form, before any wire-format packing takes place.

Key regions within the 256 bytes:

| Offset | Field | Notes |
|--------|-------|-------|
| 0 | `BP_CTX_TYPE` | Frame type code 0–4 |
| 1 | `BP_CTX_DOMAIN` | Domain: 0=fin, 1=eng, 2=hybrid, 3=custom |
| 2 | `BP_CTX_PERMISSIONS` | 4-bit permission field |
| 4 | `BP_CTX_SENDER_ID` | 32-bit sender (dword) |
| 10 | `BP_CTX_ENHANCEMENT` | Enhancement flag for C0 grammar |
| 11 | `BP_CTX_CATEGORY` | Wave category code 0–15 |
| 12 | `BP_CTX_VALUE` | 32-bit value (dword) |
| 16 | `BP_CTX_VALUE_PRES` | Value block present flag |
| 17 | `BP_CTX_VALUE_TIER` | Encoding tier 1–4 |
| 18 | `BP_CTX_SF_INDEX` | Scaling factor index 0–3 |
| 19 | `BP_CTX_DP` | Decimal position 0, 2, 4, or 6 |
| 20 | `BP_CTX_TIME_VAL` | 8-bit T1S timestamp value |
| 21 | `BP_CTX_TIME_PRES` | Time field present flag |
| 22 | `BP_CTX_TIME_TIER` | Time selector code |
| 23 | `BP_CTX_TASK_BYTE` | Task byte (3 bytes for task + optional target + timing) |
| 26 | `BP_CTX_TASK_PRES` | Task block present flag |
| 27 | `BP_CTX_NOTE_LEN` | Note byte count |
| 28 | `BP_CTX_NOTE_PRES` | Note block present flag |
| 29 | `BP_CTX_NOTE_DATA` | Note payload (up to 63 bytes inline) |
| 80 | `BP_CTX_ARCHETYPE` | 4-bit archetype for Meta Byte 2 upper nibble |
| 81 | `BP_CTX_TIME_EXT` | 16-bit Tier 2 extended timestamp (word) |
| 83–88 | Layer 2 fields | Bells, separator counters, currency, rounding balance |
| 89–95 | Layer 3 fields | L3 extension, compound-max, account pair, direction, completeness, compound mode |
| 96–100 | Frame control | ACK, continuation, priority, Layer 2 presence, signal slots |
| 101 | `BP_CTX_OUTFILE` | Null-terminated output path (63 chars max) |
| 181 | `BP_CTX_OUTMODE` | Output mode: file/dryrun/hex/hex-raw |
| 182 | `BP_CTX_PRINT_SIZE` | Suppress success message flag |
| 183 | `BP_CTX_COUNT` | Repeat count for dispatch loop |
| 165 | `BP_CTX_SIGNALS` | 16 bytes of signal slot data (P4–P8) |

All fields are stored in natural unpacked form. Wire-format packing — shifting, masking, splitting across byte boundaries — happens only in the layer and component builders, not in the context block.

---

## Frame Assembly Pipeline

A Record frame assembly pass illustrates the full pipeline. Other types follow the same pattern with fewer layers.

```
build_record
  │
  ├─ layer1_build         → 8 bytes  [buffer + 0]
  │    └─ crc15_embed     embeds CRC-15 into bytes[6–7] of L1 output
  │
  ├─ layer2_build         → 6 bytes  [buffer + 8]   (if --layer2)
  │
  ├─ meta1_build          → 1 byte   write to buffer
  ├─ meta2_build          → 1 byte   write to buffer
  │
  ├─ c0gram_build         → SSP byte + P4 signal    (if --enhance + slots)
  │
  ├─ setup_build          → 1 byte   (auto-inserted if tier/sf/dp deviate from defaults)
  ├─ value_encode         → 1–4 bytes
  ├─ time_build           → 1 or 2 bytes
  ├─ signal_build P5/P6/P7 at their defined positions
  ├─ task_build           → 1–3 bytes
  ├─ note_build           → 1 + N bytes (length prefix + payload)
  │
  └─ fileio dispatch      → file write / stdout / dry-run discard
```

Each builder function receives `rdi = bp_ctx pointer` and `rsi = write position in output buffer`. It returns `rax = bytes written`. The calling builder advances the buffer pointer by that return value and calls the next component. The frame is assembled sequentially in a single contiguous buffer pass; no post-processing or rewriting occurs.

---

## Layer 1 and CRC-15

Layer 1 is an 8-byte session header present in all Record and Ledger frames. Its structure:

```
byte[0]  : SOH (bit7=1) | domain (bits5-4) | permissions (bits3-0)
bytes[1–5]: sender ID (32-bit, packed into bits 13–44)
byte[6]  : sub-entity LSB (bit7) | CRC-15 bits[14:8]
byte[7]  : CRC-15 bits[7:0]
```

The CRC-15 is computed over the entire 49-bit Layer 1 payload (bits 1–49, covering SOH through sub-entity) using the polynomial x¹⁵ + x + 1 (0x0003). The LFSR operates MSB-first across 7 bytes. `crc15_compute` returns the 15-bit result in `rax`. `crc15_embed` then packs it into bytes[6–7] of the assembled Layer 1 buffer, preserving the sub-entity LSB in byte[6] bit[7].

The CRC binding is absolute: any change to the sender ID, domain, permissions, or sub-entity invalidates the checksum. There is no separate validation call — the CRC is embedded during assembly and the receiver validates it on arrival.

---

## Meta Bytes

Meta Byte 1 is the first byte of every BitPads transmission. It encodes frame mode and content flags:

```
bit7 (0x80) : Mode — 0=Wave, 1=Record
bit6 (0x40) : ACK Request (Wave) / System Context Extension (Record)
bit5 (0x20) : Continuation / Fragment
bit4 (0x10) : Treatment Switch — 0=Role A, 1=Role B (category mode)
bits3-0     : Role A: priority/cipher/profile flags
              Role B: 4-bit category code
              Role C: Value|Time|Task|Note presence flags (Record mode)
```

Meta Byte 2 carries encoding overrides and presence flags for subsequent blocks:

```
bits7-4 : Archetype (4-bit stream type identifier)
bits3-2 : Time selector (00=none, 01=T1S, 10=T1E, 11=T2)
bit1    : Setup Byte present (auto-set when tier/SF/DP differ from defaults)
bit0    : Signal Slot Presence byte follows (C0 grammar, requires Enhancement Flag)
```

`meta1_build` and `meta2_build` are pure functions: they read `bp_ctx` and return the finished byte in `al`. They do not write to any output buffer; the calling builder writes the return value at the current buffer position.

---

## Setup Byte Auto-Insertion

The Setup Byte is inserted automatically — never explicitly by the user — when any of the following conditions hold:

- `--tier` is not 3 (session default tier is Tier 3, 24-bit)
- `--sf` is not 0 (default scaling factor is ×1)
- `--dp` is not 2 (default decimal position is 2 places)

`meta2_build` sets the Setup Byte flag in Meta Byte 2 when this condition is detected. `setup_build` is then called by the frame builder to write the byte. The Setup Byte encodes the tier, SF, and DP override values in a packed single-byte format. The receiver reads the Meta Byte 2 flag to determine whether to expect a Setup Byte before attempting to read the value block.

---

## Wave Category Routing

`build_wave` reads `BP_CTX_CATEGORY` and dispatches to one of four sub-builders:

| Category | Code | Builder |
|----------|------|---------|
| 0 (plain value) | `BP_CAT_PLAIN_VALUE` | value/time component path |
| 12 (compact command) | `BP_CAT_COMPACT_CMD` | `cmd1100_build` |
| 13 (context declaration) | `BP_CAT_CTX_DECL` | `ctx1101_build` |
| 14 (telegraph) | `BP_CAT_TELEGRAPH` | `tel1110_build` |

`--type telem` sets `BP_CTX_CATEGORY = 0x0E` in `dispatch.asm` before calling `build_wave`, so the telemetry shorthand routes through `tel1110_build` without the user needing to pass `--category 14`.

---

## C0 Grammar and Signal Slots

The Enhancement Flag in Layer 1 byte[1] bit[4] activates the C0 grammar extension for the session. When active, up to 13 named signal positions (P0–P12) are available, each defined as firing at a specific point in the frame body.

CLI-accessible slots are P4–P8:

| Slot | Position |
|------|----------|
| P4 | Before value block |
| P5 | After value block |
| P6 | After time field |
| P7 | After task block |
| P8 | After note block (end of record body) |

When any slot flag (`--slot-p4` through `--slot-p8`) is provided, `meta2_build` sets bit[0] (Signal Slot Presence). The `c0gram_build` function writes a Signal Slot Presence (SSP) byte declaring which slots are active, and the `signals.asm` module writes the signal bytes at their declared positions within the frame body. The ordering is absolute — the frame builder calls `signal_build` at the exact position corresponding to each slot's protocol definition. Skipping a declared slot or inserting one out of position is a protocol violation.

---

## Stack Frame Convention

All non-leaf functions use the `SAVE_REGS` / `RESTORE_REGS` macros defined in `macros.inc`. The macro sequence is:

```asm
SAVE_REGS:
    push    rbp
    mov     rbp, rsp          ; rbp now points to saved_rbp slot
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    and     rsp, -16          ; align stack to 16-byte boundary for calls
```

```asm
RESTORE_REGS:
    lea     rsp, [rbp - 40]   ; rbp - 40 = address of saved_r15 (5 × 8 bytes below rbp)
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
```

The `lea rsp, [rbp - 40]` in RESTORE_REGS is critical. After `push rbp; mov rbp, rsp`, rbp holds the address of the saved_rbp slot on the stack. The five subsequent register pushes place saved values at rbp−8 through rbp−40. `and rsp, -16` may have moved rsp further down for alignment padding. `lea rsp, [rbp - 40]` bypasses any padding and lands directly at the first saved register (r15), so the five pops restore exactly the right values regardless of how much padding the alignment step inserted.

---

## I/O Layer

All I/O routes through `fileio.asm`. Four entry points:

| Function | Description |
|----------|-------------|
| `fileio_write` | Open file (create/truncate), write buffer, close |
| `fileio_write_stdout` | Write buffer to fd 1 |
| `fileio_write_stderr` | Write buffer to fd 2 |
| `fileio_write_hex` | Write hex-formatted dump of buffer to stdout |

The output mode stored in `BP_CTX_OUTMODE` governs which path the builder calls after assembling the frame. Dry-run mode (`BP_OUTMODE_DRYRUN = 1`) skips all I/O calls; the assembled frame is validated and discarded.

---

## Build System

The Makefile compiles each `.asm` source to a `.o` object file using `nasm -f macho64`, then links all objects with `ld -lSystem`. Source files are listed in dependency order — lower-level modules (crypto, I/O, layers, components) before higher-level ones (builders, dispatch, main). Every object file depends on all three include files (`bitpads.inc`, `syscall.inc`, `macros.inc`), so any change to a constant or macro triggers a full rebuild.

```
make          — build ./bitpads
make clean    — remove all .o files and the binary
make test     — build and run test binaries in tests/
```
