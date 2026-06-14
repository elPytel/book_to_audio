
GENERATE_AUDIO_DIR = generated
VOICES_DIR = voices
VOICES := cs_CZ-jirka-medium
VOICE := $(firstword $(VOICES))

# Transform voice names into target .onnx file paths
VOICE_FILES := $(patsubst %,$(VOICES_DIR)/%.onnx,$(VOICES))

BOOKS_DIR = books

# Find all EPUB files and define corresponding TXT files
EPUB_FILES := $(wildcard $(BOOKS_DIR)/*.epub)
TXT_FILES := $(patsubst %.epub,%.txt,$(EPUB_FILES))

BOOK ?= rur
INPUT_TXT := $(BOOKS_DIR)/$(BOOK).txt
OUTPUT_AUDIO := $(GENERATE_AUDIO_DIR)/$(BOOK).wav

DEPS_LISTS := $(wildcard pip-dependencies.txt apt-dependencies.txt)

RED	   := $(shell printf '\033[0;31m')
GREEN  := $(shell printf '\033[0;32m')
YELLOW := $(shell printf '\033[0;33m')
BLUE   := $(shell printf '\033[0;34m')
BOLD   := $(shell printf '\033[1m')
RESET  := $(shell printf '\033[0m')

.PHONY: all clean

all: read 

$(GENERATE_AUDIO_DIR):
	@mkdir -p $(GENERATE_AUDIO_DIR)

$(VOICES_DIR):
	@mkdir -p $(VOICES_DIR)

$(BOOKS_DIR):
	@mkdir -p $(BOOKS_DIR)

install: $(DEPS_LISTS)
	@printf "$(YELLOW)Installing dependencies from $(BLUE)$^$(RESET)...\n"
	@./install.sh
	@touch $@

# The download target depends on the actual physical files
download-voices: $(VOICE_FILES)

# Pattern rule to download missing voice models
$(VOICES_DIR)/%.onnx: | $(VOICES_DIR)
	@printf "$(YELLOW)Downloading voice model $(BLUE)$*$(RESET)...\n"
	@mkdir -p $(VOICES_DIR)
	@python3 -m piper.download_voices "$*" --data-dir $(VOICES_DIR)

# Target to convert all found EPUB books to TXT
convert-books: $(TXT_FILES)

# Pattern rule for EPUB to TXT conversion
# It uses grep to remove empty lines right during extraction
$(BOOKS_DIR)/%.txt: $(BOOKS_DIR)/%.epub | $(BOOKS_DIR)
	@printf "$(YELLOW)Converting $(BLUE)$<$(RESET) to TXT...\n"
	@pandoc "$<" -t plain | grep -v '^[[:space:]]*$$' > "$@"

# Read target now depends on the pre-converted TXT file
read: install download-voices $(INPUT_TXT) | $(BOOKS_DIR) $(GENERATE_AUDIO_DIR)
	@printf "$(YELLOW)Synthesizing book: $(BLUE)$(BOOK)$(RESET)...\n"
	@cat "$(INPUT_TXT)" | python3 -m piper -m $(VOICE) --data-dir $(VOICES_DIR) -f $(OUTPUT_AUDIO)
	@printf "$(GREEN)Audiobook generated successfully: $(BLUE)$(OUTPUT_AUDIO)$(RESET)\n"

clean:
	@printf "$(YELLOW)Cleaning up...$(RESET)\n"
	@rm -f install
	@rm -rf $(GENERATE_AUDIO_DIR)/*