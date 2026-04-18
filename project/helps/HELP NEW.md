BITPADS CLI TOOL - HELP
══════════════════════════════════════════════════════════════════════════════

Ultra-compact binary protocol for records, signals, and double-entry ledgers.

USAGE:
    bitpads --type <type> --out <filename> [options]

TRANSMISSION TYPES:
    signal   Pure Signal (1 byte)          - C0 control signals (SOH, BEL, EOT...)
    wave     Wave (2-6 bytes)              - Lightweight data, commands, telemetry
    record   Record (12-21+ bytes)         - Structured records with optional blocks
    ledger   BitLedger (28+ bytes)         - Full double-entry accounting record

CORE OPTIONS:
    --type <signal|wave|record|ledger>     Transmission type (required)
    --out <filename.bp>                    Output binary file (required)

IDENTITY & SESSION:
    --domain <fin|eng|hybrid|custom>       Domain (default: fin)
    --sender <0xHEX32>                     32-bit sender Node ID (e.g. 0xDEADBEEF)
    --subentity <0-31>                     Sub-entity / department ID
    --enhance                              Enable C0 Enhancement Grammar
    --perms <0-15>                         Permissions (Read/Write/Correct/Proxy)

VALUE ENCODING:
    --value <uint32>                       Integer value to encode
    --tier <1|2|3|4>                       Value tier (default: 3 = 3 bytes)
    --sf <0|1|2|3>                         Scaling factor (0=x1, 1=x1000, 2=x1M, 3=x1B)
    --dp <0|2|4|6>                         Decimal places (default: 2)

TIME:
    --time <0-255>                         Time value (offset or reference)
    --time-tier <0|1|2|3>                  Time tier (0=none, 1=T1 session, 2=T1 ext, 3=T2)

LEDGER-SPECIFIC (for --type ledger):
    --acct <0-15>                          Account pair code (double-entry relationship)
    --dir <0-3>                            Direction / sub-type
    --compound                             Enable compound transaction mode
    --complete                             Set completeness bit (partial record)

FLAGS:
    --ack                                  Request acknowledgement
    --cont                                 Continuation / fragment
    --prio                                 Elevated priority
    --layer2                               Include Layer 2 batch context
    --trace                                Generate .trace hex dump file

SPECIAL CATEGORIES (Wave/Record):
    --category <0-15>                      Category code
        12 (0x0C)  Compact Command
        13 (0x0D)  Context Declaration
        14 (0x0E)  Telegraph Emulation

NOTE / TASK:
    --note "Your text here"                Attach human-readable note
    --task <hex8>                          Task short-form byte

EXAMPLES:

  Simple financial Wave ($1,247.50):
    bitpads --type wave --out pay.bp --value 124750 --dp 2

  BitLedger debit entry:
    bitpads --type ledger --out entry.bp --acct 1 --dir 1 --value 50000 --dp 2 --compound

  Telegraph status (OK):
    bitpads --type wave --category 14 --out status.bp --task 0x00

  Pure SOH signal (session open):
    bitpads --type signal --category 1 --out soh.bp --prio

  Record with note and trace:
    bitpads --type record --out rec.bp --value 1000 --note "Invoice #123" --trace

OUTPUT:
    <filename>.bp      → Raw binary BitPads frame
    <filename>.bp.trace → Annotated hex + binary dump (with --trace)

TECHNICAL NOTES:
    • Layer 1 (8 bytes): Session header + CRC-15
    • Layer 2 (6 bytes): Batch context (optional)
    • Layer 3 (5 bytes): Double-entry BitLedger core (ledger type only)
    • Meta Byte 1 & 2: Universal frame descriptor
    • Value tiers: 1-4 bytes with scaling & decimals
    • Telegraph mode: Ultra-minimal messaging (category 14)

For full protocol details see:
    assemblycli/guides/technical_overview.md
    assemblycli/guides/cli_guide.md
    Source comments in *.asm files

Report bugs or request features at:
https://github.com/babbworks/bitpads

══════════════════════════════════════════════════════════════════════════════