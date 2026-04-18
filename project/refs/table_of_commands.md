# BitPads CLI Reference

## Required

| Flag | Description |
|------|-------------|
| `--type <signal\|wave\|record\|ledger\|telem>` | Transmission frame type. Determines the builder and required fields. |
| `--out <file>` | Output file path. Required unless `--dry-run`, `--hex`, or `--hex-raw` is set. |

---

## Layer 1 — Session Header
Present in `record` and `ledger` frames.

| Flag | Description |
|------|-------------|
| `--sender <hex32>` | 32-bit sender node ID in hex (e.g. `0xDEADBEEF`). Packed into bits 13–44 of the Layer 1 header. |
| `--domain <fin\|eng\|hybrid\|custom>` | Protocol domain. Encoded in bits 3–4. Default: `fin`. |
| `--perms <0-15>` | 4-bit permission field: Read / Write / Correct / Proxy flags. Default: `0`. |
| `--subentity <0-31>` | 5-bit sub-entity or department ID. Bits 45–49. Default: `0`. |
| `--split <0-2>` | Sender ID split mode. Controls how the 32-bit ID is divided across receiver roles. |
| `--enhance` | Enables Session Enhancement Flag (bit 12). Activates C0 grammar and all 13 signal positions for the session. |

---

## Layer 2 — Batch Context Header
Added to the frame when `--layer2` is passed.

| Flag | Description |
|------|-------------|
| `--layer2` | Include the 6-byte Layer 2 batch context header. Required for all L2 sub-fields below. |
| `--txtype <pre\|copy\|rep\|0\|1\|2>` | Transmission type. `pre`/`0` = pre-converted, `copy`/`1` = raw copy, `rep`/`2` = represented. Default: `pre`. |
| `--bells <0-3>` | Enquiry/acknowledge bell count. Encoded in byte[2] bits 7–6. |
| `--sep-group <0-63>` | Group separator counter (6-bit). Number of group separators preceding this batch. |
| `--sep-record <0-31>` | Record separator counter (5-bit). |
| `--sep-file <0-7>` | File separator counter (3-bit). |
| `--currency <0-63>` | 6-bit currency or physical quantity type code. |
| `--round-bal <0-15>` | 4-bit rounding balance accumulator for the batch. |
| `--compound-max <none\|3\|7\|unlim\|0-3>` | Ceiling on compound groups in this batch. `none` = compound disallowed (1111 pair is a protocol error). |

---

## Layer 3 — BitLedger Record
`ledger` frames only.

| Flag | Description |
|------|-------------|
| `--acct <0-15>` | Account pair code. Identifies the double-entry account relationship (e.g. `1` = Debtor/Creditor). `15` (1111) is the compound continuation marker and requires `--compound`. |
| `--dir <0-3>` | Direction of the entry within the account pair. |
| `--complete` | Sets the Completeness bit. `1` = partial record, more compound frames follow. |
| `--compound` | Enables compound mode. Required to use account pair `0x0F` (1111) as a continuation marker. Promotes `--compound-max` from `none` to `unlim` if unset. |
| `--l3-ext <hex8>` | Appends a 1-byte Layer 3 extension payload after the standard 5-byte Layer 3 block. |

---

## Frame Control — Meta Byte 1

| Flag | Description |
|------|-------------|
| `--ack` | Request acknowledgement from receiver. Wave: ACK Request bit. Record: System Context Extension flag. |
| `--cont` | Mark this frame as a fragment. Receiver accumulates until a frame with `--cont` absent arrives. |
| `--prio` | Elevated priority flag (Wave Role A). Receiver processes before lower-priority frames. |
| `--category <0-15>` | Role B category code. Switches Wave Meta Byte 1 to category mode. `12`=Compact Command, `13`=Context Decl, `14`=Telegraph. |

---

## Meta Byte 2

| Flag | Description |
|------|-------------|
| `--archetype <0-15>` | 4-bit archetype or sub-type field in the upper nibble of Meta Byte 2. Used for archetype stream records. |
| `--time-tier <0-3>` | Time reference selector. `1`=Tier1 session offset, `2`=Tier1 external, `3`=Tier2 block. Encoded in bits 5–6. |

The Setup Byte (Meta Byte 2 bit 7) is inserted automatically when `--tier`, `--sf`, or `--dp` deviate from session defaults (T3, x1, 2dp). No explicit flag.

---

## Value Block

| Flag | Description |
|------|-------------|
| `--value <uint32>` | Numeric value to encode. Presence of this flag includes the value block in the frame. |
| `--tier <1-4>` | Value encoding tier: `1`=8-bit, `2`=16-bit, `3`=24-bit (default), `4`=32-bit. |
| `--sf <0-3>` | Scaling factor index: `0`=×1, `1`=×1,000, `2`=×1,000,000, `3`=×1,000,000,000. |
| `--dp <0\|2\|4\|6>` | Decimal position: number of implied decimal places. Default: `2`. |

---

## Time Field

| Flag | Description |
|------|-------------|
| `--time <0-255>` | 8-bit Tier 1 timestamp value. Sets time presence and defaults `--time-tier` to `1` if unset. |
| `--time-ext <0-65535>` | 16-bit Tier 2 extended timestamp. Automatically sets `--time-tier 3` and marks time present. |

---

## Task Block

| Flag | Description |
|------|-------------|
| `--task <hex8>` | Raw task control byte. Sets task presence directly; overrides `--task-code` bit field. |
| `--task-code <0-63>` | 6-bit task operation code. Packed into bits 6–1 of the task byte. |
| `--task-target <0-255>` | Target entity byte appended after the task byte. Sets bit 7 of the task byte. |
| `--task-timing <0-255>` | Timing offset byte appended after the task byte (and target byte if present). Sets bit 0 of the task byte. |

---

## Note Block

| Flag | Description |
|------|-------------|
| `--note <text>` | UTF-8 note string, up to 63 bytes. Stored inline in the frame after other components. |

---

## Compact Command Payload
Requires `--category 12` on a `wave` frame.

| Flag | Description |
|------|-------------|
| `--cmd-class <0-15>` | Command class in upper nibble of the command byte (e.g. `0`=Lifecycle, `1`=Query, `2`=Configure). |
| `--cmd-params <0-3>` | Parameter count code: `0`=none, `1`=one, `2`=two, `3`=variable. |
| `--cmd-p1 <0-255>` | First parameter byte. Written when `--cmd-params` ≥ 1. |
| `--cmd-p2 <0-255>` | Second parameter byte. Written when `--cmd-params` = 2 or variable. |
| `--cmd-resp` | Sets the Response Required bit in the command byte. |
| `--cmd-chain` | Sets the Chained bit — another command follows in the same session. |

---

## Telegraph Payload
Used by `--type telem` (auto-selects category 14) or explicitly with `--category 14` on a `wave` frame.

| Flag | Description |
|------|-------------|
| `--tel-type <status\|value\|command\|identity\|text\|heartbeat\|priority\|extended>` | Message type encoded in bits 7–5 of the telegraph header byte. |
| `--tel-data <0-31>` | 5-bit inline payload in bits 4–0. Meaning is type-specific: status code, sequence number, opcode, sub-entity, text length, or priority code. |

For `--tel-type text`, pass `--note <string>` to supply the free-text payload bytes.

---

## Signal Slots
Require `--enhance` to be set at the session level.

| Flag | Description |
|------|-------------|
| `--slot-p4 <hex8>` | Signal byte for position P4 (fires before the value block in a record). |
| `--slot-p5 <hex8>` | Signal byte for position P5 (fires after the value block). |
| `--slot-p6 <hex8>` | Signal byte for position P6 (fires after the time field). |
| `--slot-p7 <hex8>` | Signal byte for position P7 (fires after the task block). |
| `--slot-p8 <hex8>` | Signal byte for position P8 (fires after the record body, post-note). |

Providing any slot flag automatically sets the Signal Slot Presence byte in the output.

---

## Output Control

| Flag | Description |
|------|-------------|
| `--dry-run` | Assemble the frame but do not write any output. Useful for validation. `--out` is not required. |
| `--hex` | Write raw frame bytes to stdout instead of a file. `--out` is not required. |
| `--hex-raw` | Same as `--hex`. Identical routing through `fileio_write_stdout`. |
| `--trace` | After writing the output file, also emit a hex dump of the frame to that file's trace channel. |
| `--print-size` | Suppress the success message. Intended for scripting where only byte count matters. |
| `--count <1-255>` | Repeat the frame build and write N times. Useful with `--hex-raw` or `--dry-run`; note that file mode truncates on each write. |
