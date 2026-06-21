#!/bin/bash
# Script to synthesize a text fragment using either Piper (offline) or Edge TTS (cloud)
# Parses speaker configuration and applies correct toolchain options

# Default values
ENGINE="edge"
DEFAULT_VOICE="cs-CZ-AntoninNeural"
VOICES_DIR="voices"

# Print usage helper
usage() {
    echo "Usage: $0 -i <input.txt> -o <output.wav> -m <voices.conf> [-e <edge|piper>] [-d <voices_dir>] [-v <default_voice>]"
    exit 1
}

# Parse command line arguments using standard getopts
while getopts "i:o:m:e:d:v:h" opt; do
    case "$opt" in
        i) INPUT_TXT="$OPTARG" ;;
        o) OUTPUT_WAV="$OPTARG" ;;
        m) MAP_FILE="$OPTARG" ;;
        e) ENGINE="$OPTARG" ;;
        d) VOICES_DIR="$OPTARG" ;;
        v) DEFAULT_VOICE="$OPTARG" ;;
        h|*) usage ;;
    esac
done

# Check for mandatory parameters
if [[ -z "$INPUT_TXT" || -z "$OUTPUT_WAV" || -z "$MAP_FILE" ]]; then
    echo "Error: Missing mandatory arguments (-i, -o, or -m)."
    usage
fi

# Extract speaker name from the file base name (e.g., 0001_BERNARDO.txt -> BERNARDO)
SPEAKER=$(basename "$INPUT_TXT" .txt | cut -d'_' -f2-)

# Fetch configuration line from mapping file
if [[ -z "$SPEAKER" ]]; then
    CONFIG=$(grep "^=" "$MAP_FILE" 2>/dev/null | cut -d'=' -f2)
else
    CONFIG=$(grep "^${SPEAKER}=" "$MAP_FILE" 2>/dev/null | cut -d'=' -f2)
fi

# Extract parameters from configuration string (Format: MODEL|PITCH|RATE)
VOICE_MODEL=$(echo "$CONFIG" | cut -d'|' -f1)
PITCH=$(echo "$CONFIG" | cut -d'|' -f2)
RATE=$(echo "$CONFIG" | cut -d'|' -f3)

# Fallback to safe defaults if values are missing
[[ -z "$VOICE_MODEL" ]] && VOICE_MODEL="$DEFAULT_VOICE"

# Execute synthesis branch according to the selected engine
if [[ "$ENGINE" == "edge" ]]; then
    # Normalize Edge TTS specific attributes
    [[ -z "$PITCH" || "$PITCH" == "0" ]] && PITCH="+0Hz"
    [[ -z "$RATE" ]] && RATE="+0%"
    
    edge-tts --voice "$VOICE_MODEL" --pitch "$PITCH" --rate "$RATE" -f "$INPUT_TXT" --write-media "$OUTPUT_WAV" 2>/dev/null
    exit $?

elif [[ "$ENGINE" == "piper" ]]; then
    # Normalize Piper + SoX specific attributes
    [[ -z "$PITCH" ]] && PITCH="0"
    TMP_WAV="${OUTPUT_WAV}.tmp.wav"
    
    # Run core Piper generation
    cat "$INPUT_TXT" | python3 -m piper -m "$VOICE_MODEL" --data-dir "$VOICES_DIR" -f "$TMP_WAV" 2>/dev/null
    
    if [[ $? -ne 0 || ! -f "$TMP_WAV" ]]; then
        echo "Error: Piper synthesis failed for file $INPUT_TXT"
        rm -f "$TMP_WAV"
        exit 1
    fi
    
    # Process audio post processing via SoX if pitch is altered
    if [[ "$PITCH" != "0" && "$PITCH" != "+0Hz" && "$PITCH" != "0Hz" ]]; then
        # Strip potential 'Hz' suffix if user reused Edge config in Piper mode
        PITCH_SOX=$(echo "$PITCH" | sed 's/Hz//g')
        sox "$TMP_WAV" "$OUTPUT_WAV" pitch "$PITCH_SOX" 2>/dev/null
        rm -f "$TMP_WAV"
    else
        mv "$TMP_WAV" "$OUTPUT_WAV"
    fi
    exit $?
else
    echo "Error: Unsupported engine type '$ENGINE'. Use 'edge' or 'piper'."
    exit 1
fi