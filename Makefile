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

FRAGMENTS_DIR := $(GENERATE_DIR)/$(BOOK)/fragments

TXT_FRAGMENTS := $(shell find $(FRAGMENTS_DIR) -name '*.txt' 2>/dev/null)
WAV_FRAGMENTS := $(TXT_FRAGMENTS:.txt=.wav)

MERGED_DIR := $(GENERATE_DIR)/$(BOOK)/audio

# Define dependencies for installation
DEPS_LISTS := $(wildcard pip-dependencies.txt apt-dependencies.txt)

# Color codes for terminal output
RED	   := $(shell printf '\033[0;31m')
GREEN  := $(shell printf '\033[0;32m')
YELLOW := $(shell printf '\033[0;33m')
BLUE   := $(shell printf '\033[0;34m')
BOLD   := $(shell printf '\033[1m')
RESET  := $(shell printf '\033[0m')

.PHONY: all clean stats split synthesize read list-speakers

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
	@printf "  $(BLUE)validate-xml$(RESET) - Validate the generated XML against the schema\n"
	@printf "  $(BLUE)list-speakers$(RESET) - List unique speakers found in the XML\n"
	@printf "  $(BLUE)stats$(RESET) - Print acts and scenes count for the specified BOOK\n"
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

# Vypíše abecední seznam všech unikátních postav v XML souboru
list-speakers: $(INPUT_XML)
	@printf "$(YELLOW)Unique speakers found in $(BLUE)$(INPUT_XML)$(YELLOW):$(RESET)\n"
	@xmllint --xpath "//utterance/@speaker" $< 2>/dev/null | \
		tr ' ' '\n' | \
		sed 's/speaker="//g; s/"//g' | \
		sort | \
		uniq | \
		sed 's/^/  - /'

VOICE_MAP := $(BOOKS_DIR)/$(BOOK)_voices.conf

generate-voices-map: $(INPUT_XML)
	@printf "$(YELLOW)Generating voices map from $(BLUE)$(INPUT_XML)$(RESET)...\n"
	@if [ ! -f $(VOICE_MAP) ]; then \
		xmllint --xpath "//utterance/@speaker" $< 2>/dev/null | \
		tr ' ' '\n' | \
		sed 's/speaker="//g; s/"//g' | \
		sort | uniq | \
		awk '{print $$1"=$(VOICE)|0"}' > $(VOICE_MAP); \
		printf "$(GREEN)Map successfully created at $(BLUE)$(VOICE_MAP)$(RESET)\n"; \
	else \
		printf "$(YELLOW)Map $(BLUE)$(VOICE_MAP)$(YELLOW) already exists. Skipping to prevent overwrite.$(RESET)\n"; \
	fi

# Target to print acts and scenes count
stats: $(INPUT_XML)
	@printf "$(YELLOW)Struktura dila $(BLUE)$(BOOK)$(YELLOW):$(RESET)\n"
	@ACT_COUNT=$$(xmllint --xpath "count(//act)" $< 2>/dev/null); \
	if [ "$$ACT_COUNT" -gt 0 ]; then \
		for i in $$(seq 1 $$ACT_COUNT); do \
			ACT_NAME=$$(xmllint --xpath "string(//act[$$i]/@name)" $< 2>/dev/null); \
			SCENE_COUNT=$$(xmllint --xpath "count(//act[$$i]/scene)" $< 2>/dev/null); \
			printf "  - %s: %s scen\n" "$$ACT_NAME" "$$SCENE_COUNT"; \
		done; \
	else \
		SCENE_COUNT=$$(xmllint --xpath "count(//scene)" $< 2>/dev/null); \
		if [ "$$SCENE_COUNT" -gt 0 ]; then \
			printf "  - Dilo se nedeli na dejstvi. Celkovy pocet scen: %s\n" "$$SCENE_COUNT"; \
		else \
			printf "  - Dilo neobsahuje dejstvi ani sceny (pouze prime promluvy).\n"; \
		fi; \
	fi

# Cíl pro vytvoření fragmentů textu
split: validate-xml stats list-speakers generate-voices-map
	@printf "$(YELLOW)Splitting XML into fragments in $(BLUE)$(FRAGMENTS_DIR)$(RESET)...\n"
	@./$(TOOLS_DIR)/split_xml.sh "$(INPUT_XML)" "$(FRAGMENTS_DIR)"

# Vzorové pravidlo pro převod jednoho TXT na WAV s podporou modulace hlasu
%.wav: %.txt
	@SPEAKER=$$(basename "$<" .txt | cut -d'_' -f2-); \
	CONFIG=$$(grep "^$$SPEAKER=" $(VOICE_MAP) 2>/dev/null | cut -d'=' -f2); \
	VOICE_MODEL=$$(echo "$$CONFIG" | cut -d'|' -f1); \
	PITCH_SHIFT=$$(echo "$$CONFIG" | cut -d'|' -f2); \
	if [ -z "$$VOICE_MODEL" ]; then VOICE_MODEL="$(VOICE)"; fi; \
	if [ -z "$$PITCH_SHIFT" ]; then PITCH_SHIFT="0"; fi; \
	printf "$(YELLOW)Synthesizing $(BLUE)$$SPEAKER$(YELLOW) using $(GREEN)$$VOICE_MODEL$(YELLOW) (Pitch: $$PITCH_SHIFT) -> $(BLUE)$@$(RESET)\n"; \
	cat "$<" | python3 -m piper -m "$$VOICE_MODEL" --data-dir $(VOICES_DIR) -f "$@.tmp.wav" 2>/dev/null; \
	if [ "$$PITCH_SHIFT" != "0" ]; then \
		sox "$@.tmp.wav" "$@" pitch "$$PITCH_SHIFT"; \
		rm -f "$@.tmp.wav"; \
	else \
		mv "$@.tmp.wav" "$@"; \
	fi

# Sub-cíl, který vyžaduje hotové WAV soubory
synthesize: $(WAV_FRAGMENTS)
	@printf "$(GREEN)All fragments synthesized successfully.$(RESET)\n"

merge: synthesize
	@printf "$(YELLOW)Merging fragments into acts...$(RESET)\n"
	@./$(TOOLS_DIR)/merge_acts.sh "$(FRAGMENTS_DIR)" "$(MERGED_DIR)"
	@printf "$(GREEN)Merge complete. Final audio files are in $(BLUE)$(MERGED_DIR)$(GREEN).$(RESET)\n"

# Hlavní cíl, který voláš z terminálu
# Nejprve provede split, a následně zavolá sám sebe pro syntézu
read: install download-voices split
	@$(MAKE) synthesize BOOK=$(BOOK)
	@$(MAKE) merge BOOK=$(BOOK)

clean:
	@printf "$(YELLOW)Cleaning up...$(RESET)\n"
	@rm -f install
	@rm -rf $(GENERATE_DIR)/*