# BitPads CLI — Complete Protocol Permutation Audit and Register Efficiency Report

## 2026 CLI coverage update

The CLI now exposes additional protocol fields directly:

- Layer2 tx type (`--txtype`) and compound ceilings (`--compound-max`)
- Layer2 currency/rounding/separator fields (`--currency`, `--round-bal`, `--sep-group`, `--sep-record`, `--sep-file`)
- Dedicated Meta2 archetype (`--archetype`) separate from category routing
- Tier2 full time word (`--time-ext`)
- Task semantic subfields (`--task-code`, `--task-target`, `--task-timing`)
- Signal slots P4-P8 (`--slot-p4` ... `--slot-p8`)
- cmd1100/tel1110 semantic composition flags (`--cmd-*`, `--tel-*`)
- Runtime emission modes (`--dry-run`, `--hex`, `--hex-raw`, `--count`, `--print-size`)

Unknown flags and out-of-range values for new flags are treated as parse errors.

Two topics, one document. Part 1 is a full bit-level audit of every protocol field across every
layer — the definitive map of what is reachable, what is hard-wired, and what is completely
missing from the CLI. Part 2 is an analysis of 32/64-bit register usage as a power and
efficiency concern, with a frank assessment of whether and when it matters for this project.

---

## Part 1 — Complete Protocol Permutation Audit

The protocol has five structural layers, two meta bytes, and five enhancement categories. Every
field in every layer is catalogued below. Fields are marked:

- ✓ **Exposed** — a CLI flag controls this field
- ~ **Partial** — the field is reachable but constrained (range or values limited)
- ✗ **Hardwired** — the code always writes a fixed value, no CLI path to change it
- ✗ **Unimplemented** — the protocol defines this field; the code does not emit it at all

---

### Layer 1 — Session Header (8 bytes, 64 bits)

Layer 1 is present in every Record and Ledger frame. It is the fixed session identity block.
Bit 7 of byte 0 is always 1 (the SOH anchor). The remaining 63 bits carry:

```
Byte 0:  [SOH=1][Ver=0][Domain:2][Permissions:4]
Byte 1:  [SplitOrd=0][SplitMode:2][Enhancement:1][SenderID[31:28]:4]
Bytes 2-4: SenderID[27:4]  (24 bits, 3 full bytes)
Byte 5:  [SenderID[3:0]:4][SubEntity[4:1]:4]
Byte 6:  [SubEntity[0]:1][CRC[14:8]:7]
Byte 7:  CRC[7:0]
```

| Field | Bits | Range | CLI status | Flag |
|---|---|---|---|---|
| SOH marker | 1 | always 1 | ✗ hardwired | — |
| Wire format version | 1 | always 0 | ✗ hardwired | — |
| Domain | 2 | 0-3 (fin/eng/hybrid/custom) | ✓ | `--domain` |
| Permissions | 4 | 0-15 (R/W/Correct/Proxy per bit) | ✓ | `--perms` |
| Split order default | 1 | 0=multiplicand-first | ✗ hardwired 0 | missing: `--split-order` |
| Sender ID split mode | 2 | 0-3 | ✓ | `--split` |
| Session enhancement flag | 1 | 0/1 | ✓ | `--enhance` |
| Sender ID | 32 | 0x00000000-0xFFFFFFFF | ✓ | `--sender` |
| Sub-entity ID | 5 | 0-31 | ✓ | `--subentity` |
| CRC-15 | 15 | computed | ~ auto, ✗ no override | missing: `--crc` (test only) |

**One missing field:** `split order default` (bit 7 of byte 1) is always 0. The protocol
defines 1 as "multiplier first" ordering. This is a single-bit flag that could be `--split-order`
if the protocol ever needs it. Currently safe to leave hardwired.

---

### Layer 2 — Batch Context Header (6 bytes, 48 bits)

Layer 2 is optional (`--layer2`). It establishes the batch-level interpretation context
inherited by all records in the session.

```
Byte 0:  [TxType:2][SF[5:0]:6]
Byte 1:  [SF[6]:1][OptimalSplit:4][DecimalPos:3]
Byte 2:  [Bells:2][GroupSep[5:0]:6]  (upper 6 bits of group separator counter)
Byte 3:  [GroupSep[7:6]:2][RecordSep:5][CurrencyQType[5]:1]
Byte 4:  [CurrencyQType[4:0]:5][RoundBal[3:2]:2][unused:1]
Byte 5:  [RoundBal[1:0]:2][CompoundPrefix:2][pad:1][Res=1:1]
```

| Field | Bits | Range | CLI status | Flag |
|---|---|---|---|---|
| Transmission type | 2 | 01=Pre-conv, 10=Copy, 11=Represented | ✗ hardwired Pre-conv | missing: `--txtype` |
| Scaling factor (SF) | 7 | 0-127 (indices 0-3 used) | ~ only 0-3 | `--sf` |
| Optimal split | 4 | default=8 | ✗ hardwired 8 | missing: `--optimal-split` |
| Decimal position | 3 | 0/2/4/6 | ✓ | `--dp` |
| Enquiry bell | 1 | 0/1 | ✗ hardwired 0 | missing: `--bell-enq` |
| Acknowledge bell | 1 | 0/1 | ✗ hardwired 0 | missing: `--bell-ack` |
| Group separator count | 4+2=6 | 0-63 | ✗ hardwired 0 | missing: `--sep-group` |
| Record separator count | 5 | 0-31 | ✗ hardwired 0 | missing: `--sep-record` |
| File separator count | 3 | 0-7 | ✗ hardwired 0 | missing: `--sep-file` |
| Entity ID | 5 | 0-31 | ✓ (via subentity) | `--subentity` |
| Currency / Qty type | 6 | 0-63 | ✗ hardwired 0 | missing: `--currency` |
| Rounding balance | 4 | 0-15 | ✗ hardwired 0 | missing: `--round-bal` |
| Compound prefix | 2 | 00=none, 01=max3, 10=max7, 11=unlimited | ~ (00 or 11 only) | `--compound` |
| Reserved | 1 | always 1 | ✗ hardwired 1 | — |

**High-value missing fields:** `--currency` (6-bit code) and `--txtype` (copy vs. pre-converted
vs. represented). The compound prefix jump from 00 to 11 skips the intermediate ceilings
(max-3, max-7); a `--compound-max <3|7|unlimited>` argument would expose the full range.

---

### Layer 3 — BitLedger Record (5 bytes, 40 bits)

Layer 3 is present in every Ledger frame. Bytes 0-3 are upper control fields (always 0x00 in
standard data records). Only byte 4 carries live data.

```
Bytes 0-3: Upper control fields (standard record = 0x00)
Byte 4:  [AccountPair:4][Direction/SubType:2][Completeness:1][Extension:1]
```

| Field | Bits | Range | CLI status | Flag |
|---|---|---|---|---|
| Upper control fields | 32 | always 0x00 | ✗ hardwired | — |
| Account pair | 4 | 0-15 (16 double-entry pairs incl. 1111) | ✓ | `--acct` |
| Direction / sub-type | 2 | 0-3 | ✓ | `--dir` |
| Completeness | 1 | 0=full, 1=partial/compound-hold | ✓ | `--complete` |
| Extension flag | 1 | 0=no ext, 1=ext byte follows | ✗ hardwired 0 | missing: `--ext` |
| Extension byte | 8 | sub-category, party type, timestamp | ✗ unimplemented | missing: `--ext-byte` |

**Missing:** The extension byte (flagged by bit 0 of byte 4) carries sub-category, party type,
and a timestamp hint. When set, one additional byte follows byte 4. Currently the code never
sets the extension flag and never emits an extension byte — a complete unimplemented branch.

---

### Meta Byte 1 — Universal Frame Header

Meta Byte 1 is the first byte of every BitPads transmission without exception.

```
[Mode:1][ACK/SysCtx:1][Continuation:1][Treatment:1][Content:4]

Content roles:
  Role A (Wave, no category): [Priority:1][Cipher:1][ExtFlags:1][Profile:1]
  Role B (Wave, category set): [Category:4]
  Role C (Record): [Value:1][Time:1][Task:1][Note:1]
```

| Field | Bits | CLI status | Flag |
|---|---|---|---|
| BitPad mode (Wave/Record) | 1 | ✓ automatic from `--type` | — |
| ACK request (Wave) / SysCtx ext (Record) | 1 | ✓ | `--ack` |
| Continuation / fragment | 1 | ✓ | `--cont` |
| Treatment switch (Role A/B) | 1 | ✓ automatic (nonzero category → Role B) | — |
| Role A — Priority | 1 | ✓ | `--prio` |
| Role A — Cipher | 1 | ✗ hardwired 0 | missing: `--cipher` |
| Role A — ExtFlags | 1 | ✗ hardwired 0 | missing: `--ext-flags` |
| Role A — Profile | 1 | ✗ hardwired 0 | missing: `--profile` |
| Role B — Category code | 4 | ✓ | `--category` |
| Role C — Value present | 1 | ✓ automatic from `--value` | — |
| Role C — Time present | 1 | ✓ automatic from `--time` | — |
| Role C — Task present | 1 | ✓ automatic from `--task` | — |
| Role C — Note present | 1 | ✓ automatic from `--note` | — |

**Missing Role A flags:** `--cipher`, `--ext-flags`, `--profile`. These three bits in Wave
Role A mode are always 0. In a protocol-complete implementation, each would be a boolean flag.
These are low-priority unless the receiving parser actually uses them.

---

### Meta Byte 2 — Record Structure Declaration

```
[Archetype/SubType:4][TimeSelector:2][SetupPresent:1][SlotPresent:1]
```

| Field | Bits | CLI status | Flag |
|---|---|---|---|
| Archetype / sub-type (upper nibble) | 4 | ~ conflated with category | `--category` |
| Time reference selector | 2 | ✓ (via time-tier) | `--time-tier` |
| Setup byte present | 1 | ✓ automatic | `--setup` (or auto-detected) |
| Signal slot presence | 1 | ✓ automatic from slot activity | — |

**Design tension:** The upper nibble of Meta Byte 2 serves as the *archetype code* in Record
mode but the CLI reuses `BP_CTX_CATEGORY` for it. This means the category code set by
`--category 12` (Compact Command) will also appear as "archetype 12" in Meta Byte 2's upper
nibble when building a Record. For Wave frames this is correct (category code goes in Meta Byte
1 Role B). For Record frames, the archetype is an independent classification. A `--archetype`
flag, distinct from `--category`, is the correct separation.

---

### Setup Byte — Per-Record Value Encoding Override

The setup byte follows Meta Byte 2 when the tier, SF, or DP deviate from the session defaults
(Tier 3, SF=×1, DP=2). It overrides Layer 2 defaults for this record only.

```
[ValueTier:2][ScalingFactor:2][DecimalPos:3][ContextSrc:1] (approximate layout)
```

All four fields come from `BP_CTX_VALUE_TIER`, `BP_CTX_SF_INDEX`, and `BP_CTX_DP` — all
already exposed via `--tier`, `--sf`, and `--dp`. The setup byte is generated automatically
when those values are non-default. No additional flags are needed here.

---

### Value Block — 1 to 4 Bytes

Tier 1: 1 byte (0-255). Tier 2: 2 bytes big-endian. Tier 3: 3 bytes big-endian. Tier 4: 4 bytes.

The value block is fully controlled by `--value`, `--tier`, `--sf`, `--dp`. No missing fields.

---

### Time Field — 0 to 2 Bytes

```
Tier 1 (session offset, 1 byte):  [TimeValue:8]
Tier 1 (external ref, 1 byte):    [TimeValue:8]
Tier 2 (full block, 2 bytes):     [TimeValue:16 big-endian]
```

| Field | CLI status | Gap |
|---|---|---|
| Time value (Tier 1) | ✓ `--time` (8-bit) | — |
| Time tier selector | ✓ `--time-tier` | — |
| Time value (Tier 2, 16-bit) | ~ `--time` only takes 8-bit | missing: `--time-ext` (16-bit) |

**Missing:** When `--time-tier 3` (Tier 2) is selected, the 16-bit value needs two bytes, but
`--time` stores only 8 bits into `BP_CTX_TIME_VAL`. A `--time-ext <uint16>` flag would cover
the full Tier 2 time range.

---

### Task Block — 1 to 3 Bytes

```
Byte 0: [TargetPresent:1][TaskCode:6][TimingPresent:1]
Byte 1: [TargetEntity:8]   (if TargetPresent=1)
Byte 2: [TimingOffset:8]   (if TimingPresent=1)
```

| Field | CLI status | Gap |
|---|---|---|
| Task control byte | ~ `--task <hex8>` (must pre-encode full byte) | missing: named fields |
| Target entity byte | ✗ ctx has space, no flag to set it | missing: `--task-target` |
| Timing offset byte | ✗ ctx has space, no flag to set it | missing: `--task-timing` |

**Missing:** The three task fields need separate flags. The user currently has to manually
compute the hex control byte and knows nothing about what the target/timing bytes should be.
Proposed:
```
--task-code <0-63>       6-bit task code (bits 6-1 of the control byte)
--task-target <uint8>    target entity byte (sets bit 7 of control byte automatically)
--task-timing <uint8>    timing offset byte (sets bit 0 of control byte automatically)
```

---

### Note Block — 1 to 64 Bytes

```
[LengthHeader: 1 or 2 bytes][NoteData: 0-63 bytes]
```

The length header encoding is: if length ≤ 14, single byte with length in lower 4 bits.
If length > 14, two bytes. The note content is already fully exposed via `--note <string>`.
No missing fields.

---

### Enhancement Category 1100 — Compact Command (1-3 bytes)

```
Byte 0: [CommandClass:4][ParamCount:2][ResponseReq:1][Chained:1]
Byte 1: [Param1:8]   (if ParamCount ≥ 1)
Byte 2: [Param2:8]   (if ParamCount = 2 or variable)
```

The command byte and params come entirely from `BP_CTX_TASK_BYTE` (bytes 0-2). The CLI
exposes these only via `--task <hex8>` (control byte) with no way to set params separately.

| Field | CLI status | Gap |
|---|---|---|
| Command class (4b: Lifecycle/Query/Configure/Sync/Diag/Security/Transfer/Route/Extended) | ~ pre-encode in hex | missing: `--cmd-class` |
| Parameter count (2b: none/1/2/var) | ~ pre-encode in hex | missing: `--cmd-params` |
| Response required (1b) | ~ pre-encode in hex | missing: `--cmd-resp` |
| Chained (1b) | ~ pre-encode in hex | missing: `--cmd-chain` |
| Param 1 byte | ~ pre-encode in BP_CTX_TASK_BYTE+1 | missing: `--cmd-p1` |
| Param 2 byte | ~ pre-encode in BP_CTX_TASK_BYTE+2 | missing: `--cmd-p2` |

**Command classes** defined in cmd1100.asm: Lifecycle (0x00), Query (0x10), Configure (0x20),
Sync (0x30), Diag (0x40), Security (0x50), Transfer (0x60), Route (0x70), Extended (0xF0).

---

### Enhancement Category 1101 — Context Declaration

Context declarations are assembled from the existing ctx fields (task byte = context class,
time fields carry epoch, etc.). The key gap is the same as for the task block: the context
class and epoch value are not separately addressable by name. A `--ctx-class` and
`--ctx-epoch <uint32>` would be the right additions.

---

### Enhancement Category 1110 — Telegraph

```
Byte 0: [MessageType:3][InlinePayload:5]
Byte 1: [ExtendedType:8]    (if MessageType = 111 Extended)
Bytes 1-N: UTF-8 text       (if MessageType = 100 FreeText, N = InlinePayload bits)
```

Telegraph stores its header byte in `BP_CTX_TASK_BYTE`. The user must manually encode the
full byte via `--task`. There are 7 named message types with distinct inline payload semantics.

| Message type | Inline 5 bits | CLI status |
|---|---|---|
| Status (000) | 5-bit status code (0=OK…31=ext) | ~ `--task` hex (must pre-encode) |
| Value (001) | 5-bit compact value (0-31) | ~ `--task` hex |
| Command (010) | 5-bit opcode | ~ `--task` hex |
| Identity (011) | 5-bit sub-entity assertion | ~ `--task` hex |
| Free Text (100) | 5-bit length (1-31 bytes) | ~ `--task` + `--note` for text |
| Heartbeat (101) | 5-bit sequence number | ~ `--task` hex |
| Priority (110) | 5-bit priority code | ~ `--task` hex |
| Extended (111) | — (type in next byte) | ~ `--task` + set next byte |

**Proposed named flags:**
```
--tel-type <status|value|command|identity|text|heartbeat|priority|extended>
--tel-status <0-31>       inline status code
--tel-value <0-31>        compact 5-bit sensor value
--tel-cmd <0-31>          5-bit opcode
--tel-seq <0-31>          heartbeat sequence number
--tel-prio <0-31>         priority escalation code
--tel-id <0-31>           sub-entity identity assertion
```
These would automatically assemble the `BP_CTX_TASK_BYTE` header from semantic names,
removing the need to pre-compute hex.

---

### Signal Slots — P4 through P8 (per-record) and P1-P3, P9-P13 (session-wide)

The signal slot system is partially wired. The SSP byte is assembled and emitted correctly
if `BP_CTX_SIGNAL_SLOTS` is non-zero. But there is no CLI path to set `BP_CTX_SIGNAL_SLOTS`
or `BP_CTX_SIGNALS` (the 16-byte slot data array at offset 165).

Each signal slot holds an enhanced C0 byte with structure:
```
[Priority:1][ACK:1][Continuation:1][C0Code:5]
```

Five per-record slots (P4-P8) and eight session-wide slots (P1-P3, P9-P13) are available
when enhancement is active.

**All signal slot content is currently zero and unreachable from the CLI.**

Proposed:
```
--slot-p4 <hex8>    set P4 slot (pre-value signal)
--slot-p5 <hex8>    set P5 slot (post-value signal)
--slot-p6 <hex8>    set P6 slot (post-time signal)
--slot-p7 <hex8>    set P7 slot (post-task signal)
--slot-p8 <hex8>    set P8 slot (post-record signal)
```
Or in semantic form: `--slot-p4-code <C0code> --slot-p4-prio --slot-p4-ack`.

---

### Complete Gap Summary

| Priority | Gap | Flags to add |
|---|---|---|
| High | Signal slot content (P4-P8) | `--slot-p4` through `--slot-p8` |
| High | Task sub-fields (target, timing) | `--task-code --task-target --task-timing` |
| High | Telegraph semantic flags | `--tel-type --tel-status --tel-value` etc. |
| High | Telegraph 16-bit Tier 2 time | `--time-ext` |
| High | Command sub-fields (cmd1100) | `--cmd-class --cmd-params --cmd-p1 --cmd-p2` |
| Medium | Archetype vs. category separation | `--archetype` (distinct from `--category`) |
| Medium | Layer 2 currency code | `--currency` |
| Medium | Layer 2 tx type | `--txtype <pre|copy|rep>` |
| Medium | Layer 2 compound prefix granularity | `--compound-max <3|7|unlimited>` |
| Medium | Layer 3 extension byte | `--ext-byte` |
| Low | Layer 1 CRC override | `--crc` (test only) |
| Low | Layer 2 bell flags | `--bell-enq --bell-ack` |
| Low | Layer 2 separator counters | `--sep-group --sep-record --sep-file` |
| Low | Layer 2 rounding balance | `--round-bal` |
| Low | Meta Byte 1 Role A cipher/extflags/profile | `--cipher --ext-flags --profile` |
| Low | Layer 1 split order default | `--split-order` |

---

## Part 2 — Register Width, Packing, and Power Efficiency

### The question stated plainly

Can we reduce runtime and electricity use on a low-power device by ensuring every register
is "filled to maximum" — i.e., using 64-bit operations and packing multiple protocol fields
into a single register before writing?

The answer is: **yes, but with important conditions and nuances**. The benefit is real but its
magnitude depends entirely on which execution target we are designing for.

---

### Why register width matters: a hardware model

Every instruction that executes consumes power in two ways:

1. **Dynamic power**: the energy to charge and discharge transistor gates. This is proportional
   to the number of gate transitions (bit flips). Wider data paths with more zeros are not
   automatically cheaper — what matters is how many wires actually change state.

2. **Static power** (leakage): the energy that flows even when nothing is switching. Leakage
   is a function of time, not instructions. Reducing execution time reduces leakage exposure.

Reducing the number of instructions executed reduces **time**, which reduces leakage.
Reducing unnecessary memory bus activity reduces **dynamic power** on the memory interface.
These are the two real handles available to assembly programmers.

---

### What "filling registers to maximum" actually means

There are three distinct optimisation patterns that the phrase implies, and they are different
in effect:

**Pattern A — Wide loads (batch reads)**
Instead of eight `movzx eax, byte [rbx + fieldN]` instructions reading eight separate ctx
fields one byte at a time, one `mov rax, qword [rbx + field0]` reads all eight bytes in a
single bus transaction. The CPU then extracts each byte using shifts and masks — which execute
in the CPU's execution units (zero memory access, very fast) rather than the memory subsystem.

On any CPU with a cache, eight 1-byte loads from adjacent addresses will likely all hit the
same cache line, so the memory access cost is identical either way. The benefit of wide loads
is a reduction in instruction count, not cache miss reduction.

On a bare-metal device without cache (e.g., an 8 MHz microcontroller or FPGA softcore), wide
loads are much more significant: each memory access is a full bus cycle. Eight separate byte
reads = eight bus cycles. One 64-bit read = one bus cycle (or two on 32-bit data buses).
This is a genuine and measurable power reduction.

**Pattern B — Wide stores (batch writes)**
Instead of building an output buffer byte by byte with eight `mov byte [r12 + offset], al`
instructions, accumulate the bytes in a register and write them with one `mov qword [r12], rax`.

This is the mirror of Pattern A and has the same cost model. It reduces store instructions
and, on uncached hardware, reduces bus write cycles significantly.

**Pattern C — Eliminating partial-register writes**
On x86-64, writing to `al` or `ax` does NOT clear the upper bits of `rax`. This means the CPU
must preserve those upper bits — which, on some microarchitectures, creates a
false dependency: the instruction that writes `al` must wait for the instruction that last
wrote to the full `rax` to complete, because the hardware has to merge the low byte with the
upper bytes. This is a pipeline stall.

The fix is to prefer `movzx eax, byte [mem]` (which zero-extends, breaking the dependency)
over `mov al, byte [mem]` (which requires the old rax value). This is not about "filling"
registers — it is about avoiding merge penalties.

---

### Current code: where the patterns are already applied and where they are not

**Already optimal:**

`layer1_build` line 74:
```nasm
mov     qword [r12], rax        ; zero all 8 bytes of Layer 1 in one instruction ✓
```
This is the best possible approach. One 64-bit store, zero-initialises the entire output buffer.

`layer2_build` lines 69-70:
```nasm
mov     dword [r12 + 0], eax    ; zero bytes 0-3
mov     word  [r12 + 4], ax     ; zero bytes 4-5
```
Two instructions instead of one. The entire 6 bytes could be zero-cleared with a single
`mov qword [r12], 0` (NASM allows immediate 0 in a qword store). The extra 2 bytes in
positions 6-7 don't matter because the 6-byte buffer is allocated with resb 6 and the
surrounding memory is separately managed.

`layer3_build` lines 87-89:
```nasm
mov     dword [r12 + 0], eax    ; zero bytes 0-3
mov     byte  [r12 + 4], al     ; zero byte 4
```
Same opportunity: `mov qword [r12], 0` (using 8-byte write for a 5-byte struct) if the buffer
is large enough, or keep the dword+byte form if space is tight. The dword + byte form is fine.

**Repeated single-byte ctx reads:**

In `meta2_build` the three setup-byte-detection reads are separate instructions:
```nasm
movzx   ecx, byte [rbx + BP_CTX_VALUE_TIER]    ; one byte load
...
movzx   ecx, byte [rbx + BP_CTX_SF_INDEX]      ; another byte load
...
movzx   ecx, byte [rbx + BP_CTX_DP]            ; another byte load
```

`BP_CTX_VALUE_TIER` = offset 17, `BP_CTX_SF_INDEX` = offset 18, `BP_CTX_DP` = offset 19.
These three bytes are adjacent in the ctx struct. They could be read as a single 32-bit load:

```nasm
mov     eax, dword [rbx + BP_CTX_VALUE_TIER]   ; reads offsets 17, 18, 19, 20 in one load
; tier is in al (byte 0), sf is in ah (byte 1), dp is in bits 16-23 (extract with shr/and)
```

The instruction-count reduction is from 3 loads to 1 load. On cached x86, this is noise.
On an uncached microcontroller, this is 3× reduction in bus reads for those fields.

**Multi-byte output buffer construction:**

In `layer1_build`, the sender ID is encoded across five memory writes:
```nasm
or      byte [r12 + 1], r13b    ; sender bits 31-28
mov     byte [r12 + 2], r13b    ; sender bits 27-20
mov     byte [r12 + 3], r13b    ; sender bits 19-12
mov     byte [r12 + 4], r13b    ; sender bits 11-4
or      byte [r12 + 5], r13b    ; sender bits 3-0 (with sub-entity mixed in)
```

These five writes touch five different bytes of the output buffer. Since the buffer starts
zeroed, four of these could be done with a single `mov dword [r12 + 2], reg32` if the
sender ID bits are pre-assembled into a 32-bit value. Bytes 2-5 carry sender bits 27-4:
these are exactly the middle three bytes (27:20, 19:12, 11:4) plus the upper nibble of byte 5.
A 32-bit store to `[r12 + 2]` would write all four bytes atomically.

The actual pre-assembly would look like:
```nasm
; eax = sender_id (already loaded)
; Build a 32-bit value representing bytes[2..5] of Layer 1
mov     edx, eax
bswap   edx                     ; reverse byte order (little-endian → big-endian for the buffer)
; then mask out the fields that don't align and merge sub-entity bits separately
mov     dword [r12 + 2], edx    ; one store for four bytes
```
This is more complex to reason about correctly, which is the tradeoff: fewer bus cycles versus
harder-to-audit code. For the current CLI target (macOS x86-64), this is not worth doing.
For a firmware port, it would be.

---

### When does this matter: a direct answer

| Target | Does register packing matter? | Dominant cost |
|---|---|---|
| macOS CLI (current) | No — not measurably | `SYS_OPEN + SYS_WRITE + SYS_CLOSE` syscall overhead |
| x86 SBC with Linux (e.g. Intel NUC at low power) | Marginal | Syscall overhead |
| x86 SBC bare metal (no OS, direct hardware write) | Moderate | SPI/UART write loop |
| 8/16 MHz microcontroller (x86 or compatible ISA) | High | Every instruction costs |
| FPGA softcore at MHz-range clock | Very high | Every bus cycle counted |

For the CLI, the entire frame assembly (all the shift/or/store work) executes in under 1000
cycles. The three syscalls (`open`, `write`, `close`) in `fileio_write` each cost 1000-10000
cycles due to kernel mode transition. Optimising the 1000-cycle assembly path to 800 cycles
does nothing measurable when it's surrounded by 30000 cycles of syscall overhead.

For a firmware version flashing to hardware, the picture inverts. There are no syscalls. The
"write" is a byte-at-a-time SPI or UART push. Reducing the number of byte loads and stores
in frame assembly reduces the number of iterations in the write loop, directly reducing
transmission time and power.

---

### The three rules that actually matter for this codebase

**Rule 1: Use `movzx reg32, byte/word` not `mov reg8, byte`**

`movzx eax, byte [mem]` breaks the false dependency on the old value of `rax`.
`mov al, byte [mem]` requires merging with the old `rax`. On out-of-order CPUs this can stall
the pipeline. `movzx` is always correct and often faster. This is already the dominant pattern
in the codebase and should remain so.

**Rule 2: Use `mov reg32, reg32` to zero-extend a 32-bit result to 64 bits**

As established in `BUILDFIX_NOTES.md`: `mov eax, ecx` zero-extends ecx into rax via the
implicit x86-64 rule. This is both correct and power-neutral. Never use `movzx rax, ecx`.

**Rule 3: For the firmware port, batch all ctx reads into wide loads at function entry**

Rather than reading ctx fields one byte at a time throughout a function, load the relevant
section of the ctx struct into registers at the top of the function:

```nasm
; Load value encoding fields (offsets 17-22) all at once
mov     rax, qword [rbx + BP_CTX_VALUE_TIER]   ; al=tier, ah=sf, (16)=dp, (24)=timeval, etc.
; Save to dedicated registers for use throughout the function
movzx   r8d, al          ; r8d = value tier
movzx   r9d, ah          ; r9d = SF index
; etc.
```

One bus read instead of six separate loads. On cached hardware: no difference. On uncached
firmware target: ~5× reduction in memory access count for that function's setup phase.

---

### Is aggressive register packing desirable from a program operation perspective?

For the CLI: **No**. The code as written is already readable, correct, and produces valid
protocol output. The execution time is dominated by OS overhead, not register arithmetic.
Premature optimisation here would make the code harder to audit against the protocol spec
and provide no measurable benefit.

For the firmware port: **Yes, but selectively**. The highest-value optimisations are:

1. **Output buffer construction**: replace sequences of `mov byte [buf + N], val` with
   `mov dword [buf + N], wide_val` wherever 4 or more adjacent bytes are written. This
   reduces bus write cycles by 4× on uncached hardware.

2. **Batch ctx reads at function entry**: replace per-field `movzx` loads with one or two
   wide reads at the start of each builder function, then extract fields with shifts and masks.

3. **Inline small functions**: `meta1_build`, `meta2_build`, `setup_build` are each under 30
   instructions. For a firmware build, inlining them into the builder functions eliminates
   the call/ret overhead and allows the compiler view to see the full register usage, enabling
   tighter packing.

4. **Reduce function call depth**: the current architecture is `main → dispatch → build_wave
   → meta1_build + meta2_build + value_encode + ...`. Each level saves and restores callee
   registers. For a firmware image, flattening two levels saves 8-16 push/pop instructions
   per frame — meaningful at MHz clock speeds.

The honest summary: write the firmware port differently from the CLI from the start. The CLI
benefits from the modular, well-commented architecture. The firmware version benefits from
flatter, denser functions with pre-loaded register contexts. They are the same protocol; they
should be different implementations with a shared specification in the include files.

---

### Appendix: ctx field layout for wide-load planning

```
Offset  Field                    Width
──────────────────────────────────────
0       BP_CTX_TYPE              1 byte
1       BP_CTX_DOMAIN            1 byte
2       BP_CTX_PERMISSIONS       1 byte
3       (unused)
4       BP_CTX_SENDER_ID         4 bytes (dword)
8       BP_CTX_SUB_ENTITY        1 byte
9       BP_CTX_SPLIT_MODE        1 byte
10      BP_CTX_ENHANCEMENT       1 byte
11      BP_CTX_CATEGORY          1 byte
12      BP_CTX_VALUE             4 bytes (dword)
16      BP_CTX_VALUE_PRES        1 byte
17      BP_CTX_VALUE_TIER        1 byte   ─┐
18      BP_CTX_SF_INDEX          1 byte    │ 6-byte run — one qword read covers all
19      BP_CTX_DP                1 byte    │
20      BP_CTX_TIME_VAL          1 byte    │
21      BP_CTX_TIME_PRES         1 byte    │
22      BP_CTX_TIME_TIER         1 byte   ─┘
23      BP_CTX_TASK_BYTE         3 bytes  ─┐
26      BP_CTX_TASK_PRES         1 byte    │ 6-byte run
27      BP_CTX_NOTE_LEN          1 byte    │
28      BP_CTX_NOTE_PRES         1 byte   ─┘
29      BP_CTX_NOTE_DATA         63 bytes
92      BP_CTX_ACCT_PAIR         1 byte   ─┐
93      BP_CTX_DIRECTION         1 byte    │ 8-byte run — one qword read covers all
94      BP_CTX_COMPLETENESS      1 byte    │
95      BP_CTX_COMPOUND          1 byte    │
96      BP_CTX_ACK_REQ           1 byte    │
97      BP_CTX_CONT              1 byte    │
98      BP_CTX_PRIO              1 byte    │
99      BP_CTX_LAYER2_PRES       1 byte   ─┘
100     BP_CTX_SIGNAL_SLOTS      1 byte
101     BP_CTX_OUTFILE           63 bytes
164     BP_CTX_HEX_TRACE         1 byte
165     BP_CTX_SIGNALS           16 bytes
```

The three marked runs (offsets 17-22, 23-28, 92-99) are the primary candidates for wide-load
optimisation in a firmware port. Each is a natural 6 or 8-byte aligned group of tightly related
fields used together in a single builder function.
