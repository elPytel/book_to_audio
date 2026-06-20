#!/bin/bash
# Script to parse a play text file into a hierarchical XML format
# Usage: ./parse_play.sh input.txt output.xml

INPUT_TXT="$1"
OUTPUT_XML="$2"

if [[ -z "$INPUT_TXT" || -z "$OUTPUT_XML" ]]; then
    echo "Usage: $0 <input.txt> <output.xml>"
    exit 1
fi

# Helper function to escape XML special characters natively
escape_xml() {
    local text="$1"
    text="${text//&/&amp;}"
    text="${text//</&lt;}"
    text="${text//>/&gt;}"
    text="${text//\"/&quot;}"
    text="${text//\'/&apos;}"
    echo "$text"
}

# Helper function to trim leading and trailing whitespace
trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# State variables
current_speaker="NARRATOR"
current_action=""
current_text=""
in_act=0
in_scene=0

# Clean output file
> "$OUTPUT_XML"
echo '<?xml version="1.0" encoding="UTF-8"?>' >> "$OUTPUT_XML"
echo '<book>' >> "$OUTPUT_XML"

# Function to write the compiled utterance to the file
flush_utterance() {
    # Normalize spaces: replace multiple spaces, tabs and NBSP with a single space
    current_text=$(echo "$current_text" | sed -E 's/[[:space:]\xC2\xA0]+/ /g' | sed -E 's/^ //; s/ $//')

    if [[ -n "$current_text" ]]; then
        local e_text
        e_text=$(escape_xml "$current_text")
        local e_speaker
        e_speaker=$(escape_xml "$current_speaker")

        if [[ -n "$current_action" ]]; then
            local e_action
            e_action=$(escape_xml "$current_action")
            echo "    <utterance speaker=\"$e_speaker\" action=\"$e_action\">$e_text</utterance>" >> "$OUTPUT_XML"
        else
            echo "    <utterance speaker=\"$e_speaker\">$e_text</utterance>" >> "$OUTPUT_XML"
        fi
    fi
    current_text=""
    current_action=""
}

# Close current scene safely
close_scene() {
    if [[ $in_scene -eq 1 ]]; then
        flush_utterance
        echo "  </scene>" >> "$OUTPUT_XML"
        in_scene=0
    fi
}

# Close current act safely
close_act() {
    close_scene
    if [[ $in_act -eq 1 ]]; then
        flush_utterance
        echo "</act>" >> "$OUTPUT_XML"
        in_act=0
    fi
}

# POSIX ERE Regex patterns for bash
# Match combinations like "Jednani", "JEDNANI", "Scena", "SCENA" optionally followed by text
REGEX_ACT="^(Dějství|DĚJSTVÍ|Jednání|JEDNÁNÍ|Akt|AKT)([[:space:]]|$)"
REGEX_SCENE="^(Scéna|SCÉNA|Výstup|VÝSTUP)([[:space:]]|$)"
REGEX_WITH_ACTION="^([A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ ]+)[[:space:]]*\(([^)]+)\):[[:space:]]*(.*)$"
REGEX_NO_ACTION="^([A-ZÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ ]+):[[:space:]]*(.*)$"

# Read file line by line using bash built-ins
while IFS= read -r line || [[ -n "$line" ]]; do
    line=$(trim "$line")
    
    # Skip empty lines
    [[ -z "$line" ]] && continue

    if [[ "$line" =~ $REGEX_ACT ]]; then
        close_act
        act_name=$(escape_xml "$line")
        echo "<act name=\"$act_name\">" >> "$OUTPUT_XML"
        in_act=1
        # Reset speaker to NARRATOR for stage directions
        current_speaker="NARRATOR" 
        
    elif [[ "$line" =~ $REGEX_SCENE ]]; then
        close_scene
        scene_name=$(escape_xml "$line")
        echo "  <scene name=\"$scene_name\">" >> "$OUTPUT_XML"
        in_scene=1
        # Reset speaker to NARRATOR for stage directions
        current_speaker="NARRATOR"

    elif [[ "$line" =~ $REGEX_WITH_ACTION ]]; then
        flush_utterance
        current_speaker=$(trim "${BASH_REMATCH[1]}")
        current_action=$(trim "${BASH_REMATCH[2]}")
        current_text=$(trim "${BASH_REMATCH[3]}")
        
    elif [[ "$line" =~ $REGEX_NO_ACTION ]]; then
        flush_utterance
        current_speaker=$(trim "${BASH_REMATCH[1]}")
        current_action=""
        current_text=$(trim "${BASH_REMATCH[2]}")
        
    else
        # Append to current utterance if no speaker is found
        if [[ -z "$current_text" ]]; then
            current_text="$line"
        else
            current_text="$current_text $line"
        fi
    fi
done < "$INPUT_TXT"

# Flush remaining utterances and properly close all tags
close_act
echo '</book>' >> "$OUTPUT_XML"

# Format output using xmllint
if command -v xmllint &> /dev/null; then
    xmllint --format "$OUTPUT_XML" --output "$OUTPUT_XML"
fi