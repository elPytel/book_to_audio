#!/bin/bash
# Script to download Piper TTS models from a JSON configuration
# Requires jq and wget

CONFIG_FILE="languages.json"
VOICES_DIR="voices"

# Allow overriding VOICES_DIR and CONFIG_FILE via command-line args
while [ $# -gt 0 ]; do
    case "$1" in
        --data-dir)
            VOICES_DIR="$2"
            shift 2
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Check for required tools
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Run: sudo apt install jq"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found."
    exit 1
fi

# Ensure target directory exists
mkdir -p "$VOICES_DIR"

echo "Parsing $CONFIG_FILE and downloading missing models..."

# Extract filename and URL pairs from the JSON structure
# The jq query goes through all languages and extracts keys and values from the model object
while read -r filename url; do
    target_path="$VOICES_DIR/$filename"

    if [ -f "$target_path" ]; then
        echo "Skipping: $filename (already exists)"
    else
        echo "Downloading: $filename"
        # Download quietly but show progress bar
        wget -q --show-progress -O "$target_path" "$url"
        
        # Verify download success
        if [ $? -ne 0 ]; then
            echo "Error downloading $filename"
            # Remove potentially corrupted incomplete file
            rm -f "$target_path"
        fi
    fi
done < <(jq -r '.languages[].model | to_entries[] | "\(.key) \(.value)"' "$CONFIG_FILE")

echo "Download process finished."