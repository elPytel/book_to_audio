#!/bin/bash
# Script to concatenate wav fragments into single files per act or scene
# Usage: ./merge_acts.sh input_dir output_dir

FRAGMENTS_DIR="$1"
OUTPUT_DIR="$2"

if [[ -z "$FRAGMENTS_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: $0 <fragments_dir> <output_dir>"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Iterate through top level directories in the fragments folder
# These represent either acts or scenes depending on the play structure
for dir_path in "$FRAGMENTS_DIR"/*; do
    if [[ -d "$dir_path" ]]; then
        dir_name=$(basename "$dir_path")
        list_file="$dir_path/concat_list.txt"
        output_file="$OUTPUT_DIR/${dir_name}.wav"
        
        # Clean up any old list file
        rm -f "$list_file"
        
        # Find all wav files recursively, sort them alphabetically and write to list
        # We use absolute paths by using readlink
        find "$dir_path" -type f -name "*.wav" | sort | while read -r wav_file; do
            # Format required by ffmpeg concat demuxer
            echo "file '$(readlink -f "$wav_file")'" >> "$list_file"
        done
        
        if [[ -s "$list_file" ]]; then
            # Use ffmpeg concat demuxer to merge without re encoding
            # Redirect stdin from /dev/null to prevent ffmpeg from eating bash input
            ffmpeg -y -f concat -safe 0 -i "$list_file" -c copy "$output_file" < /dev/null 2> /dev/null
            rm -f "$list_file"
            echo "Merged act: $output_file"
        fi
    fi
done

# Handle the case where the play has no acts or scenes and files are in the root
root_list="$FRAGMENTS_DIR/root_concat_list.txt"
rm -f "$root_list"
find "$FRAGMENTS_DIR" -maxdepth 1 -type f -name "*.wav" | sort | while read -r wav_file; do
    echo "file '$(readlink -f "$wav_file")'" >> "$root_list"
done
#!/bin/bash
# Script to concatenate wav fragments into single files per act or scene
# Usage: ./merge_acts.sh input_dir output_dir

FRAGMENTS_DIR="$1"
OUTPUT_DIR="$2"

if [[ -z "$FRAGMENTS_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: $0 <fragments_dir> <output_dir>"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Iterate through top level directories in the fragments folder
# These represent either acts or scenes depending on the play structure
for dir_path in "$FRAGMENTS_DIR"/*; do
    if [[ -d "$dir_path" ]]; then
        dir_name=$(basename "$dir_path")
        list_file="$dir_path/concat_list.txt"
        output_file="$OUTPUT_DIR/${dir_name}.wav"
        
        # Clean up any old list file
        rm -f "$list_file"
        
        # Find all wav files recursively, sort them alphabetically and write to list
        # We use absolute paths by using readlink
        find "$dir_path" -type f -name "*.wav" | sort | while read -r wav_file; do
            # Format required by ffmpeg concat demuxer
            echo "file '$(readlink -f "$wav_file")'" >> "$list_file"
        done
        
        if [[ -s "$list_file" ]]; then
            # Use ffmpeg concat demuxer to merge without re encoding
            # Redirect stdin from /dev/null to prevent ffmpeg from eating bash input
            ffmpeg -y -f concat -safe 0 -i "$list_file" -c copy "$output_file" < /dev/null 2> /dev/null
            rm -f "$list_file"
            echo "Merged act: $output_file"
        fi
    fi
done

# Handle the case where the play has no acts or scenes and files are in the root
root_list="$FRAGMENTS_DIR/root_concat_list.txt"
rm -f "$root_list"
find "$FRAGMENTS_DIR" -maxdepth 1 -type f -name "*.wav" | sort | while read -r wav_file; do
    echo "file '$(readlink -f "$wav_file")'" >> "$root_list"
done

if [[ -s "$root_list" ]]; then
    output_file="$OUTPUT_DIR/00_Complete_Play.wav"
    ffmpeg -y -f concat -safe 0 -i "$root_list" -c copy "$output_file" < /dev/null 2> /dev/null
    rm -f "$root_list"
    echo "Merged root fragments: $output_file"
else
    rm -f "$root_list"
fi
if [[ -s "$root_list" ]]; then
    output_file="$OUTPUT_DIR/00_Complete_Play.wav"
    ffmpeg -y -f concat -safe 0 -i "$root_list" -c copy "$output_file" < /dev/null 2> /dev/null
    rm -f "$root_list"
    echo "Merged root fragments: $output_file"
else
    rm -f "$root_list"
fi