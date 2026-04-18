# BitPads — Project Todos

---

## 🔴 High Priority

### Functionality

- [ ] Resolve 28-byte vs 22-byte footprint discrepancy — spec Section 11.1 states 28 bytes for Full BitLedger in BitPads but named components sum to 22 bytes minimum; Session Config Extension sizing is ambiguous and needs a definitive breakdown
- [ ] Add formal test vectors — smoke test exists but no byte-level output verification against known-good reference frames; a corrupted build currently passes the smoke test
- [ ] Implement protocol decoder — CLI is encode-only; no way to read a `.bp` file back and verify or display its contents; makes testing and integration significantly harder
- [ ] Complete signal slot content bytes — SSP byte is emitted correctly but actual slot content bytes for P4–P8 are not written; slots are declared but empty
- [ ] Link-test and run-test the Linux port — all 25 files assemble clean to ELF64 but the port has never been linked or executed on a Linux machine; needs confirmation before it can be distributed

### CLI Experience

- [ ] Add `--help` flag with grouped flag reference — currently there is no help output at all; bad flags produce an error but no guidance on correct usage
- [ ] Improve error messages to suggest correct syntax — errors currently state what went wrong but do not show the correct flag or a usage example

---

## 🟡 Medium Priority

### Functionality

- [ ] Implement `--script <file>` batch mode — execute a file where each line is a bitpads invocation; documented as missing in CLI_GUIDE.md; enables scripted and LLM-generated transmission sequences
- [ ] Implement `--stdin` pipe input — read flags from stdin so bitpads can be used in shell pipelines
- [ ] Add CRC override flags `--crc <hex16>` and `--no-crc` — needed for testing parsers and receivers with known-bad or zeroed CRC frames
- [ ] Complete Tier 2 time block — `--time-ext` flag exists but the second byte of the Tier 2 time block is not settable; documented gap in CLI_GUIDE.md
- [ ] Add coordinated two-frame compound helper — compound mode requires two separate invocations with manually coordinated flags; a single `--compound-pair` command should emit both frames atomically
- [ ] Add output diff test between macOS and Linux builds — run identical invocations on both binaries and compare byte output; any divergence would indicate an ABI bug in the Linux port
- [ ] Fix archetype code exposure — `--archetype` flag is listed in the gap table as not reachable for some frame types; should be settable for all frame types that carry Meta Byte 2

### CLI Experience

- [ ] Make `--dry-run` output a byte-by-byte breakdown — current dry-run suppresses file output but does not show what would be written; should print each component with its byte range and decoded meaning
- [ ] Add `--version` and `--info` flags — `--version` prints CLI version and protocol revision; `--info` prints supported frame types, sizes, and total flag count
- [ ] Add shell completion scripts — generate bash and zsh completion files so flags tab-complete in the terminal
- [ ] Improve `--trace` output readability — trace files are hex dumps; add component labels so each line identifies which protocol layer or field it belongs to

---

## 🟢 Low Priority

### Functionality

- [ ] Add sub-field flags for enhancement categories 1100, 1101, and 1110 — currently routed correctly but individual sub-fields within compact command, context declaration, and telegraph modes are not fully exposed via CLI flags
- [ ] Add multi-frame batch output mode — emit multiple frames to a single file with correct batch separators rather than requiring separate invocations
- [ ] Produce formal conformance test suite — structured test cases with input flags, expected output bytes, and pass/fail criteria; prerequisite for any standards submission
- [ ] Add a decoder binary — separate `bitpads-decode` tool (or `--decode` mode) that reads a `.bp` file and prints a human-readable field-by-field breakdown

### CLI Experience

- [ ] Write a man page — `man bitpads` should be available after install
- [ ] Add a `--quiet` flag — suppress all stdout except the binary output; useful in scripts where only the exit code matters
- [ ] Build an example cookbook — a markdown file with 20–30 real invocation examples covering each frame type and common use cases; link from the main README
- [ ] Add color output option for `--hex` and `--hex-raw` modes — highlight different protocol layers in different colors for readability at the terminal
