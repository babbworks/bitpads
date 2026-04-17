; ═══════════════════════════════════════════════════════════════════════════════
; bitpads.inc — Central constants and structure definitions for BitPads v2
;
; Updated: April 2026 — includes all missing symbols from layer2.asm, task.asm, etc.
; Linux port: System Constants block updated for Linux x86-64 native ABI.
; ═══════════════════════════════════════════════════════════════════════════════

; ── System Constants ─────────────────────────────────────────────────────────
; Linux x86-64 native syscall numbers (no BSD class offset).
; macOS used: SYS_EXIT=0x2000001, SYS_WRITE=0x2000004, SYS_OPEN=0x2000005, SYS_CLOSE=0x2000006
; macOS used: O_CREAT=0x0200, O_TRUNC=0x0400
SYS_EXIT    equ 60
SYS_WRITE   equ 1
SYS_OPEN    equ 2
SYS_CLOSE   equ 3

STDOUT      equ 1
STDERR      equ 2

O_WRONLY    equ 0x0001
O_CREAT     equ 0x40
O_TRUNC     equ 0x200

; ── Buffer Sizes ─────────────────────────────────────────────────────────────
BP_OUTBUF_SIZE          equ 4096    ; max output frame buffer (generous for all frame types)

; ── BitPads Protocol v2 Constants ───────────────────────────────────────────

BPv2_L1_SIZE            equ 8
BPv2_L2_SIZE            equ 6
BPv2_L3_SIZE            equ 5

; Layer 1 constants
BPv2_L1_SOH             equ 0x80
BPv2_L1_DOMAIN          equ 0x30
BPv2_L1_ENHANCE         equ 0x10
BPv2_L1_CRC15_POLY      equ 0x0003

; Layer 2 constants
BPv2_L2_TXTYPE_PREC     equ 0x40    ; Pre-converted (bits 7-6 = 01)
BPv2_L2_RESERVED        equ 0x01    ; Reserved bit 0 must always be 1

; Meta Byte 1 constants
BPv2_META1_MODE         equ 0x80    ; 1 = Record mode
BPv2_META1_ACK_SYSCTX   equ 0x40
BPv2_META1_CONT         equ 0x20
BPv2_META1_TREAT        equ 0x10    ; Treatment switch (Role B)

; Role A flags (Wave basic)
BPv2_META1_ROLA_PRIO    equ 0x08

; Role C flags (Record)
BPv2_META1_ROLC_VAL     equ 0x08
BPv2_META1_ROLC_TIME    equ 0x04
BPv2_META1_ROLC_TASK    equ 0x02
BPv2_META1_ROLC_NOTE    equ 0x01

; Meta Byte 2 constants
BPv2_META2_TIMESEL      equ 0x0C    ; mask for time selector bits (bits 3-2)
BPv2_META2_TIMESEL_NONE equ 0x00
BPv2_META2_TIMESEL_T1S  equ 0x04    ; Tier 1 session offset
BPv2_META2_TIMESEL_T1E  equ 0x08    ; Tier 1 external
BPv2_META2_TIMESEL_T2   equ 0x0C    ; Tier 2
BPv2_META2_SETUP        equ 0x02
BPv2_META2_SLOTS        equ 0x01

; Domain codes
BP_DOMAIN_FIN           equ 0
BP_DOMAIN_ENG           equ 1
BP_DOMAIN_HYBRID        equ 2
BP_DOMAIN_CUSTOM        equ 3

; Transmission types
BP_TYPE_SIGNAL          equ 0
BP_TYPE_WAVE            equ 1
BP_TYPE_RECORD          equ 2
BP_TYPE_LEDGER          equ 3
BP_TYPE_TELEM           equ 4

; Account pair codes for Layer 3
BP_ACCT_DEBIT_CRED      equ 1
BP_ACCT_COMPOUND        equ 0x0F

; Category codes (for Wave / Record)
BP_CAT_PLAIN_VALUE      equ 0
BP_CAT_BASIC_REC        equ 4
BP_CAT_COMPACT_CMD      equ 0x0C    ; 1100
BP_CAT_CTX_DECL         equ 0x0D    ; 1101
BP_CAT_TELEGRAPH        equ 0x0E    ; 1110

; Value tiers
BP_TIER1_BYTES          equ 1
BP_TIER2_BYTES          equ 2
BP_TIER3_BYTES          equ 3
BP_TIER4_BYTES          equ 4

; Signal Slot Presence bits
BP_SSP_P4               equ 0x80
BP_SSP_P5               equ 0x40
BP_SSP_P6               equ 0x20
BP_SSP_P7               equ 0x10
BP_SSP_P8               equ 0x08
BP_SSP_RES              equ 0x07    ; reserved bits must be 1

; Signal slot numbers
BP_SLOT_P4              equ 4
BP_SLOT_P5              equ 5
BP_SLOT_P6              equ 6
BP_SLOT_P7              equ 7
BP_SLOT_P8              equ 8

; Compound prefix ceiling codes (for BP_CTX_COMPOUND_MAX → layer2 byte[5] bits5-4)
BP_CMAX_NONE            equ 0    ; 00 = no compound groups in this batch
BP_CMAX_3               equ 1    ; 01 = up to 3 compound groups
BP_CMAX_7               equ 2    ; 10 = up to 7 compound groups
BP_CMAX_UNLIM           equ 3    ; 11 = unlimited compound groups

; Layer 2 transmission type CLI codes (stored in BP_CTX_L2_TXTYPE, converted at build time)
BP_L2_TXTYPE_CLI_PREC   equ 0   ; pre-converted — values already in declared denomination (wire: 0x40)
BP_L2_TXTYPE_CLI_COPY   equ 1   ; copy — raw source values (wire: 0x80)
BP_L2_TXTYPE_CLI_REP    equ 2   ; represented — values represent another entity (wire: 0xC0)

; CLI output modes
BP_OUTMODE_FILE         equ 0
BP_OUTMODE_DRYRUN       equ 1
BP_OUTMODE_HEX          equ 2
BP_OUTMODE_HEX_RAW      equ 3

; Task component flags (in BP_CTX_TASK_BYTE)
BP_TASK_TARGET          equ 0x80    ; bit 7: target entity byte follows
BP_TASK_TIMING          equ 0x01    ; bit 0 (LSB): timing offset byte follows

; Setup byte flags
BP_SETUP_CTX            equ 0x02    ; standalone context
BP_SETUP_ROUND          equ 0x01    ; physical rounding

; C0 Grammar flags
C0_CODE_MASK            equ 0x1F
C0_FLAG_PRIO            equ 0x80
C0_FLAG_ACK             equ 0x40
C0_FLAG_CONT            equ 0x20

; ── bp_ctx structure offsets ────────────────────────────────────────────────
BP_CTX_SIZE             equ 256     ; total size of context block

BP_CTX_TYPE             equ 0
BP_CTX_DOMAIN           equ 1
BP_CTX_PERMISSIONS      equ 2
BP_CTX_L2_TXTYPE        equ 3       ; CLI tx type code (BP_L2_TXTYPE_CLI_*)
BP_CTX_SENDER_ID        equ 4       ; dword (32-bit)
BP_CTX_SUB_ENTITY       equ 8
BP_CTX_SPLIT_MODE       equ 9
BP_CTX_ENHANCEMENT      equ 10
BP_CTX_CATEGORY         equ 11
BP_CTX_VALUE            equ 12      ; dword
BP_CTX_VALUE_PRES       equ 16
BP_CTX_VALUE_TIER       equ 17
BP_CTX_SF_INDEX         equ 18
BP_CTX_DP               equ 19
BP_CTX_TIME_VAL         equ 20
BP_CTX_TIME_PRES        equ 21
BP_CTX_TIME_TIER        equ 22
BP_CTX_TASK_BYTE        equ 23      ; 3 bytes for task data
BP_CTX_TASK_PRES        equ 26
BP_CTX_NOTE_LEN         equ 27
BP_CTX_NOTE_PRES        equ 28
BP_CTX_NOTE_DATA        equ 29      ; up to 63 bytes of note text
BP_CTX_ARCHETYPE        equ 80      ; Meta2 upper nibble, separated from category
BP_CTX_TIME_EXT         equ 81      ; word: Tier2 full time value (--time-ext)
BP_CTX_L2_BELLS         equ 83      ; bits7-6 for layer2 byte2
BP_CTX_L2_GROUP_SEP     equ 84      ; 6-bit group separator count
BP_CTX_L2_REC_SEP       equ 85      ; 5-bit record separator count
BP_CTX_L2_FILE_SEP      equ 86      ; 3-bit file separator count
BP_CTX_L2_CURRENCY      equ 87      ; 6-bit currency/qtype code
BP_CTX_L2_ROUND_BAL     equ 88      ; 4-bit rounding balance
BP_CTX_L3_EXT           equ 89      ; 1=layer3 extension byte present
BP_CTX_L3_EXT_BYTE      equ 90      ; layer3 extension payload
BP_CTX_COMPOUND_MAX     equ 91      ; 2-bit compound prefix ceiling (BP_CMAX_*)
BP_CTX_ACCT_PAIR        equ 92
BP_CTX_DIRECTION        equ 93
BP_CTX_COMPLETENESS     equ 94
BP_CTX_COMPOUND         equ 95
BP_CTX_ACK_REQ          equ 96
BP_CTX_CONT             equ 97
BP_CTX_PRIO             equ 98
BP_CTX_LAYER2_PRES      equ 99
BP_CTX_SIGNAL_SLOTS     equ 100
BP_CTX_OUTFILE          equ 101     ; null-terminated filename (max 63 chars)
BP_CTX_HEX_TRACE        equ 164
BP_CTX_OUTMODE          equ 181     ; BP_OUTMODE_*
BP_CTX_PRINT_SIZE       equ 182     ; print "<n> bytes" on success
BP_CTX_COUNT            equ 183     ; repeat count for runtime loop (default 1)

; Signals array (for P4–P8 enhanced C0 slots)
BP_CTX_SIGNALS          equ 165     ; 16 bytes reserved for signal slot data

; End of structure
BP_CTX_END              equ 256

; ── End of bitpads.inc ───────────────────────────────────────────────────────
