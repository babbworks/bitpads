# BitPads CLI

A command-line frame assembler for the BitPads Protocol v2. Accepts structured flags describing a transmission, assembles the binary frame according to protocol rules, and writes the result to a file, stdout, or discards it in dry-run mode.

Written entirely in x86-64 NASM assembly. Targets macOS (Intel native or Rosetta 2 on Apple Silicon).

---

## Requirements

- macOS 12.0 or later
- NASM (Netwide Assembler)
- Xcode Command Line Tools (provides `ld` and the system SDK)

Install NASM via Homebrew if needed:

```
brew install nasm
```

---

## Build

```
make
```

The binary is placed at `./bitpads`. Object files are written alongside their source files. Clean with `make clean`.

---

## Usage

```
./bitpads --type <frame-type> [flags] --out <file>
```

`--type` and `--out` are required unless `--dry-run`, `--hex`, or `--hex-raw` is specified in place of `--out`.

Flags may appear in any order. Dependencies between flags are enforced at parse time — for example, `--layer2` must be present before any `--sep-*`, `--bells`, or `--currency` flags have effect, and `--enhance` must be present before any `--slot-*` flags are accepted.

---

## Frame Types

| Type | Description | Min Size |
|------|-------------|----------|
| `signal` | Single-byte null signal. No Layer 1. | 1 byte |
| `wave` | Lightweight push frame. No Layer 1 unless category demands it. | 2 bytes |
| `record` | Full structured record. Layer 1 required. | 10 bytes |
| `ledger` | Double-entry bookkeeping frame. Layer 1 + Layer 3 required. | 15 bytes |
| `telem` | Telemetry shorthand. Wave framing, Engineering domain, Telegraph category auto-set. | 3 bytes |

---

## Output Modes

| Flag | Behavior |
|------|----------|
| `--out <file>` | Write binary frame to file. File is created or truncated. |
| `--dry-run` | Assemble and validate the frame; write nothing. |
| `--hex` | Write raw frame bytes to stdout. |
| `--hex-raw` | Identical to `--hex`. |
| `--trace` | After writing the output file, also emit a hex dump to that file's trace channel. |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Argument error — required flag missing or value out of range |
| `2` | Protocol build error — compound marker without Layer 2, or similar |

---

## Examples

Minimal record, dry-run:
```
./bitpads --type record --sender 0x1 --dry-run
```

Record with value and 8-bit encoding:
```
./bitpads --type record --sender 0xDEADBEEF --value 42 --tier 1 --out /tmp/out.bp
```

Wave with compact command:
```
./bitpads --type wave --category 12 --cmd-class 2 --cmd-params 1 --cmd-p1 0xFF --hex
```

Telemetry heartbeat:
```
./bitpads --type telem --tel-type heartbeat --tel-data 1 --out /tmp/hb.bp
```

Ledger compound continuation:
```
./bitpads --type ledger --sender 0x1 --layer2 --compound --compound-max unlim --acct 15 --dir 0 --out /tmp/cont.bp
```

Repeat frame assembly three times in dry-run:
```
./bitpads --type record --sender 0x1 --value 1 --tier 1 --count 3 --dry-run
```

---

## Documentation

| File | Contents |
|------|----------|
| `table_of_commands.md` | Complete flag reference with descriptions, organized by section |
| `test_runs/testrun1.md` | 25 annotated command runs with hex output and protocol explanation |
| `guides/CLI_GUIDE.md` | Narrative usage guide |
| `guides/PROTOCOL_AND_REGISTERS.md` | Protocol and register reference |
