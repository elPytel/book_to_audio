PY			:= python3
TOOLS_DIR   := tools
GENERATE_DIR = generated
VOICES_DIR   = voices

SCHEMA_FILE = $(TOOLS_DIR)/schema.xsd

# Define available voices and select the first one as default
VOICES := cs_CZ-jirka-medium
VOICE := $(firstword $(VOICES))

# Transform voice names into target .onnx file paths
VOICE_FILES := $(patsubst %,$(VOICES_DIR)/%.onnx,$(VOICES))

BOOKS_DIR = books

# Find all EPUB files and define corresponding TXT files
EPUB_FILES := $(wildcard $(BOOKS_DIR)/*.epub)
TXT_FILES := $(patsubst %.epub,%.txt,$(EPUB_FILES))

BOOK ?= $(firstword $(notdir $(basename $(TXT_FILES))))
INPUT_TXT := $(GENERATE_DIR)/$(BOOK).txt
INPUT_XML := $(GENERATE_DIR)/$(BOOK).xml
OUTPUT_AUDIO := $(GENERATE_DIR)/$(BOOK).wav

# Define dependencies for installation
DEPS_LISTS := $(wildcard pip-dependencies.txt apt-dependencies.txt)

# Color codes for terminal output
RED	   := $(shell printf '\033[0;31m')
GREEN  := $(shell printf '\033[0;32m')
YELLOW := $(shell printf '\033[0;33m')
BLUE   := $(shell printf '\033[0;34m')
BOLD   := $(shell printf '\033[1m')
RESET  := $(shell printf '\033[0m')

.PHONY: all clean

all: read 

$(GENERATE_DIR):
	@mkdir -p $(GENERATE_DIR)

$(VOICES_DIR):
	@mkdir -p $(VOICES_DIR)

$(BOOKS_DIR):
	@mkdir -p $(BOOKS_DIR)

help:
	@printf "$(YELLOW)Usage: make [target] BOOK=\"book_name\"$(RESET)\n"
	@printf "$(YELLOW)Targets:$(RESET)\n"
	@printf "  $(BLUE)install$(RESET) - Install dependencies from pip-dependencies.txt and apt-dependencies.txt\n"
	@printf "  $(BLUE)download-voices$(RESET) - Download required voice models\n"
	@printf "  $(BLUE)convert-books$(RESET) - Convert all EPUB books in $(BOOKS_DIR) to TXT format\n"
	@printf "  $(BLUE)read$(RESET) - Generate audiobook for the specified BOOK (without extension)\n"
	@printf "  $(BLUE)clean$(RESET) - Remove generated audio files and installation marker\n"

install: $(DEPS_LISTS)
	@printf "$(YELLOW)Installing dependencies from $(BLUE)$^$(RESET)...\n"
	@./install.sh
	@touch $@

# The download target depends on the actual physical files
download-voices: $(VOICE_FILES) download-voices-huggingface

# Pattern rule to download missing voice models
$(VOICES_DIR)/%.onnx: | $(VOICES_DIR)
	@printf "$(YELLOW)Downloading voice model $(BLUE)$*$(RESET)...\n"
	@python3 -m piper.download_voices "$*" --data-dir $(VOICES_DIR)

download-voices-huggingface: | $(VOICES_DIR)
	@printf "$(YELLOW)Downloading Hugging Face voice models...$(RESET)\n"
	@bash ./download_custom_voices.sh --data-dir $(VOICES_DIR)

# Target to convert all found EPUB books to TXT
convert-books: $(TXT_FILES)

# Pattern rule for EPUB to TXT conversion
# It uses grep to remove empty lines right during extraction
$(GENERATE_DIR)/%.txt: $(BOOKS_DIR)/%.epub | $(BOOKS_DIR) $(GENERATE_DIR)
	@printf "$(YELLOW)Converting $(BLUE)$<$(RESET) to TXT...\n"
	@pandoc "$<" -t plain | grep -v '^[[:space:]]*$$' > "$@"

$(GENERATE_DIR)/%.xml: $(GENERATE_DIR)/%.txt | $(GENERATE_DIR)
	@printf "$(YELLOW)Parsing $(BLUE)$(INPUT_TXT)$(YELLOW) to XML...$(RESET)\n"
	@./$(TOOLS_DIR)/parse_play.sh "$<" "$@"

# Ochranný cíl, který zkontroluje strukturu před generováním audia
validate-xml: $(INPUT_XML) $(SCHEMA_FILE)
	@printf "$(YELLOW)Validating $(BLUE)$(INPUT_XML)$(YELLOW) against schema...$(RESET)\n"
	@xmllint --noout --schema $(SCHEMA_FILE) $(INPUT_XML)
	@printf "$(GREEN)Validation passed! XML is perfectly structured.$(RESET)\n"

.PHONY: list-speakers

# Vypíše abecední seznam všech unikátních postav v XML souboru
list-speakers: $(INPUT_XML)
	@printf "$(YELLOW)Unique speakers found in $(BLUE)$(INPUT_XML)$(YELLOW):$(RESET)\n"
	@xmllint --xpath "//utterance/@speaker" $< 2>/dev/null | \
		tr ' ' '\n' | \
		sed 's/speaker="//g; s/"//g' | \
		sort | \
		uniq | \
		sed 's/^/  - /'

# Read target now depends on the pre-converted TXT file
read: install download-voices $(INPUT_TXT) | $(BOOKS_DIR) $(GENERATE_DIR)
	@printf "$(YELLOW)Synthesizing book: $(BLUE)$(BOOK)$(RESET)...\n"
	@cat "$(INPUT_TXT)" | python3 -m piper -m $(VOICE) --data-dir $(VOICES_DIR) -f $(OUTPUT_AUDIO)
	@printf "$(GREEN)Audiobook generated successfully: $(BLUE)$(OUTPUT_AUDIO)$(RESET)\n"

clean:
	@printf "$(YELLOW)Cleaning up...$(RESET)\n"
	@rm -f install
	@rm -rf $(GENERATE_DIR)/*