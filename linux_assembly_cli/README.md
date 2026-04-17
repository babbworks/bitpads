# BitPads Assembly CLI — Linux x86-64

Linux port of the BitPads assembly CLI. Ported from `../assemblycli/` (macOS x86-64).

Identical protocol output. Identical CLI interface. Platform layer swapped.

---

## Requirements

- **NASM** 2.14 or later
- **GNU binutils** `ld`
- **Linux x86-64** kernel (2.6.29+ for guaranteed 16-byte stack alignment at `_start`)

---

## Build

```bash
cd linux_assembly_cli
make
```

The binary is produced as `./bitpads`.

---

## Usage

The CLI interface is identical to the macOS version:

```bash
./bitpads --type signal --hex-raw
./bitpads --type wave --value 1234 --hex
./bitpads --type record --sender-id 42 --value 5000 --out frame.bin
./bitpads --type ledger --sender-id 1 --acct 1 --dir 0 --value 10000 --out tx.bin
```

---

## What Changed from the macOS Source

Only the platform layer was changed. All protocol logic is untouched.

### `include/syscall.inc` — complete replacement

| Constant | macOS (BSD class) | Linux (native) |
|----------|-------------------|----------------|
| `SYS_READ` | `0x2000003` | `0` |
| `SYS_WRITE` | `0x2000004` | `1` |
| `SYS_OPEN` | `0x2000005` | `2` |
| `SYS_CLOSE` | `0x2000006` | `3` |
| `SYS_EXIT` | `0x2000001` | `60` |
| `O_CREAT` | `0x0200` | `0x40` |
| `O_TRUNC` | `0x0400` | `0x200` |

macOS ORs every syscall number with `0x2000000` (BSD class). Linux uses the numbers directly.

### `include/bitpads.inc` — System Constants block only

The `SYS_*` and `O_*` constants are duplicated in `bitpads.inc` (for files that include only this header). Updated to match Linux values. All protocol constants below line 18 are unchanged.

### `src/main.asm` — entry point and argv ABI

| | macOS | Linux |
|--|-------|-------|
| Entry symbol | `_main` (called by runtime) | `_start` (kernel entry, no caller) |
| `argc` source | `rdi` (passed by runtime) | `[rsp]` (placed by kernel) |
| `argv` source | `rsi` (passed by runtime) | `[rsp+8]` (placed by kernel) |
| Frame setup | `push rbp / mov rbp, rsp` | None — no return address on stack |

Stack alignment: the Linux kernel guarantees rsp is 16-byte aligned at `_start`. Two register pushes (`rbx`, `r12`) maintain alignment before the first `call`.

### `src/io/fileio.asm` — error detection after syscalls

The macOS BSD kernel sets the carry flag (CF) on syscall error. Linux does not — it returns a negative value in `rax` (the errno negated).

Every `jc` error check replaced with `test rax, rax` / `js`:

| Location | macOS | Linux |
|----------|-------|-------|
| After `open()` | `jc .open_error` | `test rax,rax` / `js .open_error` |
| After `write()` | `jc .write_error` | `test rax,rax` / `js .write_error` |
| After `close()` | `jc .close_error` | `test rax,rax` / `js .close_error` |

### `Makefile`

| | macOS | Linux |
|--|-------|-------|
| NASM format | `-f macho64` | `-f elf64` |
| Linker flags | `-macosx_version_min 12.0 -L$(xcrun ...) -lSystem` | `-e _start` |

---

## What Was NOT Changed

All 21 protocol source files are direct copies — no modifications:

- `src/crypto/crc15.asm`
- `src/layers/` — meta1, meta2, layer1, layer2, layer3
- `src/components/` — setup, value, time_comp, task, note
- `src/enhancement/` — c0gram, signals, cmd1100, ctx1101, tel1110
- `src/builders/` — build_signal, build_wave, build_record, build_ledger
- `src/cli_parse.asm`, `src/dispatch.asm`
- `include/macros.inc`

These files contain only x86-64 arithmetic, bitwise operations, and register manipulation — fully portable across macOS and Linux.
