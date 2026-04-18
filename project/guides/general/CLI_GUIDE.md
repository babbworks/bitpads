# BitPads CLI — Usage Guide and Expansion Reference

This document covers what the CLI currently does, how to invoke every frame type, and what
remains unexposed from the BitPads and BitLedger protocols that could be added.

---

## Part 1 — Current CLI

### Strict validation mode

Newly added advanced flags now fail fast on invalid ranges or inconsistent combinations.
Examples:

- `--currency` must be `0..63`
- `--round-bal` must be `0..15`
- `--sep-group` must be `0..63`, `--sep-record` `0..31`, `--sep-file` `0..7`
- `--archetype` must be `0..15`
- `--time-ext` must be `0..65535` and implies Tier-2 time
- `--task-code` must be `0..63`
- `--tel-data` must be `0..31`

Unknown flags are now treated as parse errors instead of being silently ignored.

### Invocation

```
bitpads --type <signal|wave|record|ledger> --out <file> [options]
```

`--out` is the only truly required flag. `--type` defaults to `wave` if omitted.
Exit codes: `0` = success, `1` = argument error, `2` = build/protocol error.

A `--trace` flag on any invocation writes a parallel `.trace` human-readable hex dump alongside
the binary output file.

---

### Frame types and what they build

#### `--type signal` — Pure Signal (1 byte)

The smallest possible BitPads transmission. The entire payload is one C0-encoded byte:
bits 7-5 carry flags (Priority, ACK, Continuation) and bits 4-0 carry the C0 identity (0-31).

Relevant flags:
```
--category <0-31>    C0 identity code (which C0 control character this signal represents)
--prio               set Priority flag (bit 7)
--ack                set ACK Request flag (bit 6)
--cont               set Continuation flag (bit 5) — signals more bytes follow
--out <file>         output file
```

Example — SOH signal with priority:
```
bitpads --type signal --category 1 --prio --out soh.bp
```

---

#### `--type wave` — Wave Frame (2-6 bytes typical)

A lightweight push frame. No Layer 1 session header, no Layer 3 ledger record. Fastest to
construct; used for sensor readings, status pushes, and data with implicit session context.

Frame layout (in byte order):
```
[0]        Meta Byte 1   — Wave mode, ACK/CONT/PRIO flags, Role/category
[1]        Meta Byte 2   — archetype, time selector, setup flag, slot flag
[optional] SSP byte      — signal slot presence (if --enhance + signal slots active)
[optional] Setup byte    — value tier/SF/DP overrides (if --setup)
[optional] Time field    — 1 or 2 bytes (if --time)
[payload]  Category-routed payload:
             --category 12 (0x0C)  → Compact Command  (cmd1100)
             --category 13 (0x0D)  → Context Declaration (ctx1101)
             --category 14 (0x0E)  → Telegraph (tel1110)
             anything else         → plain value (value_encode, 1-4 bytes per tier)
```

Common examples:

```
# Minimal wave: value 42, no extras
bitpads --type wave --value 42 --out reading.bp

# Wave with Tier 2 value (2 bytes), scaling x1k, 2 decimal places, financial domain
bitpads --type wave --value 9875 --tier 2 --sf 1 --dp 2 --domain fin --out price.bp

# Wave with a timestamp (Tier 1 session offset = 15)
bitpads --type wave --value 100 --time 15 --out timestamped.bp

# Wave with setup byte override and priority
bitpads --type wave --value 500 --setup --prio --out alert.bp

# Wave with Compact Command enhancement (category 1100)
bitpads --type wave --category 12 --enhance --out command.bp

# Wave with Context Declaration (category 1101)
bitpads --type wave --category 13 --enhance --out ctx_decl.bp

# Wave with ACK requested and continuation
bitpads --type wave --value 1 --ack --cont --out part1.bp
```

---

#### `--type record` — Full Record Frame (12-21 bytes typical)

The primary structured transmission. Always includes Layer 1 (8-byte session header) plus the
optional-block body: value, time, task, and note in that order.

Frame layout:
```
[8 bytes]  Layer 1       — SOH, version, domain, permissions, sender ID, CRC-15
[6 bytes]  Layer 2       — batch context (only if --layer2)
[1 byte]   Meta Byte 1   — Record mode (bit7=1), SysCtx, Role C block flags
[1 byte]   Meta Byte 2   — archetype, time selector, setup/slot flags
[optional] SSP byte
[optional] P4 signal     (pre-value)
[optional] Setup byte
[optional] Value block   1-4 bytes (if --value)
[optional] P5 signal     (post-value)
[optional] Time field    0-2 bytes (if --time)
[optional] P6 signal     (post-time)
[optional] Task block    1-3 bytes (if --task)
[optional] P7 signal     (post-task)
[optional] Note block    1-64 bytes (if --note)
[optional] P8 signal     (post-record)
```

Examples:

```
# Minimal record: just Layer 1 + meta bytes, no optional blocks
bitpads --type record --sender 0xDEAD0001 --out bare.bp

# Full record with value, time, task, and note
bitpads --type record \
  --sender 0xABCD1234 \
  --domain fin \
  --value 15000 --tier 3 --sf 0 --dp 2 \
  --time 42 \
  --task 0x81 \
  --note "quarterly settlement" \
  --out full_record.bp

# Record with Layer 2 batch context and sub-entity
bitpads --type record \
  --sender 0x00000001 \
  --layer2 \
  --subentity 5 \
  --value 999 \
  --out batch_rec.bp

# Record with permissions (read=1 write=1 corr=0 proxy=0 → 0xC = 1100)
bitpads --type record --sender 0x00000001 --perms 12 --out perms.bp

# Record with split mode (0=none, 1=split-a, 2=split-b)
bitpads --type record --sender 0x00000001 --split 1 --out split.bp

# Record with trace dump
bitpads --type record --sender 0x00000001 --value 100 --out rec.bp --trace
```

---

#### `--type ledger` — BitLedger Frame (28+ bytes)

A full double-entry accounting record. Extends the Record frame with Layer 3: a 5-byte account
routing block that carries the account pair code, direction, and completeness flag.

Frame layout:
```
[8 bytes]  Layer 1       — Session Header
[6 bytes]  Layer 2       — Batch Context (if --layer2)
[5 bytes]  Layer 3       — account pair, direction, completeness, extension
[rest]     same optional blocks as Record (meta bytes, value, time, task, note, signals)
```

The account pair code selects the double-entry routing (e.g. `1` = Debtor/Creditor,
`15` / `0x0F` = compound continuation marker which requires `--compound`).

Examples:

```
# Basic ledger entry: Debtor/Creditor pair, debit direction
bitpads --type ledger \
  --sender 0x00000001 \
  --acct 1 \
  --dir 0 \
  --value 5000 --tier 2 --dp 2 \
  --out debit.bp

# Credit side of the same entry
bitpads --type ledger \
  --sender 0x00000001 \
  --acct 1 \
  --dir 1 \
  --value 5000 --tier 2 --dp 2 \
  --out credit.bp

# Compound entry — Frame 1: normal pair with completeness flag
bitpads --type ledger \
  --sender 0x00000001 \
  --acct 1 --dir 0 \
  --complete \
  --value 5000 \
  --out compound_frame1.bp

# Compound entry — Frame 2: continuation marker (pair 0x0F = 1111)
bitpads --type ledger \
  --sender 0x00000001 \
  --acct 15 \
  --compound \
  --out compound_frame2.bp

# Ledger with time block and note
bitpads --type ledger \
  --sender 0xCAFE0001 \
  --acct 1 --dir 0 \
  --value 12500 --tier 3 --dp 2 \
  --time 100 \
  --note "annual audit adjustment" \
  --out audit.bp
```

---

#### `--type telem` — Telemetry (Wave framing, Engineering domain)

Uses the Wave builder but forces `BP_DOMAIN_ENG` if you haven't set `--domain` explicitly.
Intended for sensor/telemetry use cases that need to signal engineering context without
requiring you to remember `--domain eng` every time.

```
bitpads --type telem --category 14 --enhance --value 2048 --out sensor.bp
```

---

### Complete flag reference

| Flag | Argument | Field set | Notes |
|---|---|---|---|
| `--type` | `signal\|wave\|record\|ledger` | `BP_CTX_TYPE` | Defaults to `wave` |
| `--domain` | `fin\|eng\|hybrid\|custom` | `BP_CTX_DOMAIN` | Defaults to `fin` |
| `--sender` | hex32 (e.g. `0xDEAD1234`) | `BP_CTX_SENDER_ID` | 32-bit session sender ID |
| `--subentity` | 0-31 | `BP_CTX_SUB_ENTITY` | Sub-entity within the sender |
| `--category` | 0-15 | `BP_CTX_CATEGORY` | Wave payload category; 12/13/14 = enhancement modes |
| `--value` | uint32 | `BP_CTX_VALUE` | Numeric payload; sets value-present flag |
| `--tier` | 1-4 | `BP_CTX_VALUE_TIER` | Byte width: T1=1, T2=2, T3=3, T4=4 |
| `--sf` | 0-3 | `BP_CTX_SF_INDEX` | Scale: 0=×1, 1=×1k, 2=×1M, 3=×1B |
| `--dp` | 0/2/4/6 | `BP_CTX_DP` | Decimal places |
| `--time` | 0-255 | `BP_CTX_TIME_VAL` | Timestamp value; sets time-present flag; defaults to Tier 1 |
| `--time-tier` | 0-3 | `BP_CTX_TIME_TIER` | 0=none, 1=T1 session offset, 2=T1 external, 3=T2 |
| `--task` | hex8 | `BP_CTX_TASK_BYTE` | Task control byte; sets task-present flag |
| `--note` | string | `BP_CTX_NOTE_DATA` | Up to 63 bytes of text; sets note-present flag |
| `--acct` | 0-15 | `BP_CTX_ACCT_PAIR` | Ledger account pair code |
| `--dir` | 0-3 | `BP_CTX_DIRECTION` | Entry direction (0=debit, 1=credit, etc.) |
| `--compound` | _(flag)_ | `BP_CTX_COMPOUND` | Enable compound continuation mode |
| `--complete` | _(flag)_ | `BP_CTX_COMPLETENESS` | Mark record as partial/complete |
| `--ack` | _(flag)_ | `BP_CTX_ACK_REQ` | Request acknowledgement |
| `--cont` | _(flag)_ | `BP_CTX_CONT` | Continuation flag (more frames follow) |
| `--prio` | _(flag)_ | `BP_CTX_PRIO` | Priority flag |
| `--layer2` | _(flag)_ | `BP_CTX_LAYER2_PRES` | Include Layer 2 batch context header |
| `--setup` | _(flag)_ | via Meta2 | Include setup byte (tier/SF/DP override in-frame) |
| `--enhance` | _(flag)_ | `BP_CTX_ENHANCEMENT` | Enable enhancement grammar (C0 signal encoding) |
| `--perms` | 0-15 | `BP_CTX_PERMISSIONS` | 4-bit permissions field in Layer 1 |
| `--split` | 0-2 | `BP_CTX_SPLIT_MODE` | Split mode: 0=none, 1=A, 2=B |
| `--txtype` | `pre\|copy\|rep\|0\|1\|2` | `BP_CTX_L2_TXTYPE` | Layer2 tx type |
| `--compound-max` | `none\|3\|7\|unlim\|0-3` | `BP_CTX_COMPOUND_MAX` | Layer2 compound ceiling |
| `--currency` | 0-63 | `BP_CTX_L2_CURRENCY` | Layer2 currency/qtype code |
| `--round-bal` | 0-15 | `BP_CTX_L2_ROUND_BAL` | Layer2 rounding accumulator |
| `--sep-group` | 0-63 | `BP_CTX_L2_GROUP_SEP` | Layer2 separator field |
| `--sep-record` | 0-31 | `BP_CTX_L2_REC_SEP` | Layer2 separator field |
| `--sep-file` | 0-7 | `BP_CTX_L2_FILE_SEP` | Layer2 separator field |
| `--archetype` | 0-15 | `BP_CTX_ARCHETYPE` | Meta2 archetype nibble |
| `--time-ext` | 0-65535 | `BP_CTX_TIME_EXT` | Full Tier-2 time value |
| `--task-code` | 0-63 | `BP_CTX_TASK_BYTE` | Named task code helper |
| `--task-target` | 0-255 | `BP_CTX_TASK_BYTE+1` | Task target byte + bit7 |
| `--task-timing` | 0-255 | `BP_CTX_TASK_BYTE+2` | Task timing byte + bit0 |
| `--slot-p4..--slot-p8` | hex8 | `BP_CTX_SIGNALS` + SSP bits | Per-record signal slots |
| `--l3-ext` | hex8 | `BP_CTX_L3_EXT(_BYTE)` | Layer3 extension marker byte |
| `--cmd-class` | 0-15 | `BP_CTX_TASK_BYTE` high nibble | cmd1100 semantic helper |
| `--cmd-params` | 0-3 | `BP_CTX_TASK_BYTE` bits3-2 | cmd1100 parameter count |
| `--cmd-p1` | 0-255 | `BP_CTX_TASK_BYTE+1` | cmd1100 param 1 |
| `--cmd-p2` | 0-255 | `BP_CTX_TASK_BYTE+2` | cmd1100 param 2 |
| `--cmd-resp` | _(flag)_ | `BP_CTX_TASK_BYTE` bit1 | cmd1100 response required |
| `--cmd-chain` | _(flag)_ | `BP_CTX_TASK_BYTE` bit0 | cmd1100 chained command |
| `--tel-type` | status/value/command/identity/text/heartbeat/priority/extended | `BP_CTX_TASK_BYTE` type bits | tel1110 semantic helper |
| `--tel-data` | 0-31 | `BP_CTX_TASK_BYTE` low 5 bits | tel1110 inline payload |
| `--dry-run` | _(flag)_ | `BP_CTX_OUTMODE` | Build but do not write file |
| `--hex` | _(flag)_ | `BP_CTX_OUTMODE` | Write frame bytes to stdout |
| `--hex-raw` | _(flag)_ | `BP_CTX_OUTMODE` | Write raw frame bytes to stdout |
| `--print-size` | _(flag)_ | `BP_CTX_PRINT_SIZE` | Suppress success banner for scripted output |
| `--count` | 1-255 | `BP_CTX_COUNT` | Repeat dispatch N times |
| `--out` | filename | `BP_CTX_OUTFILE` | Output file path (required) |
| `--trace` | _(flag)_ | `BP_CTX_HEX_TRACE` | Also write a `.trace` annotation file |

---

## Part 2 — What Could Be Added

The following covers every protocol feature that exists in the spec but is not yet exposed or
is only partially reachable through the current CLI. Ordered roughly from most immediately useful
to most architecturally involved.

---

### 1. Signal slot data — `--slot-p4` through `--slot-p8`

**What's missing:** You can trigger the SSP byte (via `--enhance` and the signals infrastructure)
but there is no way to set the *content* of individual signal slots. `BP_CTX_SIGNALS` (16 bytes
at offset 165) holds slot data but no flag populates it.

**What to add:**
```
--slot-p4 <hex8>     set the encoded C0 byte for signal slot P4 (pre-value)
--slot-p5 <hex8>     P5 (post-value)
--slot-p6 <hex8>     P6 (post-time)
--slot-p7 <hex8>     P7 (post-task)
--slot-p8 <hex8>     P8 (post-record)
```

Each slot flag would write the encoded C0 byte into the corresponding position in
`BP_CTX_SIGNALS` and set the matching bit in `BP_CTX_SIGNAL_SLOTS`. This unlocks the full
interleaved-signal capability of the record body.

---

### 2. Task block sub-fields — `--task-target` and `--task-timing`

**What's missing:** `--task <hex8>` sets the task control byte (which has `BP_TASK_TARGET`
bit 7 and `BP_TASK_TIMING` bit 0 as presence flags) but provides no way to set the actual
target entity value or timing offset that follow when those bits are set.

**What to add:**
```
--task-flags <hex8>      the task control byte (replaces --task, more explicit name)
--task-target <uint8>    target entity byte (written if bit 7 of task control is set)
--task-timing <uint8>    timing offset byte (written if bit 0 of task control is set)
```

The task builder already reads from `BP_CTX_TASK_BYTE + 1` and `BP_CTX_TASK_BYTE + 2`
(the three-byte task data area) — the CLI just needs flags to populate those positions.

---

### 3. Compound entry helper — `--compound-pair`

**What's missing:** Generating a compound entry currently requires two separate invocations
with careful manual coordination (Frame 1: normal pair + `--complete`; Frame 2: pair 15 +
`--compound`). There is no compound-aware mode that validates the pairing.

**What to add:**
```
--compound-pair <file1> <file2>
```

A meta-mode that builds both frames in one invocation, enforcing the protocol contract (pair
1111 on the second frame is only valid when compound mode is set, and both frames must share a
sender ID). This would call `build_ledger` twice, writing to two separate output files.
Alternatively, a `--out2 <file>` flag for the continuation frame alongside `--compound`.

---

### 4. Layer 2 field control

**What's missing:** `--layer2` includes the Layer 2 header but the six bytes it writes come
entirely from defaults already in the ctx (TX type, SF index, DP, separator, currency code).
The existing `--sf` and `--dp` flags do feed into Layer 2, but there is no way to set the
**currency code** or **separator code** fields that Layer 2 carries.

**What to add:**
```
--currency <uint8>       currency/commodity code for Layer 2 (e.g. ISO 4217 compressed)
--separator <uint8>      separator/formatting code for Layer 2 batch context
```

These fields matter when Layer 2 is used to declare a batch context that will be inherited by
multiple subsequent Wave or Record frames.

---

### 5. Stdin / pipe input — `--stdin`

**What's missing:** Every argument must be passed on the command line. This is fine for direct
use but awkward for scripted pipelines where an agent generates many transmissions.

**What to add:**
```
--stdin      read one set of flag arguments per line from stdin instead of argv
```

Each line would be tokenized and parsed by the same `streq`/`parse_uint32` logic. This allows:

```bash
# Agent generates a batch file, CLI consumes it
generate_transmissions.py | bitpads --stdin
```

Requires a line-reader (a new `read_line` function calling the `SYS_READ` syscall into a
scratch buffer) and a tokenizer that splits on spaces — both straightforward additions in NASM.

---

### 6. Frame size reporting — `--print-size`

**What's missing:** After a successful build, the CLI prints only "transmission written
successfully." The actual byte count of the written frame is discarded.

**What to add:**
```
--print-size     print "<n> bytes written to <file>" to stdout after success
```

The byte count is already in `r12d` at the end of each builder. Passing it back through
`dispatch_build` to `main.asm` (e.g. via a global or a returned struct) and formatting it as
decimal ASCII using a small `uint32_to_ascii` helper would give immediate feedback useful for
protocol debugging and scripting.

---

### 7. Validation mode — `--dry-run`

**What's missing:** There is no way to check whether a set of flags would produce a valid frame
without actually writing a file.

**What to add:**
```
--dry-run    assemble the frame in memory, validate it, report size/structure — no file written
```

Implementation: skip the `fileio_write` call and instead write a summary to stdout. This is
particularly useful for compound entries, where the validation of the pair-1111 rule happens
inside `layer3_build` and currently results in a hard error with no recovery path.

---

### 8. Hex output to stdout — `--hex`

**What's missing:** `--trace` writes a parallel annotation file. There is no way to get the raw
hex of the frame on stdout for piping to other tools.

**What to add:**
```
--hex        write the assembled frame as a hex string to stdout (no binary file)
--hex-raw    write the raw binary frame to stdout (for piping, no file at all)
```

`--hex-raw` combined with shell redirection covers the same cases as `--out` but enables
pipelines like `bitpads ... --hex-raw | xxd` without a temporary file.

---

### 9. Multiple frames in one invocation — `--count <n>`

**What's missing:** There is no repeat mode. Generating N identical frames requires N shell
invocations.

**What to add:**
```
--count <n>      write N copies of the frame, appended to the output file
--count <n> --out-dir <dir>   write N frames as separate numbered files
```

Useful for generating test sequences, bulk signal transmissions, or simulating a stream of
sensor readings.

---

### 10. Enhancement category sub-fields

**What's exposed via `--category`:**
- `12` (1100) → Compact Command: `cmd1100_build` is called but has no CLI-accessible sub-fields
- `13` (1101) → Context Declaration: `ctx1101_build` is called but its epoch/task fields are
  populated from the same ctx fields as the main record (not separately addressable)
- `14` (1110) → Telegraph: `tel1110_build` produces a telegraph payload from ctx fields

**What to add:**

For category 1100 (Compact Command):
```
--cmd-code <0-255>      command code byte for the Compact Command payload
--cmd-arg <uint32>      optional argument for the command
```

For category 1101 (Context Declaration):
This already reads `BP_CTX_TASK_BYTE` and time fields from the ctx — so `--task` and `--time`
partially work. But the Context Declaration has its own epoch field and task presence encoding
that is distinct from the record body's task block. A `--ctx-epoch <uint32>` flag would let
you set the 32-bit epoch value it carries directly.

For category 1110 (Telegraph):
```
--tel-code <0-255>      telegraph category/code byte
--tel-payload <hex>     raw hex bytes for the telegraph body (up to protocol limit)
```

---

### 11. Archetype code — `--archetype`

**What's missing:** Meta Byte 2 carries an archetype code (bits 7-4, a 4-bit field that
classifies the record's semantic type within its domain). The current code uses a default
archetype of 0. There is no CLI flag to set it.

**What to add:**
```
--archetype <0-15>      4-bit archetype code written into Meta Byte 2
```

Example archetypes in the financial domain might distinguish spot transactions, adjustments,
fees, and corrections. Setting this field makes the frame machine-classifiable without reading
deeper into the payload.

---

### 12. CRC-15 bypass / manual CRC — `--crc <hex16>`

**What's missing:** Layer 1 always has CRC-15 computed automatically by `crc15.asm`. For
testing parsers, you may want to deliberately write a frame with a known-bad CRC.

**What to add:**
```
--crc <hex16>      override the computed CRC-15 with a specific value (testing only)
--no-crc           write zero in the CRC field (for minimal test frames)
```

---

### 13. Tier 2 time block — `--time-ext <hex16>`

**What's missing:** `--time-tier 3` selects Tier 2 time (2-byte external timestamp) but
`--time` only takes an 8-bit value. The second byte of the Tier 2 time block is not settable.

**What to add:**
```
--time-ext <uint16>     full 16-bit Tier 2 time block value (replaces --time when --time-tier 3)
```

---

### 14. Script file input — `--script <file>`

A natural extension of `--stdin`: read a file where each line is a complete bitpads invocation
(flags only, no `bitpads` prefix), execute each in sequence, and report per-line results.

```
# transmissions.bps
--type wave --value 100 --out t1.bp
--type wave --value 200 --out t2.bp
--type ledger --sender 0x1 --acct 1 --dir 0 --value 500 --out l1.bp
```

```
bitpads --script transmissions.bps
```

This is the agent-oriented mode: an LLM generates the script, the CLI executes it
deterministically.

---

### 15. Version and protocol info — `--version` / `--info`

```
--version      print the CLI version, NASM version used to build it, and protocol revision
--info         print a summary of all supported frame types, sizes, and flag count
```

Small quality-of-life additions that make the binary self-describing.

---

## Summary: gap table

| Protocol feature | Currently reachable | Missing |
|---|---|---|
| Signal (1 byte, C0) | ✓ full | — |
| Wave plain value | ✓ full | — |
| Wave with time | ✓ full | Tier 2 time (--time-ext) |
| Wave with setup byte | ✓ full | — |
| Wave enhancement categories 1100/1101/1110 | ✓ routed | Sub-field flags |
| Record Layer 1 | ✓ full | CRC override flag |
| Record Layer 2 batch context | ✓ presence flag | Currency, separator fields |
| Record value block | ✓ full | — |
| Record time block | ✓ Tier 1 | Tier 2 second byte |
| Record task block | ✓ control byte | Target/timing sub-fields |
| Record note block | ✓ full (63 bytes) | — |
| Signal slots P4-P8 | ✓ SSP byte emitted | Slot content bytes |
| Archetype code (Meta Byte 2 bits 7-4) | ✗ fixed at 0 | `--archetype` flag |
| Ledger Layer 3 | ✓ full | — |
| Compound entry (two-frame) | ✓ per-frame flags | Coordinated two-frame helper |
| Stdin / pipe input | ✗ | `--stdin` |
| Script file input | ✗ | `--script` |
| Frame size reporting | ✗ | `--print-size` |
| Dry-run validation | ✗ | `--dry-run` |
| Hex stdout | ✗ | `--hex` / `--hex-raw` |
| Repeat mode | ✗ | `--count` |
| Protocol/version info | ✗ | `--version` / `--info` |
