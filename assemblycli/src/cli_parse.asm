; ═══════════════════════════════════════════════════════════════════════════════
; cli_parse.asm — Command-Line Argument Parser
;
; Parses argv[] into a bp_ctx structure. Every recognised flag maps to one or
; more fields in the context block.  Unknown flags are silently ignored so that
; future flag additions do not break older callers.
;
; SUPPORTED FLAGS:
;   --type <signal|wave|record|ledger>   BP_CTX_TYPE
;   --domain <fin|eng|hybrid|custom>     BP_CTX_DOMAIN
;   --sender <hex32>                     BP_CTX_SENDER_ID (32-bit hex, e.g. 0xDEAD1234)
;   --subentity <0-31>                   BP_CTX_SUB_ENTITY
;   --category <0-15>                    BP_CTX_CATEGORY (Wave Role B category)
;   --value <uint32>                     BP_CTX_VALUE + BP_CTX_VALUE_PRES
;   --tier <1|2|3|4>                     BP_CTX_VALUE_TIER
;   --sf <0|1|2|3>                       BP_CTX_SF_INDEX (x1/x1k/x1M/x1B)
;   --dp <0|2|4|6>                       BP_CTX_DP
;   --time <0-255>                       BP_CTX_TIME_VAL + BP_CTX_TIME_PRES
;   --time-tier <0|1|2|3>               BP_CTX_TIME_TIER
;   --task <hex8>                        BP_CTX_TASK_BYTE + BP_CTX_TASK_PRES
;   --note <string>                      BP_CTX_NOTE_DATA + BP_CTX_NOTE_LEN + PRES
;   --acct <0-15>                        BP_CTX_ACCT_PAIR
;   --dir <0-3>                          BP_CTX_DIRECTION
;   --compound                           BP_CTX_COMPOUND = 1
;   --complete                           BP_CTX_COMPLETENESS = 1
;   --ack                                BP_CTX_ACK_REQ = 1
;   --cont                               BP_CTX_CONT = 1
;   --prio                               BP_CTX_PRIO = 1
;   --layer2                             BP_CTX_LAYER2_PRES = 1
;   --setup                              forces setup byte (set via Meta2)
;   --enhance                            BP_CTX_ENHANCEMENT = 1
;   --perms <0-15>                       BP_CTX_PERMISSIONS (4-bit read/write/corr/proxy)
;   --split <0|1|2>                      BP_CTX_SPLIT_MODE
;   --txtype <pre|copy|rep|0|1|2>        BP_CTX_L2_TXTYPE (Layer 2 tx type code)
;   --compound-max <none|3|7|unlim|0-3>  BP_CTX_COMPOUND_MAX (Layer 2 compound prefix ceiling)
;   --out <filename>                     BP_CTX_OUTFILE
;   --trace                              BP_CTX_HEX_TRACE = 1
;
; PARSING APPROACH:
;   We iterate over argv[1..argc-1].  Each argument is compared against known
;   flag strings using byte-by-byte comparison.  For flags that take a value
;   argument, the next argv entry is parsed as a decimal or hex integer.
;
; Exports: cli_parse
; Input:   rdi = argc (int), rsi = argv (char**)
; Output:  rdi = pointer to bp_ctx (address of the static ctx block)
;          rax = 0 on success, -1 if required args missing
; ═══════════════════════════════════════════════════════════════════════════════

    %include "include/bitpads.inc"
    %include "include/syscall.inc"
    %include "include/macros.inc"

    global cli_parse

section .data

; ── Error / usage message ─────────────────────────────────────────────────────
usage_msg   db "Usage: bitpads --type <signal|wave|record|ledger|telem> --out <file> [options]", 10
            db "Options:", 10
            db "  --domain <fin|eng|hybrid|custom>", 10
            db "  --sender <hex32>   --subentity <0-31>", 10
            db "  --category <0-15>  --value <uint32>   --tier <1-4>", 10
            db "  --sf <0-3>         --dp <0|2|4|6>", 10
            db "  --time <0-255>     --time-tier <0-3>", 10
            db "  --task <hex8>      --note <text>", 10
            db "  --acct <0-15>      --dir <0-3>", 10
            db "  --ack  --cont  --prio  --compound  --complete", 10
            db "  --layer2  --enhance  --perms <0-15>  --split <0-2>", 10
            db "  --txtype <pre|copy|rep|0|1|2>  --compound-max <none|3|7|unlim>", 10
            db "  --currency <0-63>  --round-bal <0-15>  --sep-group <0-63>  --sep-record <0-31>  --sep-file <0-7>  --bells <0-3>", 10
            db "  --archetype <0-15>  --time-ext <0-65535>", 10
            db "  --task-code <0-63>  --task-target <0-255>  --task-timing <0-255>", 10
            db "  --slot-p4 <hex8> ... --slot-p8 <hex8>  --l3-ext <hex8>", 10
            db "  --cmd-class <0-15> --cmd-params <0-3> --cmd-p1 <0-255> --cmd-p2 <0-255> --cmd-resp --cmd-chain", 10
            db "  --tel-type <status|value|command|identity|text|heartbeat|priority|extended> --tel-data <0-31>", 10
            db "  --dry-run --hex --hex-raw --print-size --count <1-255>", 10
            db "  --trace", 10
usage_len   equ $ - usage_msg

; ── Known flag strings (null-terminated) ─────────────────────────────────────
; Keep these aligned for efficient comparison.  Shorter strings go first.
flag_type      db "--type",      0
flag_domain    db "--domain",    0
flag_sender    db "--sender",    0
flag_sub       db "--subentity", 0
flag_cat       db "--category",  0
flag_value     db "--value",     0
flag_tier      db "--tier",      0
flag_sf        db "--sf",        0
flag_dp        db "--dp",        0
flag_time      db "--time",      0
flag_timetier  db "--time-tier", 0
flag_task      db "--task",      0
flag_note      db "--note",      0
flag_acct      db "--acct",      0
flag_dir       db "--dir",       0
flag_compound  db "--compound",  0
flag_complete  db "--complete",  0
flag_ack       db "--ack",       0
flag_cont      db "--cont",      0
flag_prio      db "--prio",      0
flag_layer2    db "--layer2",    0
flag_enhance   db "--enhance",   0
flag_perms     db "--perms",     0
flag_split     db "--split",     0
flag_txtype    db "--txtype",    0
flag_cmax      db "--compound-max", 0
flag_currency  db "--currency",  0
flag_roundbal  db "--round-bal", 0
flag_sepgrp    db "--sep-group", 0
flag_seprec    db "--sep-record",0
flag_sepfile   db "--sep-file",  0
flag_bells     db "--bells",     0
flag_archetype db "--archetype", 0
flag_timeext   db "--time-ext",  0
flag_taskcode  db "--task-code", 0
flag_tasktarget db "--task-target", 0
flag_tasktiming db "--task-timing", 0
flag_slot_p4   db "--slot-p4",   0
flag_slot_p5   db "--slot-p5",   0
flag_slot_p6   db "--slot-p6",   0
flag_slot_p7   db "--slot-p7",   0
flag_slot_p8   db "--slot-p8",   0
flag_l3ext     db "--l3-ext",    0
flag_cmd_class db "--cmd-class", 0
flag_cmd_params db "--cmd-params", 0
flag_cmd_p1    db "--cmd-p1",    0
flag_cmd_p2    db "--cmd-p2",    0
flag_cmd_resp  db "--cmd-resp",  0
flag_cmd_chain db "--cmd-chain", 0
flag_tel_type  db "--tel-type",  0
flag_tel_data  db "--tel-data",  0
flag_dryrun    db "--dry-run",   0
flag_hex       db "--hex",       0
flag_hexraw    db "--hex-raw",   0
flag_printsize db "--print-size",0
flag_count     db "--count",     0
flag_out       db "--out",       0
flag_trace     db "--trace",     0

; ── Domain name strings ───────────────────────────────────────────────────────
dom_fin    db "fin",    0
dom_eng    db "eng",    0
dom_hyb    db "hybrid", 0
dom_cust   db "custom", 0

; ── Type name strings ─────────────────────────────────────────────────────────
typ_signal  db "signal",  0
typ_wave    db "wave",    0
typ_record  db "record",  0
typ_ledger  db "ledger",  0
typ_telem   db "telem",   0

; ── Layer 2 tx type / compound max strings ───────────────────────────────────
txt_pre     db "pre",       0
txt_prec    db "prec",      0
txt_copy    db "copy",      0
txt_rep     db "rep",       0
txt_repr    db "represented", 0

cmax_none   db "none",      0
cmax_unlim  db "unlim",     0
cmax_unl    db "unlimited", 0

tel_status  db "status",    0
tel_value   db "value",     0
tel_cmd     db "command",   0
tel_ident   db "identity",  0
tel_text    db "text",      0
tel_heart   db "heartbeat", 0
tel_prio    db "priority",  0
tel_ext     db "extended",  0

section .bss
    the_ctx     resb BP_CTX_SIZE    ; the single bp_ctx structure for this process
                                    ; zero-initialised by the OS at startup (BSS section)

section .text
default rel

; ─────────────────────────────────────────────────────────────────────────────
; Helper: streq
;   Compare two null-terminated strings.
;   rdi = string 1, rsi = string 2
;   Returns: ZF set if equal, ZF clear if not equal
;   Clobbers: rax, rcx
; ─────────────────────────────────────────────────────────────────────────────
streq:
.loop:
    movzx   eax, byte [rdi]         ; load next char from string 1
    movzx   ecx, byte [rsi]         ; load next char from string 2
    cmp     al, cl                  ; do they match?
    jne     .neq                    ; no → strings differ
    test    al, al                  ; end of string?
    jz      .eq                     ; yes → equal (both hit null together)
    inc     rdi                     ; advance both pointers
    inc     rsi
    jmp     .loop
.eq:
    cmp     al, al                  ; set ZF=1 (equal)
    ret
.neq:
    or      al, 1                   ; clear ZF (not equal) — cmp al,1 will not set ZF
    cmp     al, 0                   ; ZF=0 if al≠0 (which it is after `or al,1`)
    ret

; ─────────────────────────────────────────────────────────────────────────────
; Helper: parse_uint32
;   Parse a null-terminated ASCII decimal or hex ("0x...") number.
;   rdi = pointer to string
;   Returns: rax = parsed value (32-bit, zero-extended into rax)
;   Clobbers: rax, rcx, rdx, rsi
; ─────────────────────────────────────────────────────────────────────────────
parse_uint32:
    xor     eax, eax                ; accumulator = 0
    movzx   ecx, byte [rdi]         ; first character

    ; Check for "0x" hex prefix
    cmp     cl, '0'
    jne     .decimal_loop           ; not '0' → parse decimal
    movzx   ecx, byte [rdi + 1]
    cmp     cl, 'x'
    je      .hex_prefix
    cmp     cl, 'X'
    jne     .decimal_loop           ; "0" followed by non-x → decimal

.hex_prefix:
    add     rdi, 2                  ; skip past "0x"
.hex_loop:
    movzx   ecx, byte [rdi]
    test    cl, cl
    jz      .done_parse             ; null terminator → done
    cmp     cl, '0'
    jl      .done_parse
    cmp     cl, '9'
    jle     .hex_digit
    cmp     cl, 'a'
    jl      .check_upper_hex
    cmp     cl, 'f'
    jg      .done_parse
    sub     cl, 'a' - 10            ; 'a'-'f' → 10-15
    jmp     .hex_accumulate
.check_upper_hex:
    cmp     cl, 'A'
    jl      .done_parse
    cmp     cl, 'F'
    jg      .done_parse
    sub     cl, 'A' - 10            ; 'A'-'F' → 10-15
    jmp     .hex_accumulate
.hex_digit:
    sub     cl, '0'                 ; '0'-'9' → 0-9
.hex_accumulate:
    shl     eax, 4                  ; accumulator <<= 4
    or      al, cl                  ; accumulator |= digit
    inc     rdi
    jmp     .hex_loop

.decimal_loop:
    movzx   ecx, byte [rdi]
    test    cl, cl
    jz      .done_parse
    cmp     cl, '0'
    jl      .done_parse
    cmp     cl, '9'
    jg      .done_parse
    sub     cl, '0'                 ; convert ASCII digit to integer
    imul    eax, eax, 10            ; accumulator *= 10
    add     eax, ecx                ; accumulator += digit
    inc     rdi
    jmp     .decimal_loop

.done_parse:
    ret

; parse_u8_strict
;   Parse uint32 then enforce <=255
;   in: rdi string, out: rax value, rdx=0 ok / 1 invalid
parse_u8_strict:
    call    parse_uint32
    cmp     eax, 255
    jbe     .u8_ok
    mov     edx, 1
    ret
.u8_ok:
    xor     edx, edx
    ret

; parse_u16_strict
;   Parse uint32 then enforce <=65535
;   in: rdi string, out: rax value, rdx=0 ok / 1 invalid
parse_u16_strict:
    call    parse_uint32
    cmp     eax, 65535
    jbe     .u16_ok
    mov     edx, 1
    ret
.u16_ok:
    xor     edx, edx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; Helper: copy_string
;   Copy at most 63 bytes from rsi into [rdi], null-terminate.
;   Clobbers: rax, rcx
; ─────────────────────────────────────────────────────────────────────────────
copy_string:
    xor     ecx, ecx
.cs_loop:
    cmp     ecx, 63                 ; limit to 63 bytes
    jge     .cs_null
    movzx   eax, byte [rsi + rcx]
    test    al, al
    jz      .cs_null
    mov     byte [rdi + rcx], al
    inc     ecx
    jmp     .cs_loop
.cs_null:
    mov     byte [rdi + rcx], 0     ; null-terminate
    ret

; ─────────────────────────────────────────────────────────────────────────────
; cli_parse
;   Main argument parsing entry point.
;
; Input:  rdi = argc (number of arguments including argv[0])
;         rsi = argv  (array of char* pointers)
; Output: rdi = &the_ctx (pointer to the populated bp_ctx)
;         rax = 0 on success, -1 if --type or --out not provided
; ─────────────────────────────────────────────────────────────────────────────
cli_parse:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 8                  ; align stack

    ; ── Preserve argc and argv ────────────────────────────────────────────
    mov     r14d, edi               ; r14d = argc
    mov     r15, rsi                ; r15  = argv

    ; ── Set bp_ctx defaults ───────────────────────────────────────────────
    ; BSS is zero-initialised, but we set explicit meaningful defaults here.
    lea     rbx, [the_ctx]          ; rbx = &the_ctx

    mov     byte [rbx + BP_CTX_TYPE],       BP_TYPE_WAVE    ; default: Wave transmission
    mov     byte [rbx + BP_CTX_DOMAIN],     BP_DOMAIN_FIN   ; default: Financial domain
    mov     byte [rbx + BP_CTX_VALUE_TIER], 2               ; default: Tier 3 (24-bit value)
    mov     byte [rbx + BP_CTX_SF_INDEX],   0               ; default: x1 scaling factor
    mov     byte [rbx + BP_CTX_DP],         2               ; default: 2 decimal places
    mov     byte [rbx + BP_CTX_L2_TXTYPE],  BP_L2_TXTYPE_CLI_PREC
    mov     byte [rbx + BP_CTX_COMPOUND_MAX], BP_CMAX_NONE
    mov     byte [rbx + BP_CTX_ARCHETYPE],  0
    mov     byte [rbx + BP_CTX_OUTMODE],    BP_OUTMODE_FILE
    mov     byte [rbx + BP_CTX_COUNT],      1

    ; ── Main parse loop: iterate argv[1..argc-1] ──────────────────────────
    mov     r12d, 1                 ; r12d = argv index, starts at 1 (skip argv[0])

.arg_loop:
    cmp     r12d, r14d              ; have we processed all arguments?
    jge     .parse_done

    mov     r13, [r15 + r12 * 8]   ; r13 = argv[r12] = pointer to current argument string
    inc     r12d                    ; pre-advance to next (will be used for value args)

    ; ── Test each known flag ───────────────────────────────────────────────
    ; We use the streq helper which preserves rdi/rsi on the call but we
    ; reload r13 before each comparison. The actual check clobbers rdi/rsi.

    ; --type
    lea     rdi, [flag_type]
    mov     rsi, r13
    call    streq
    jne     .chk_domain
    mov     r13, [r15 + r12 * 8]   ; r13 = value argument (next argv)
    inc     r12d
    lea     rdi, [typ_signal]
    mov     rsi, r13
    call    streq
    jne     .type_wave
    mov     byte [rbx + BP_CTX_TYPE], BP_TYPE_SIGNAL
    jmp     .arg_loop
.type_wave:
    lea     rdi, [typ_wave]
    mov     rsi, r13
    call    streq
    jne     .type_record
    mov     byte [rbx + BP_CTX_TYPE], BP_TYPE_WAVE
    jmp     .arg_loop
.type_record:
    lea     rdi, [typ_record]
    mov     rsi, r13
    call    streq
    jne     .type_ledger
    mov     byte [rbx + BP_CTX_TYPE], BP_TYPE_RECORD
    jmp     .arg_loop
.type_ledger:
    lea     rdi, [typ_ledger]
    mov     rsi, r13
    call    streq
    jne     .type_telem
    mov     byte [rbx + BP_CTX_TYPE], BP_TYPE_LEDGER
    jmp     .arg_loop
.type_telem:
    mov     byte [rbx + BP_CTX_TYPE], BP_TYPE_TELEM
    jmp     .arg_loop

.chk_domain:
    lea     rdi, [flag_domain]
    mov     rsi, r13
    call    streq
    jne     .chk_sender
    mov     r13, [r15 + r12 * 8]
    inc     r12d
    lea     rdi, [dom_fin]
    mov     rsi, r13
    call    streq
    jne     .dom_eng
    mov     byte [rbx + BP_CTX_DOMAIN], BP_DOMAIN_FIN
    jmp     .arg_loop
.dom_eng:
    lea     rdi, [dom_eng]
    mov     rsi, r13
    call    streq
    jne     .dom_hyb
    mov     byte [rbx + BP_CTX_DOMAIN], BP_DOMAIN_ENG
    jmp     .arg_loop
.dom_hyb:
    lea     rdi, [dom_hyb]
    mov     rsi, r13
    call    streq
    jne     .dom_cust
    mov     byte [rbx + BP_CTX_DOMAIN], BP_DOMAIN_HYBRID
    jmp     .arg_loop
.dom_cust:
    mov     byte [rbx + BP_CTX_DOMAIN], BP_DOMAIN_CUSTOM
    jmp     .arg_loop

.chk_sender:
    lea     rdi, [flag_sender]
    mov     rsi, r13
    call    streq
    jne     .chk_sub
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32            ; rax = 32-bit sender ID
    mov     dword [rbx + BP_CTX_SENDER_ID], eax
    jmp     .arg_loop

.chk_sub:
    lea     rdi, [flag_sub]
    mov     rsi, r13
    call    streq
    jne     .chk_cat
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    and     al, 0x1F                ; mask to 5 bits (0-31)
    mov     byte [rbx + BP_CTX_SUB_ENTITY], al
    jmp     .arg_loop

.chk_cat:
    lea     rdi, [flag_cat]
    mov     rsi, r13
    call    streq
    jne     .chk_value
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    and     al, 0x0F                ; mask to 4 bits (0-15)
    mov     byte [rbx + BP_CTX_CATEGORY], al
    jmp     .arg_loop

.chk_value:
    lea     rdi, [flag_value]
    mov     rsi, r13
    call    streq
    jne     .chk_tier
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    mov     dword [rbx + BP_CTX_VALUE], eax
    mov     byte  [rbx + BP_CTX_VALUE_PRES], 1
    jmp     .arg_loop

.chk_tier:
    lea     rdi, [flag_tier]
    mov     rsi, r13
    call    streq
    jne     .chk_sf
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    dec     eax                     ; convert 1-based (T1=1) to 0-based (T1=0)
    and     al, 0x03                ; clamp to 0-3
    mov     byte [rbx + BP_CTX_VALUE_TIER], al
    jmp     .arg_loop

.chk_sf:
    lea     rdi, [flag_sf]
    mov     rsi, r13
    call    streq
    jne     .chk_dp
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    and     al, 0x03
    mov     byte [rbx + BP_CTX_SF_INDEX], al
    jmp     .arg_loop

.chk_dp:
    lea     rdi, [flag_dp]
    mov     rsi, r13
    call    streq
    jne     .chk_time
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    and     al, 0x07                ; clamp: valid values 0, 2, 4, 6
    mov     byte [rbx + BP_CTX_DP], al
    jmp     .arg_loop

.chk_time:
    lea     rdi, [flag_time]
    mov     rsi, r13
    call    streq
    jne     .chk_timetier
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    mov     byte [rbx + BP_CTX_TIME_VAL], al
    mov     byte [rbx + BP_CTX_TIME_PRES], 1
    cmp     byte [rbx + BP_CTX_TIME_TIER], 0  ; if tier not set yet, default to Tier 1
    jne     .arg_loop
    mov     byte [rbx + BP_CTX_TIME_TIER], 1   ; default time tier = T1 session offset
    jmp     .arg_loop

.chk_timetier:
    lea     rdi, [flag_timetier]
    mov     rsi, r13
    call    streq
    jne     .chk_task
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    and     al, 0x03
    mov     byte [rbx + BP_CTX_TIME_TIER], al
    jmp     .arg_loop

.chk_task:
    lea     rdi, [flag_task]
    mov     rsi, r13
    call    streq
    jne     .chk_note
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    mov     byte [rbx + BP_CTX_TASK_BYTE], al
    mov     byte [rbx + BP_CTX_TASK_PRES], 1
    jmp     .arg_loop

.chk_note:
    lea     rdi, [flag_note]
    mov     rsi, r13
    call    streq
    jne     .chk_acct
    mov     rsi, [r15 + r12 * 8]   ; rsi = note string pointer
    inc     r12d
    ; Measure note length (up to 63 bytes)
    xor     ecx, ecx
.note_len_loop:
    cmp     ecx, 63
    jge     .note_len_done
    cmp     byte [rsi + rcx], 0
    je      .note_len_done
    inc     ecx
    jmp     .note_len_loop
.note_len_done:
    mov     byte [rbx + BP_CTX_NOTE_LEN], cl
    mov     byte [rbx + BP_CTX_NOTE_PRES], 1
    ; Copy note bytes into ctx
    lea     rdi, [rbx + BP_CTX_NOTE_DATA]
    call    copy_string             ; copies up to 63 bytes from rsi to rdi
    jmp     .arg_loop

.chk_acct:
    lea     rdi, [flag_acct]
    mov     rsi, r13
    call    streq
    jne     .chk_dir
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    and     al, 0x0F
    mov     byte [rbx + BP_CTX_ACCT_PAIR], al
    jmp     .arg_loop

.chk_dir:
    lea     rdi, [flag_dir]
    mov     rsi, r13
    call    streq
    jne     .chk_compound
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    and     al, 0x03
    mov     byte [rbx + BP_CTX_DIRECTION], al
    jmp     .arg_loop

.chk_compound:
    lea     rdi, [flag_compound]
    mov     rsi, r13
    call    streq
    jne     .chk_complete
    mov     byte [rbx + BP_CTX_COMPOUND], 1    ; enable compound mode
    jmp     .arg_loop

.chk_complete:
    lea     rdi, [flag_complete]
    mov     rsi, r13
    call    streq
    jne     .chk_ack
    mov     byte [rbx + BP_CTX_COMPLETENESS], 1  ; partial record
    jmp     .arg_loop

.chk_ack:
    lea     rdi, [flag_ack]
    mov     rsi, r13
    call    streq
    jne     .chk_cont
    mov     byte [rbx + BP_CTX_ACK_REQ], 1
    jmp     .arg_loop

.chk_cont:
    lea     rdi, [flag_cont]
    mov     rsi, r13
    call    streq
    jne     .chk_prio
    mov     byte [rbx + BP_CTX_CONT], 1
    jmp     .arg_loop

.chk_prio:
    lea     rdi, [flag_prio]
    mov     rsi, r13
    call    streq
    jne     .chk_layer2
    mov     byte [rbx + BP_CTX_PRIO], 1
    jmp     .arg_loop

.chk_layer2:
    lea     rdi, [flag_layer2]
    mov     rsi, r13
    call    streq
    jne     .chk_enhance
    mov     byte [rbx + BP_CTX_LAYER2_PRES], 1
    jmp     .arg_loop

.chk_enhance:
    lea     rdi, [flag_enhance]
    mov     rsi, r13
    call    streq
    jne     .chk_perms
    mov     byte [rbx + BP_CTX_ENHANCEMENT], 1
    jmp     .arg_loop

.chk_perms:
    lea     rdi, [flag_perms]
    mov     rsi, r13
    call    streq
    jne     .chk_split
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    and     al, 0x0F                ; mask to 4 bits (read/write/correct/proxy)
    mov     byte [rbx + BP_CTX_PERMISSIONS], al
    jmp     .arg_loop

.chk_split:
    lea     rdi, [flag_split]
    mov     rsi, r13
    call    streq
    jne     .chk_txtype
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_uint32
    and     al, 0x03
    mov     byte [rbx + BP_CTX_SPLIT_MODE], al
    jmp     .arg_loop

.chk_txtype:
    lea     rdi, [flag_txtype]
    mov     rsi, r13
    call    streq
    jne     .chk_cmax
    mov     r13, [r15 + r12 * 8]
    inc     r12d
    lea     rdi, [txt_pre]
    mov     rsi, r13
    call    streq
    je      .txtype_prec
    lea     rdi, [txt_prec]
    mov     rsi, r13
    call    streq
    je      .txtype_prec
    lea     rdi, [txt_copy]
    mov     rsi, r13
    call    streq
    je      .txtype_copy
    lea     rdi, [txt_rep]
    mov     rsi, r13
    call    streq
    je      .txtype_rep
    lea     rdi, [txt_repr]
    mov     rsi, r13
    call    streq
    je      .txtype_rep
    ; Numeric fallback: 0=pre, 1=copy, 2=rep (mask keeps range bounded)
    mov     rdi, r13
    call    parse_uint32
    and     al, 0x03
    cmp     al, BP_L2_TXTYPE_CLI_REP
    jbe     .txtype_store
    mov     al, BP_L2_TXTYPE_CLI_PREC
.txtype_store:
    mov     byte [rbx + BP_CTX_L2_TXTYPE], al
    jmp     .arg_loop
.txtype_prec:
    mov     byte [rbx + BP_CTX_L2_TXTYPE], BP_L2_TXTYPE_CLI_PREC
    jmp     .arg_loop
.txtype_copy:
    mov     byte [rbx + BP_CTX_L2_TXTYPE], BP_L2_TXTYPE_CLI_COPY
    jmp     .arg_loop
.txtype_rep:
    mov     byte [rbx + BP_CTX_L2_TXTYPE], BP_L2_TXTYPE_CLI_REP
    jmp     .arg_loop

.chk_cmax:
    lea     rdi, [flag_cmax]
    mov     rsi, r13
    call    streq
    jne     .chk_currency
    mov     r13, [r15 + r12 * 8]
    inc     r12d
    lea     rdi, [cmax_none]
    mov     rsi, r13
    call    streq
    je      .cmax_none_set
    lea     rdi, [cmax_unlim]
    mov     rsi, r13
    call    streq
    je      .cmax_unlim_set
    lea     rdi, [cmax_unl]
    mov     rsi, r13
    call    streq
    je      .cmax_unlim_set
    ; Numeric or symbolic "3"/"7" values
    mov     rdi, r13
    call    parse_uint32
    cmp     eax, 3
    je      .cmax_3_set
    cmp     eax, 7
    je      .cmax_7_set
    and     al, 0x03
    mov     byte [rbx + BP_CTX_COMPOUND_MAX], al
    jmp     .arg_loop
.cmax_none_set:
    mov     byte [rbx + BP_CTX_COMPOUND_MAX], BP_CMAX_NONE
    jmp     .arg_loop
.cmax_3_set:
    mov     byte [rbx + BP_CTX_COMPOUND_MAX], BP_CMAX_3
    jmp     .arg_loop
.cmax_7_set:
    mov     byte [rbx + BP_CTX_COMPOUND_MAX], BP_CMAX_7
    jmp     .arg_loop
.cmax_unlim_set:
    mov     byte [rbx + BP_CTX_COMPOUND_MAX], BP_CMAX_UNLIM
    jmp     .arg_loop

.chk_currency:
    lea     rdi, [flag_currency]
    mov     rsi, r13
    call    streq
    jne     .chk_roundbal
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 63
    ja      .parse_error
    mov     byte [rbx + BP_CTX_L2_CURRENCY], al
    jmp     .arg_loop

.chk_roundbal:
    lea     rdi, [flag_roundbal]
    mov     rsi, r13
    call    streq
    jne     .chk_sepgrp
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 15
    ja      .parse_error
    mov     byte [rbx + BP_CTX_L2_ROUND_BAL], al
    jmp     .arg_loop

.chk_sepgrp:
    lea     rdi, [flag_sepgrp]
    mov     rsi, r13
    call    streq
    jne     .chk_seprec
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 63
    ja      .parse_error
    mov     byte [rbx + BP_CTX_L2_GROUP_SEP], al
    jmp     .arg_loop

.chk_seprec:
    lea     rdi, [flag_seprec]
    mov     rsi, r13
    call    streq
    jne     .chk_sepfile
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 31
    ja      .parse_error
    mov     byte [rbx + BP_CTX_L2_REC_SEP], al
    jmp     .arg_loop

.chk_sepfile:
    lea     rdi, [flag_sepfile]
    mov     rsi, r13
    call    streq
    jne     .chk_bells
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 7
    ja      .parse_error
    mov     byte [rbx + BP_CTX_L2_FILE_SEP], al
    jmp     .arg_loop

.chk_bells:
    lea     rdi, [flag_bells]
    mov     rsi, r13
    call    streq
    jne     .chk_archetype
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 3
    ja      .parse_error
    mov     byte [rbx + BP_CTX_L2_BELLS], al
    jmp     .arg_loop

.chk_archetype:
    lea     rdi, [flag_archetype]
    mov     rsi, r13
    call    streq
    jne     .chk_timeext
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 15
    ja      .parse_error
    mov     byte [rbx + BP_CTX_ARCHETYPE], al
    jmp     .arg_loop

.chk_timeext:
    lea     rdi, [flag_timeext]
    mov     rsi, r13
    call    streq
    jne     .chk_taskcode
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u16_strict
    test    edx, edx
    jnz     .parse_error
    mov     word [rbx + BP_CTX_TIME_EXT], ax
    mov     byte [rbx + BP_CTX_TIME_PRES], 1
    mov     byte [rbx + BP_CTX_TIME_TIER], 3
    jmp     .arg_loop

.chk_taskcode:
    lea     rdi, [flag_taskcode]
    mov     rsi, r13
    call    streq
    jne     .chk_tasktarget
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 63
    ja      .parse_error
    shl     al, 1
    and     byte [rbx + BP_CTX_TASK_BYTE], 0x81
    or      byte [rbx + BP_CTX_TASK_BYTE], al
    mov     byte [rbx + BP_CTX_TASK_PRES], 1
    jmp     .arg_loop

.chk_tasktarget:
    lea     rdi, [flag_tasktarget]
    mov     rsi, r13
    call    streq
    jne     .chk_tasktiming
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    mov     byte [rbx + BP_CTX_TASK_BYTE + 1], al
    or      byte [rbx + BP_CTX_TASK_BYTE], BP_TASK_TARGET
    mov     byte [rbx + BP_CTX_TASK_PRES], 1
    jmp     .arg_loop

.chk_tasktiming:
    lea     rdi, [flag_tasktiming]
    mov     rsi, r13
    call    streq
    jne     .chk_slot_p4
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    mov     byte [rbx + BP_CTX_TASK_BYTE + 2], al
    or      byte [rbx + BP_CTX_TASK_BYTE], BP_TASK_TIMING
    mov     byte [rbx + BP_CTX_TASK_PRES], 1
    jmp     .arg_loop

.chk_slot_p4:
    lea     rdi, [flag_slot_p4]
    mov     rsi, r13
    call    streq
    jne     .chk_slot_p5
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    mov     byte [rbx + BP_CTX_SIGNALS + 0], 1
    mov     byte [rbx + BP_CTX_SIGNALS + 1], al
    or      byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P4
    jmp     .arg_loop

.chk_slot_p5:
    lea     rdi, [flag_slot_p5]
    mov     rsi, r13
    call    streq
    jne     .chk_slot_p6
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    mov     byte [rbx + BP_CTX_SIGNALS + 3], 1
    mov     byte [rbx + BP_CTX_SIGNALS + 4], al
    or      byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P5
    jmp     .arg_loop

.chk_slot_p6:
    lea     rdi, [flag_slot_p6]
    mov     rsi, r13
    call    streq
    jne     .chk_slot_p7
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    mov     byte [rbx + BP_CTX_SIGNALS + 6], 1
    mov     byte [rbx + BP_CTX_SIGNALS + 7], al
    or      byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P6
    jmp     .arg_loop

.chk_slot_p7:
    lea     rdi, [flag_slot_p7]
    mov     rsi, r13
    call    streq
    jne     .chk_slot_p8
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    mov     byte [rbx + BP_CTX_SIGNALS + 9], 1
    mov     byte [rbx + BP_CTX_SIGNALS + 10], al
    or      byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P7
    jmp     .arg_loop

.chk_slot_p8:
    lea     rdi, [flag_slot_p8]
    mov     rsi, r13
    call    streq
    jne     .chk_l3_ext
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    mov     byte [rbx + BP_CTX_SIGNALS + 12], 1
    mov     byte [rbx + BP_CTX_SIGNALS + 13], al
    or      byte [rbx + BP_CTX_SIGNAL_SLOTS], BP_SSP_P8
    jmp     .arg_loop

.chk_l3_ext:
    lea     rdi, [flag_l3ext]
    mov     rsi, r13
    call    streq
    jne     .chk_cmd_class
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    mov     byte [rbx + BP_CTX_L3_EXT], 1
    mov     byte [rbx + BP_CTX_L3_EXT_BYTE], al
    jmp     .arg_loop

.chk_cmd_class:
    lea     rdi, [flag_cmd_class]
    mov     rsi, r13
    call    streq
    jne     .chk_cmd_params
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 15
    ja      .parse_error
    shl     al, 4
    and     byte [rbx + BP_CTX_TASK_BYTE], 0x0F
    or      byte [rbx + BP_CTX_TASK_BYTE], al
    jmp     .arg_loop

.chk_cmd_params:
    lea     rdi, [flag_cmd_params]
    mov     rsi, r13
    call    streq
    jne     .chk_cmd_p1
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 3
    ja      .parse_error
    shl     al, 2
    and     byte [rbx + BP_CTX_TASK_BYTE], 0xF3
    or      byte [rbx + BP_CTX_TASK_BYTE], al
    jmp     .arg_loop

.chk_cmd_p1:
    lea     rdi, [flag_cmd_p1]
    mov     rsi, r13
    call    streq
    jne     .chk_cmd_p2
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    mov     byte [rbx + BP_CTX_TASK_BYTE + 1], al
    jmp     .arg_loop

.chk_cmd_p2:
    lea     rdi, [flag_cmd_p2]
    mov     rsi, r13
    call    streq
    jne     .chk_cmd_resp
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    mov     byte [rbx + BP_CTX_TASK_BYTE + 2], al
    jmp     .arg_loop

.chk_cmd_resp:
    lea     rdi, [flag_cmd_resp]
    mov     rsi, r13
    call    streq
    jne     .chk_cmd_chain
    or      byte [rbx + BP_CTX_TASK_BYTE], 0x02
    jmp     .arg_loop

.chk_cmd_chain:
    lea     rdi, [flag_cmd_chain]
    mov     rsi, r13
    call    streq
    jne     .chk_tel_type
    or      byte [rbx + BP_CTX_TASK_BYTE], 0x01
    jmp     .arg_loop

.chk_tel_type:
    lea     rdi, [flag_tel_type]
    mov     rsi, r13
    call    streq
    jne     .chk_tel_data
    mov     r13, [r15 + r12 * 8]
    inc     r12d
    lea     rdi, [tel_status]
    mov     rsi, r13
    call    streq
    je      .tel_status_set
    lea     rdi, [tel_value]
    mov     rsi, r13
    call    streq
    je      .tel_value_set
    lea     rdi, [tel_cmd]
    mov     rsi, r13
    call    streq
    je      .tel_cmd_set
    lea     rdi, [tel_ident]
    mov     rsi, r13
    call    streq
    je      .tel_ident_set
    lea     rdi, [tel_text]
    mov     rsi, r13
    call    streq
    je      .tel_text_set
    lea     rdi, [tel_heart]
    mov     rsi, r13
    call    streq
    je      .tel_heart_set
    lea     rdi, [tel_prio]
    mov     rsi, r13
    call    streq
    je      .tel_prio_set
    lea     rdi, [tel_ext]
    mov     rsi, r13
    call    streq
    je      .tel_ext_set
    jmp     .parse_error
.tel_status_set:
    and     byte [rbx + BP_CTX_TASK_BYTE], 0x1F
    jmp     .arg_loop
.tel_value_set:
    and     byte [rbx + BP_CTX_TASK_BYTE], 0x1F
    or      byte [rbx + BP_CTX_TASK_BYTE], 0x20
    jmp     .arg_loop
.tel_cmd_set:
    and     byte [rbx + BP_CTX_TASK_BYTE], 0x1F
    or      byte [rbx + BP_CTX_TASK_BYTE], 0x40
    jmp     .arg_loop
.tel_ident_set:
    and     byte [rbx + BP_CTX_TASK_BYTE], 0x1F
    or      byte [rbx + BP_CTX_TASK_BYTE], 0x60
    jmp     .arg_loop
.tel_text_set:
    and     byte [rbx + BP_CTX_TASK_BYTE], 0x1F
    or      byte [rbx + BP_CTX_TASK_BYTE], 0x80
    jmp     .arg_loop
.tel_heart_set:
    and     byte [rbx + BP_CTX_TASK_BYTE], 0x1F
    or      byte [rbx + BP_CTX_TASK_BYTE], 0xA0
    jmp     .arg_loop
.tel_prio_set:
    and     byte [rbx + BP_CTX_TASK_BYTE], 0x1F
    or      byte [rbx + BP_CTX_TASK_BYTE], 0xC0
    jmp     .arg_loop
.tel_ext_set:
    and     byte [rbx + BP_CTX_TASK_BYTE], 0x1F
    or      byte [rbx + BP_CTX_TASK_BYTE], 0xE0
    jmp     .arg_loop

.chk_tel_data:
    lea     rdi, [flag_tel_data]
    mov     rsi, r13
    call    streq
    jne     .chk_dryrun
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 31
    ja      .parse_error
    and     byte [rbx + BP_CTX_TASK_BYTE], 0xE0
    or      byte [rbx + BP_CTX_TASK_BYTE], al
    jmp     .arg_loop

.chk_dryrun:
    lea     rdi, [flag_dryrun]
    mov     rsi, r13
    call    streq
    jne     .chk_hex
    mov     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_DRYRUN
    jmp     .arg_loop

.chk_hex:
    lea     rdi, [flag_hex]
    mov     rsi, r13
    call    streq
    jne     .chk_hexraw
    mov     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_HEX
    jmp     .arg_loop

.chk_hexraw:
    lea     rdi, [flag_hexraw]
    mov     rsi, r13
    call    streq
    jne     .chk_printsize
    mov     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_HEX_RAW
    jmp     .arg_loop

.chk_printsize:
    lea     rdi, [flag_printsize]
    mov     rsi, r13
    call    streq
    jne     .chk_count
    mov     byte [rbx + BP_CTX_PRINT_SIZE], 1
    jmp     .arg_loop

.chk_count:
    lea     rdi, [flag_count]
    mov     rsi, r13
    call    streq
    jne     .chk_out
    mov     rdi, [r15 + r12 * 8]
    inc     r12d
    call    parse_u8_strict
    test    edx, edx
    jnz     .parse_error
    cmp     eax, 1
    jb      .parse_error
    mov     byte [rbx + BP_CTX_COUNT], al
    jmp     .arg_loop

.chk_out:
    lea     rdi, [flag_out]
    mov     rsi, r13
    call    streq
    jne     .chk_trace
    ; Copy output filename (up to 63 chars) into ctx
    mov     rsi, [r15 + r12 * 8]   ; rsi = filename string pointer
    inc     r12d
    lea     rdi, [rbx + BP_CTX_OUTFILE]
    call    copy_string
    jmp     .arg_loop

.chk_trace:
    lea     rdi, [flag_trace]
    mov     rsi, r13
    call    streq
    jne     .unknown_flag           ; not a known flag — skip silently
    mov     byte [rbx + BP_CTX_HEX_TRACE], 1
    jmp     .arg_loop

.unknown_flag:
    ; Strict mode: unknown flag is a parse error.
    jmp     .parse_error

.parse_done:
    ; ── Validate required fields ───────────────────────────────────────────
    ; --out is required only for file mode
    cmp     byte [rbx + BP_CTX_OUTMODE], BP_OUTMODE_FILE
    jne     .out_ok
    cmp     byte [rbx + BP_CTX_OUTFILE], 0
    je      .missing_out
.out_ok:
    ; strict task-byte validation only applies when the task block is explicitly declared
    ; (--task / --task-code / --task-target / --task-timing).  Telegraph encoding
    ; (--tel-type / --tel-data) reuses BP_CTX_TASK_BYTE with a different bit layout
    ; and must not be validated here.
    cmp     byte [rbx + BP_CTX_TASK_PRES], 0
    je      .timing_ok                          ; no task block → skip validation
    test    byte [rbx + BP_CTX_TASK_BYTE], BP_TASK_TARGET
    jz      .target_ok
    cmp     byte [rbx + BP_CTX_TASK_BYTE + 1], 0
    jne     .target_ok
    jmp     .parse_error
.target_ok:
    test    byte [rbx + BP_CTX_TASK_BYTE], BP_TASK_TIMING
    jz      .timing_ok
    cmp     byte [rbx + BP_CTX_TASK_BYTE + 2], 0
    jne     .timing_ok
    jmp     .parse_error
.timing_ok:
    cmp     byte [rbx + BP_CTX_TIME_TIER], 3
    jne     .tier_ok
    cmp     word [rbx + BP_CTX_TIME_EXT], 0
    jne     .tier_ok
    ; allow explicit zero with --time-ext 0 if set; time presence differentiates
    cmp     byte [rbx + BP_CTX_TIME_PRES], 1
    jne     .parse_error
.tier_ok:

    ; Validation passed — return ctx pointer
    lea     rdi, [the_ctx]          ; rdi = &the_ctx (return value for dispatch.asm)
    xor     eax, eax                ; rax = 0 (success)
    jmp     .done

.missing_out:
    ; Print usage to stderr and return -1
    mov     rax, SYS_WRITE
    mov     rdi, STDERR
    lea     rsi, [usage_msg]
    mov     rdx, usage_len
    syscall

    lea     rdi, [the_ctx]          ; still return ctx pointer (partially filled)
    mov     eax, -1                 ; return -1 to signal caller
    jmp     .done

.parse_error:
    mov     rax, SYS_WRITE
    mov     rdi, STDERR
    lea     rsi, [usage_msg]
    mov     rdx, usage_len
    syscall
    lea     rdi, [the_ctx]
    mov     eax, -1

.done:
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
