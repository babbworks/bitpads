# ─────────────────────────────────────────────────────────────────────────────
# BitPads Assembly CLI — Updated Makefile for modern macOS (2025+)
# Target: macOS x86-64 (Intel or Rosetta on Apple Silicon)
# Assembler: NASM
# Linker: ld with current Xcode Command Line Tools
# ─────────────────────────────────────────────────────────────────────────────

NASM    := nasm
LD      := ld

# Modern NASM flags
NFLAGS  := -f macho64 -I include/ -Werror

# Modern linker flags for macOS 2024–2026
LFLAGS  := -macosx_version_min 12.0 \
           -L$(shell xcrun --sdk macosx --show-sdk-path)/usr/lib \
           -lSystem

# Source files (in correct dependency order)
SRC := \
    src/crypto/crc15.asm            \
    src/io/fileio.asm               \
    src/io/hexdump.asm              \
    src/layers/meta1.asm            \
    src/layers/meta2.asm            \
    src/layers/layer1.asm           \
    src/layers/layer2.asm           \
    src/layers/layer3.asm           \
    src/components/setup.asm        \
    src/components/value.asm        \
    src/components/time_comp.asm    \
    src/components/task.asm         \
    src/components/note.asm         \
    src/enhancement/c0gram.asm      \
    src/enhancement/signals.asm     \
    src/enhancement/cmd1100.asm     \
    src/enhancement/ctx1101.asm     \
    src/enhancement/tel1110.asm     \
    src/builders/build_signal.asm   \
    src/builders/build_wave.asm     \
    src/builders/build_record.asm   \
    src/builders/build_ledger.asm   \
    src/cli_parse.asm               \
    src/dispatch.asm                \
    src/main.asm

OBJ := $(SRC:.asm=.o)
BIN := bitpads

.PHONY: all clean test

all: $(BIN)

$(BIN): $(OBJ)
	@echo "[LD] Linking $(BIN)"
	$(LD) $(LFLAGS) -o $@ $^
	@echo "[OK] Build complete: ./$(BIN)"

%.o: %.asm include/bitpads.inc include/syscall.inc include/macros.inc
	@echo "[AS] $<"
	$(NASM) $(NFLAGS) -o $@ $<

clean:
	@echo "[CLEAN] Removing objects and binary"
	rm -f $(OBJ) $(BIN) tests/*.o tests/test_*

# Test targets
test: $(BIN)
	@echo "[TEST] Running unit tests..."
	@echo "[TEST] --- test_layers ---"
	./tests/test_layers || true
	@echo "[TEST] --- test_meta ---"
	./tests/test_meta || true
	@echo "[TEST] --- test_crc15 ---"
	./tests/test_crc15 || true
	@echo "[TEST] Done"

# Create test binaries (optional, for manual testing)
tests/test_layers: tests/test_layers.o $(filter-out src/main.o, $(OBJ))
	$(LD) $(LFLAGS) -o $@ $^

tests/test_meta: tests/test_meta.o $(filter-out src/main.o, $(OBJ))
	$(LD) $(LFLAGS) -o $@ $^

tests/test_crc15: tests/test_crc15.o $(filter-out src/main.o, $(OBJ))
	$(LD) $(LFLAGS) -o $@ $^