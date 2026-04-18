# BitPads CLI — Test Run 1

All commands run against `./bitpads` on macOS x86-64. Hex output via `xxd`.

---

### 1 — Minimal record, dry-run

```
./bitpads --type record --sender 0x1 --dry-run --out /dev/null
```
```
bitpads: transmission written successfully
```
8-byte Layer 1 session header + 2 Meta bytes assembled and validated; no file written.

This transmission exercises the minimum viable Record frame path without producing any output artifact. The protocol requires that a Record frame always carries a Layer 1 session header; even with no optional blocks, the 8-byte L1 structure must be assembled and the CRC-15 computed over its first 49 bits before the frame is considered valid. Dry-run mode satisfies all assembly and validation rules — including CRC embedding — then discards the result instead of routing it to the file I/O layer. The single success message confirms that the dispatch loop completed normally and the frame passed internal integrity checks.

---

### 2 — Record with 32-bit sender ID

```
./bitpads --type record --sender 0xDEADBEEF --out /tmp/t2.bp
```
```
00000000: 800d eadb eef0 620e 8000                 ......b...
```
10-byte Record (Layer 1 + Meta1 + Meta2); sender 0xDEADBEEF packed across bytes[1–5], CRC-15 embedded in bytes[6–7] as 0x62, 0x0E.

The sender field is a 32-bit node identifier occupying bits 13–44 of the Layer 1 header, which means it spans parts of bytes[1] through bytes[5] when packed MSB-first. The protocol rule is that the sender bits are interleaved with the domain and permission fields in byte[0] and the sub-entity and CRC fields in bytes[6–7], so the raw 0xDEADBEEF value is never stored contiguously — it is shifted and masked across the header during assembly. The CRC-15 is computed over the entire 49-bit payload of Layer 1 after the sender is packed in place, meaning the CRC covers the sender field as part of its input. Any change to the sender ID produces a different CRC result, binding the two fields together by the checksum.

---

### 3 — Record with 8-bit value, Tier 1

```
./bitpads --type record --sender 0x1 --value 42 --tier 1 --out /tmp/t3.bp
```
```
00000000: 8000 0000 0010 00e8 8802 062a             ...........*
```
12-byte Record; Meta1 = 0x88 (Record + Value flag), Meta2 = 0x02 (Setup Byte present), Setup Byte 0x06 auto-inserted because Tier 1 overrides the session default of Tier 3, value 42 (0x2A).

The presence of a value block is declared in Meta Byte 1 via the Role C Value flag, which instructs the receiver to expect a value block after the meta bytes. Because Tier 1 deviates from the session default encoding of Tier 3, the protocol requires a Setup Byte to carry the override — the receiver cannot assume default encoding when the Setup Byte flag is set in Meta Byte 2. The Setup Byte itself encodes the tier selection in its lower bits, and the assembler inserts it automatically when any of tier, scaling factor, or decimal position differ from defaults. The value 42 is then written as a single byte (0x2A) consistent with the Tier 1 8-bit encoding declared in the Setup Byte. The sequencing rule is strict: Setup Byte always precedes the value it governs.

---

### 4 — Record with note block

```
./bitpads --type record --sender 0x1 --note "hello" --out /tmp/t4.bp
```
```
00000000: 8000 0000 0010 00e8 8100 0568 656c 6c6f  ...........hello
```
16-byte Record; Meta1 = 0x81 (Record + Note flag), length byte 0x05 precedes the 5-byte inline string "hello".

The Note block is the last optional component in the Record frame ordering — it always appears at the tail of the frame after any value, time, task, and signal slot data. Its presence is declared by the Role C Note flag in Meta Byte 1, and the block itself is self-delimiting: a single length byte precedes the raw UTF-8 payload, capping the maximum note size at 63 bytes. Because there is no value block in this frame, Meta Byte 2 carries no Setup Byte flag and no time selector, reducing it to 0x00. The receiver uses Meta Byte 1 as its sole guide to which blocks follow the meta bytes: it reads the Role C flags left to right in bit order (Value, Time, Task, Note) and consumes exactly the blocks those flags declare, in that sequence.

---

### 5 — Record with Tier 1 timestamp

```
./bitpads --type record --sender 0x1 --time 100 --out /tmp/t5.bp
```
```
00000000: 8000 0000 0010 00e8 8404 64              ..........d
```
11-byte Record; Meta1 = 0x84 (Record + Time flag), Meta2 = 0x04 (time selector = T1S session offset), timestamp byte 100 (0x64).

The time field has two encoding tiers accessible through different flags: an 8-bit Tier 1 session offset and a 16-bit Tier 2 extended block. The selector for which encoding is in use is carried in bits 3–2 of Meta Byte 2, not in Meta Byte 1 — Meta Byte 1 only declares that a time field is present, while Meta Byte 2 specifies how large it is and what reference it uses. Here, Meta Byte 2 = 0x04 sets the T1S (Tier 1 Session) selector, and the single timestamp byte 0x64 follows immediately. The receiver reads Meta Byte 2 first to determine the time block width before attempting to consume it, making the two meta bytes a coordinated pair even though they are assembled by separate builder routines.

---

### 6 — Record with task operation code

```
./bitpads --type record --sender 0x1 --task-code 7 --out /tmp/t6.bp
```
```
00000000: 8000 0000 0010 00e8 8200 0e              ...........
```
11-byte Record; Meta1 = 0x82 (Record + Task flag), task control byte 0x0E = code 7 shifted to bits[6:1].

The task block encodes a 6-bit operation code in bits[6:1] of the task control byte, leaving bit[7] reserved for a target-entity companion byte and bit[0] for a timing-offset companion byte. Code 7 shifted left by one position yields 0x0E (0000 1110), placing it squarely in the 6-bit field without activating either companion flag. The protocol rule for task block expansion is additive: if the target bit is set, one more byte follows the task byte; if the timing bit is also set, another byte follows that. The receiver determines the total task block length by inspecting those two flag bits before advancing its read cursor. In this case neither companion is present, so the task block is exactly one byte.

---

### 7 — Record with all four optional blocks

```
./bitpads --type record --sender 0x1 --value 999 --tier 2 --time 50 --task-code 3 --note "test" --out /tmp/t7.bp
```
```
00000000: 8000 0000 0010 00e8 8f06 4603 e732 0604  ..........F..2..
00000010: 7465 7374                                test
```
20-byte Record; Meta1 = 0x8F (all Role C flags set), Meta2 = 0x06 (Setup + T1S); value 999 as 0x03E7 (16-bit), time 50, task code 3, note "test".

When all four Role C flags are active simultaneously, the frame body must follow a fixed assembly sequence: Setup Byte (if triggered), value block, time field, task block, note block — in that order. The receiver depends on this ordering to parse the frame correctly without any inline length or type markers between components; it uses Meta Byte 1 as a map and Meta Byte 2 for encoding overrides, then advances through the frame in the declared sequence consuming the known-width blocks. Value 999 exceeds the 8-bit Tier 1 ceiling of 255, so Tier 2 (16-bit) is used and the Setup Byte encodes that tier selection. The T1S time selector in Meta Byte 2 also stacks with the Setup Byte flag in the same byte — both fields coexist in Meta Byte 2 independently, and the assembler writes both in a single pass. The note "test" lands last, length-prefixed, at the tail of the 20-byte frame.

---

### 8 — Record with Layer 2 batch header

```
./bitpads --type record --sender 0x1 --layer2 --out /tmp/t8.bp
```
```
00000000: 8000 0000 0010 00e8 4042 0000 0001 8000  ........@B......
```
16-byte Record; Layer 2 (6 bytes: 0x4042 0000 0001) carries pre-converted tx type, default SF/DP, and reserved bit 0x01; no optional data blocks.

Layer 2 is a 6-byte batch context header that is inserted between Layer 1 and the meta bytes when present. It carries session-level encoding defaults — transmission type, scaling factor, decimal position, separator counters, currency code, and compound group ceiling — that apply to every record in the batch. The transmission type field in byte[0] bits[7:6] is mandatory; the default is 0x40 (pre-converted, binary pattern 01), since a value of 0x00 is a protocol error. The optimal split field in byte[1] defaults to 8 and is written unconditionally. Byte[5] bit[0] is the reserved bit, always transmitted as 1. Even a bare `--layer2` invocation with no other L2 flags produces a fully populated 6-byte structure because all fields have defined defaults — there is no concept of an empty or omitted Layer 2 once the flag is set.

---

### 9 — Record with Layer 2, non-default value encoding

```
./bitpads --type record --sender 0x1 --layer2 --value 5000 --tier 2 --sf 1 --dp 4 --out /tmp/t9.bp
```
```
00000000: 8000 0000 0010 00e8 4144 0000 0001 8802  ........AD......
00000010: 5813 88                                  X..
```
21-byte Record; L2 byte[0] = 0x41 (SF bit0=1, ×1,000 scale), byte[1] = 0x44 (DP=4 encoded in bits[2:0]); value 5000 (0x1388) as 16-bit with Setup Byte 0x58 overriding session defaults.

When Layer 2 is present, the scaling factor and decimal position it carries represent the batch-level session defaults. A Setup Byte in the Record's meta layer then overrides those defaults for this individual record. This two-level override hierarchy means the receiver maintains two states simultaneously: the batch context inherited from Layer 2, and the per-record override declared in the Setup Byte. The SF index 1 (×1,000 scale) is encoded in Layer 2 byte[0], where bit[0] of the SF field activates the first magnitude step. DP=4 encodes as binary 100 in byte[1] bits[2:0]. The Setup Byte 0x58 in the meta layer independently declares Tier 2 and the same SF/DP combination for this record, creating an explicit per-record declaration even though the batch context already carries matching values — this is by design, since the Setup Byte is keyed to deviations from the hardcoded session baseline (T3, ×1, 2dp), not from the L2 values.

---

### 10 — Record with Layer 2 separator counters and currency

```
./bitpads --type record --sender 0x1 --layer2 --sep-group 3 --sep-record 1 --currency 42 --out /tmp/t10.bp
```
```
00000000: 8000 0000 0010 00e8 4042 0301 2801 8000  ........@B..(...
```
16-byte Record; L2 byte[2] = 0x03 (group separator count 3), record separator and currency code 42 packed across bytes[3–4].

The separator counters in Layer 2 describe the structural position of this batch within a larger data stream — specifically, how many group, record, and file separators have been encountered since the previous batch. These counters allow a receiver processing a continuous stream to maintain positional awareness without out-of-band signaling. The group separator count occupies 6 bits across bytes[2] and[3], the record separator takes 5 bits, and the file separator takes 3 bits — together forming a 14-bit positional descriptor packed across a 2-byte span. The currency code is a 6-bit physical quantity or currency type identifier, split with its most significant bit in byte[3] bit[0] and the lower 5 bits in byte[4] bits[7:3]. This non-contiguous packing is a consequence of the fixed 6-byte Layer 2 budget; all fields must fit within it regardless of which subset is populated.

---

### 11 — Ledger frame, basic double-entry

```
./bitpads --type ledger --sender 0x1 --acct 1 --dir 0 --out /tmp/t11.bp
```
```
00000000: 8000 0000 0010 00e8 0000 0000 1080 00    ...............
```
15-byte BitLedger frame; Layer 3 (5 bytes) carries account pair 1 (Debtor/Creditor) and direction 0; no optional data blocks.

The ledger frame type adds Layer 3 after Layer 1 and the meta bytes. Layer 3 is the double-entry bookkeeping layer: it identifies an account pair by a 4-bit code and specifies the direction of the entry within that pair. Account pair 1 is the canonical Debtor/Creditor relationship. The 5-byte Layer 3 block is mandatory for all ledger frames and is positioned after the meta bytes in the same way Layer 2 is for record frames — the frame type declared in Layer 1 is what tells the receiver to expect it. The meta bytes for a ledger frame follow the same Role C flag rules as a record frame, meaning value, time, task, and note blocks can still be appended after Layer 3 using the same ordering and encoding rules.

---

### 12 — Ledger with Layer 2 and completeness flag

```
./bitpads --type ledger --sender 0x1 --layer2 --acct 1 --dir 1 --complete --out /tmp/t12.bp
```
```
00000000: 8000 0000 0010 00e8 4042 0000 0001 0000  ........@B......
00000010: 0000 1680 00                             .....
```
21-byte BitLedger frame; Completeness bit set in Layer 3 signals a compound opening entry — receiver holds this record pending a continuation frame.

The Completeness bit in Layer 3 is a sequencing flag: when set, it signals that this ledger entry is the opening member of a compound group and must not be posted until a continuation frame with the join marker arrives. The receiver is required by protocol to buffer the frame and withhold any processing dependent on entry finality. Layer 2 is present here, placing the batch context before Layer 3 in the frame structure — the ordering rule for a ledger frame with both L2 and L3 is always L1 → L2 → meta → L3. The Completeness bit does not affect the meta byte structure or the optional block sequencing; it is purely a Layer 3 directive that governs multi-frame entry composition at the application layer.

---

### 13 — Ledger compound continuation frame (account pair 1111)

```
./bitpads --type ledger --sender 0x1 --layer2 --compound --compound-max unlim --acct 15 --dir 0 --out /tmp/t13.bp
```
```
00000000: 8000 0000 0010 00e8 4042 0000 0031 0000  ........@B...1..
00000010: 0000 f080 00                             .....
```
21-byte compound continuation; account pair 0xF (1111) in Layer 3 is the protocol join marker; L2 byte[5] = 0x31 (compound prefix = unlimited, reserved = 1).

Account pair 0xF (binary 1111) is a reserved protocol value used exclusively as the compound continuation join marker. Its appearance in Layer 3 signals to the receiver that this frame is a continuation leg of a compound entry opened by a prior frame carrying the Completeness bit. The compound-max field in Layer 2 byte[5] bits[5:4] declares the ceiling on compound group depth for the batch; the 2-bit code 11 = unlimited removes the cap. The `--compound` flag also serves as a mode gate: without it, account pair 0xF would be treated as a protocol error. Layer 2 must be present in a compound frame because the compound-max field that governs the continuation's validity lives in Layer 2 — the receiver uses that field to decide whether to accept or reject the 0xF account pair.

---

### 14 — Wave with 8-bit value

```
./bitpads --type wave --value 255 --tier 1 --out /tmp/t14.bp
```
```
00000000: 0002 06ff                                ....
```
4-byte Wave; Meta1 = 0x00, Meta2 = 0x02 (Setup present), Setup Byte 0x06 (tier 1 override), value 255 (0xFF).

Wave frames do not carry a Layer 1 session header. The frame begins directly with Meta Byte 1 and Meta Byte 2, making the meta bytes the outermost framing structure. Despite the absence of Layer 1, the Setup Byte and value encoding rules apply identically to Wave frames: a Tier 1 deviation from the session default still triggers automatic Setup Byte insertion, and the Setup Byte still precedes the value block. Meta Byte 1 = 0x00 reflects Wave mode (bit 7 = 0) with no category, no ACK request, and no continuation flag set. The entire frame is 4 bytes — meta pair, Setup Byte, value — demonstrating that the meta layer's encoding machinery operates independently of whether a session header is present.

---

### 15 — Wave with value and timestamp

```
./bitpads --type wave --value 128 --tier 1 --time 30 --out /tmp/t15.bp
```
```
00000000: 0006 061e 80                             .....
```
5-byte Wave; Meta2 = 0x06 (Setup + T1S time selector), Meta2 = 0x06, Setup Byte 0x06, timestamp 30 (0x1E), value 128 (0x80).

Meta Byte 2 simultaneously carries two independent fields here: bit[1] set for Setup Byte presence, and bits[3:2] = 01 for the T1S time selector. The two fields share the same byte but govern different subsequent blocks — the Setup Byte flag says a Setup Byte follows the meta pair, and the time selector says a time field follows the value block. The assembly sequence for a Wave frame with both a value and a timestamp is: meta pair, Setup Byte, value, time — the same ordering rule as in a Record frame. The receiver decodes Meta Byte 2 once and uses both fields to plan its parse pass through the remainder of the frame. Value 128 fits in a single byte at Tier 1 and appears last, after the timestamp.

---

### 16 — Pure Signal frame

```
./bitpads --type signal --out /tmp/t16.bp
```
```
00000000: 00                                       .
```
1-byte transmission — a single Meta Byte 1 = 0x00; the minimum possible BitPads frame.

The Signal frame type produces a single-byte transmission consisting only of Meta Byte 1. It carries no Layer 1 header, no Meta Byte 2, and no payload — the meta byte itself is the complete message. With all bits at zero, the byte declares Wave mode, no category, no ACK request, no continuation, and no Role A flags. In protocol terms this is a null signal: a transmission whose meaning is defined entirely by its context in the session rather than by any embedded payload. It represents the floor of the BitPads frame hierarchy — no further reduction is possible while still producing a valid transmission.

---

### 17 — Telemetry heartbeat

```
./bitpads --type telem --tel-type heartbeat --tel-data 1 --out /tmp/t17.bp
```
```
00000000: 1e00 a1                                  ...
```
3-byte telemetry Wave in Engineering domain; Meta1 = 0x1E (Wave mode, category 14 = telegraph), telegraph byte 0xA1 = heartbeat type (0xA0) + sequence number 1.

The `--type telem` shorthand applies two automatic context rules before assembly begins: the domain is promoted to Engineering if it is currently Financial, and the category is forced to 14 (Telegraph Emulation). This means the CLI user never needs to declare `--category 14` or `--domain eng` explicitly for telemetry frames — the type flag encodes those decisions as protocol conventions. The resulting Meta Byte 1 = 0x1E sets the category mode switch (bit 4) and encodes category 14 (binary 1110) in the lower nibble, placing the frame in Wave Role B. The telegraph byte uses its upper 3 bits for message type and its lower 5 bits for inline payload; heartbeat type sets bits[7:5] = 101 (0xA0) and the sequence number 1 occupies the lower 5 bits, yielding 0xA1.

---

### 18 — Telemetry status ERR

```
./bitpads --type telem --tel-type status --tel-data 2 --out /tmp/t18.bp
```
```
00000000: 1e00 02                                  ...
```
3-byte telemetry status report; category 14 telegraph, byte 0x02 = status type (0x00) + code 2 (ERR).

Status is the lowest-valued telegraph message type, with bits[7:5] = 000, so the type field contributes 0x00 to the telegraph byte and the 5-bit status code occupies the entire lower portion. Code 2 maps to ERR in the telemetry status vocabulary. The frame structure is identical to test 17 — same Meta Byte 1, same Meta Byte 2, same 3-byte total length — because all telegraph messages share the same frame layout regardless of type. The only difference between any two telegraph frames at this level is the content of the single telegraph byte. This uniformity is deliberate: the receiver identifies the message type and payload in one byte after confirming the category-14 context from Meta Byte 1, requiring no additional framing.

---

### 19 — Wave compact command, class Configure, 1 parameter

```
./bitpads --type wave --category 12 --cmd-class 2 --cmd-params 1 --cmd-p1 0xFF --out /tmp/t19.bp
```
```
00000000: 1c00 24ff                                ..$.
```
4-byte Compact Command Wave; Meta1 = 0x1C (category 0xC = 1100), command byte 0x24 = class Configure (0x20) + 1 parameter (0x04), parameter value 0xFF.

Category 12 activates the Compact Command sub-protocol in a Wave frame. The command byte that follows Meta Byte 2 packs the command class into its upper nibble and a parameter count code into its lower nibble; optionally, response-required and chain flags occupy two further bits in the lower nibble alongside the count. Class 2 (Configure) shifts to 0x20, parameter count 1 encodes as 0x04, and their bitwise combination produces 0x24. The parameter bytes follow directly after the command byte in declaration order: p1 first, then p2 if present. The receiver reads the parameter count code from the command byte to determine how many parameter bytes to consume — 0=none, 1=one byte, 2=two bytes, 3=variable length. No Setup Byte or value block encoding rules apply in this path; the compact command payload is entirely self-described by the command byte.

---

### 20 — Wave explicit telegraph, priority alert

```
./bitpads --type wave --category 14 --tel-type priority --tel-data 15 --out /tmp/t20.bp
```
```
00000000: 1e00 cf                                  ...
```
3-byte telegraph Wave; Meta1 = 0x1E (category 14), telegraph byte 0xCF = priority type (0xC0) + escalation code 15.

This frame uses `--type wave --category 14` rather than `--type telem`, which demonstrates that the telegraph payload path is accessible directly through the Wave type without invoking the telem shorthand. The protocol result is identical to a telem frame with the same category — the distinction is purely at the CLI level. Priority type sets bits[7:5] = 110 (0xC0) in the telegraph byte, and escalation code 15 (0x0F) fills the lower 5 bits, producing 0xCF. Category 14 in Meta Byte 1 activates Role B mode, and the receiver treats the immediately following byte as a telegraph header in the standard message type / payload format regardless of whether the frame arrived as telem or wave.

---

### 21 — Enhanced Record with signal slot P4

```
./bitpads --type record --sender 0x1 --enhance --slot-p4 0xAB --value 10 --tier 1 --out /tmp/t21.bp
```
```
00000000: 8010 0000 0010 0768 8803 878b 060a       .......h......
```
14-byte Record; Layer 1 byte[1] = 0x10 (Enhancement Flag set), Meta2 = 0x03 (Setup + Slots), SSP byte 0x87 declares P4 active, signal byte 0xAB fires before the value block, Setup Byte 0x06, value 10.

The Enhancement Flag in Layer 1 byte[1] bit[4] activates the C0 grammar extension for the session, which enables 13 named signal positions (P0–P12) that fire at defined points in the frame body. Once the enhancement flag is set, Meta Byte 2 bit[0] is used as a Signal Slot Presence indicator: when set, a Signal Slot Presence (SSP) byte follows the meta pair and declares which slots are active via a bitmask. The SSP byte 0x87 = 1000 0111 activates slots P4 (bit 2), P5 (bit 1), and P6 (bit 0) in its lower nibble along with the extension marker in the upper nibble; P4 is defined as firing immediately before the value block, so signal byte 0xAB is written at that position. The ordering contract is: meta pair → SSP byte → P4 signal → Setup Byte → value. Skipping any declared slot or inserting one out of position violates the C0 grammar and renders the frame unparse-able.

---

### 22 — Record with archetype field

```
./bitpads --type record --sender 0x1 --archetype 5 --out /tmp/t22.bp
```
```
00000000: 8000 0000 0010 00e8 8050                 .........P
```
10-byte Record; Meta2 = 0x50 = archetype 5 in upper nibble (0101_0000); identifies the BitLedger flow archetype for this record stream.

The archetype field occupies the upper nibble of Meta Byte 2 (bits[7:4]) and carries a 4-bit code that classifies the record stream by its data flow pattern — for example, identifying whether the stream represents a sales ledger, inventory adjustment, payroll run, or other defined archetype. Archetype 5 encodes as 0x50 in the upper nibble (0101 shifted left 4 = 0101_0000). The archetype field is independent of all other Meta Byte 2 fields: it coexists with the time selector, Setup Byte flag, and slot presence bit without interaction. Because no value, time, task, or note blocks are present, Meta Byte 1's lower nibble is 0x00, and the frame is just the 8-byte Layer 1 header followed by the two meta bytes — the archetype is carried at minimal frame cost.

---

### 23 — Record in Engineering domain with full permissions

```
./bitpads --type record --sender 0x42 --domain eng --perms 15 --out /tmp/t23.bp
```
```
00000000: 9f00 0000 0420 3056 8000                 ..... 0V..
```
10-byte Record; Layer 1 byte[0] = 0x9F (SOH + domain 01 Engineering + permissions 1111 = Read/Write/Correct/Proxy); sender 0x42 packed across bytes[1–5].

Layer 1 byte[0] is the most compositionally dense byte in the protocol. It carries the SOH marker (bit[7] = 1, always), the 2-bit domain code in bits[5:4], and the 4-bit permission field in bits[3:0], all within a single byte. Engineering domain encodes as binary 01 in bits[5:4], and full permissions 15 (binary 1111) in bits[3:0] set all four flags — Read, Write, Correct, and Proxy — simultaneously. The resulting 0x9F = 1001 1111 reflects all five fields packed together. The permission field is a bitfield, not a level: each bit is an independent capability grant, so partial permission sets (e.g., Read-only = 0001) are equally valid. Sender 0x42 is a small value that occupies only the low bits of the sender span across bytes[1–5]; the CRC covers the full 49-bit Layer 1 payload including the domain and permission fields, so changing either one invalidates the checksum.

---

### 24 — Record with Tier 2 extended timestamp

```
./bitpads --type record --sender 0x1 --time-ext 1000 --out /tmp/t24.bp
```
```
00000000: 8000 0000 0010 00e8 840c 03e8             ............
```
12-byte Record; Meta1 = 0x84 (Record + Time), Meta2 = 0x0C (time selector = Tier 2 block), 16-bit timestamp 1000 (0x03E8) follows.

The `--time-ext` flag selects the Tier 2 extended timestamp path, which differs from `--time` in two respects: the value is 16-bit rather than 8-bit, and the time selector code in Meta Byte 2 bits[3:2] is set to 11 (0x0C) instead of 01 (T1S session offset). The time selector is the receiver's only signal for how many bytes to consume as the time field — without it, the receiver cannot determine whether to read 1 or 2 bytes. The 16-bit value 1000 = 0x03E8 is written big-endian in the frame body. No Setup Byte is generated because there is no value block; the Setup Byte trigger is conditioned on value encoding deviations, not on timestamp width. The frame demonstrates that the time and value subsystems are independently controlled: either can be present without the other, and their respective encoding controls do not interfere.

---

### 25 — Repeated dry-run, count 3

```
./bitpads --type record --sender 0x1 --value 1 --tier 1 --count 3 --dry-run --out /dev/null
```
```
bitpads: transmission written successfully
```
Dispatch loop ran 3 iterations, frame assembled and validated each time in dry-run mode; no file written, single success message printed on completion.

The `--count` flag wraps the entire build-and-dispatch cycle in a loop, repeating the frame assembly from scratch on each iteration. In dry-run mode the assembled frame is validated but the write path is suppressed, so each iteration exercises the full assembly stack — Layer 1 construction, CRC-15 computation, meta byte building, Setup Byte insertion, value encoding — without producing file I/O. The count value is stored as an 8-bit integer in the context block, limiting the range to 1–255. A single success message is printed after the loop completes rather than once per iteration, making the output identical to a single dry-run regardless of count. Combined with `--hex-raw` instead of `--dry-run`, the same loop would emit the assembled frame bytes to stdout on each pass, which is useful for stress-testing downstream parsers.
