#!/bin/bash
# Script to extract utterances from XML into separate text files.
# Directory structure is created based on act and scene.

INPUT_XML="$1"
OUT_DIR="$2"

if [[ -z "$INPUT_XML" || -z "$OUT_DIR" ]]; then
    echo "Usage: $0 <input_xml> <output_dir>"
    exit 1
fi

# Initialize variables for current path and sequential numbering
act_dir=""
scene_dir=""
counter=1

# Clean output directory before extraction to prevent mixing old files
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Regular expressions to parse the XML tags
REGEX_ACT="<act name=\"([^\"]+)\">"
REGEX_SCENE="<scene name=\"([^\"]+)\">"
REGEX_UTTERANCE="<utterance[^>]*speaker=\"([^\"]+)\"[^>]*>(.*)</utterance>"
REGEX_END_ACT="</act>"
REGEX_END_SCENE="</scene>"

# Process line by line
while IFS= read -r line; do
    if [[ "$line" =~ $REGEX_ACT ]]; then
        # Replace spaces with underscores for safe directory names
        act_dir="${BASH_REMATCH[1]// /_}"
    elif [[ "$line" =~ $REGEX_SCENE ]]; then
        scene_dir="${BASH_REMATCH[1]// /_}"
    elif [[ "$line" =~ $REGEX_END_ACT ]]; then
        act_dir=""
    elif [[ "$line" =~ $REGEX_END_SCENE ]]; then
        scene_dir=""
    elif [[ "$line" =~ $REGEX_UTTERANCE ]]; then
        speaker="${BASH_REMATCH[1]// /_}"
        text="${BASH_REMATCH[2]}"
        
        # Decode simple XML entities back to plain text
        text="${text//&lt;/<}"
        text="${text//&gt;/>}"
        text="${text//&quot;/\"}"
        text="${text//&apos;/\'}"
        text="${text//&amp;/&}"
        
        # Construct target path based on current state
        target_path="$OUT_DIR"
        [[ -n "$act_dir" ]] && target_path="$target_path/$act_dir"
        [[ -n "$scene_dir" ]] && target_path="$target_path/$scene_dir"
        
        mkdir -p "$target_path"
        
        # Zero pad counter to 4 digits for correct alphabetical sorting
        printf -v pad_counter "%04d" $counter
        file_name="${pad_counter}_${speaker}.txt"
        
        echo "$text" > "$target_path/$file_name"
        ((counter++))
    fi
done < "$INPUT_XML"