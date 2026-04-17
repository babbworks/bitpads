#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

./bitpads --type signal --category 1 --hex-raw >/dev/null
./bitpads --type wave --value 42 --txtype copy --compound-max 3 --dry-run
./bitpads --type record --sender 0x1 --layer2 --currency 10 --round-bal 2 --sep-group 7 --sep-record 3 --sep-file 1 --archetype 9 --task-code 12 --task-target 9 --task-timing 8 --slot-p4 0x81 --out test_record.bp
./bitpads --type ledger --sender 0x1 --acct 1 --dir 0 --l3-ext 0xAA --time-ext 1024 --out test_ledger.bp
./bitpads --type telem --tel-type heartbeat --tel-data 4 --count 2 --dry-run

echo "cli_matrix_smoke.sh: OK"
