#!/bin/bash
set -euo pipefail

# Global Variables
skip_grain=false
log=true
max_jobs=3
error_log="av1_errors.log"
job_log="parallel_jobs.log"

# Trap to clean up partial files on cancel
trap 'echo "Script canceled, cleaning up partial files..."; \
      find . -type f -name "*.av1.mkv" -delete; \
      find . -type f -name "*.txt" -delete; \
      exit 1' SIGINT SIGTERM

# Generate film grain
generateGrain(){
    local input_file=$1
    local output_file=$2
    local grain_file=${input_file%.*}.txt

    echo "Grain generation for $input_file started"
    grav1synth diff "$input_file" "$output_file" -o "$grain_file"
    grav1synth apply "$output_file" -o "av1_$output_file" -g "$grain_file"

    mv "av1_$output_file" "$output_file"
    rm -f "$grain_file"
}

# Parse script arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-grain)
      skip_grain=true; shift ;;
    --no-log)
      log=false; shift ;;
    --worker-count)
      max_jobs=$2; shift 2 ;;
    *)
      shift ;;
  esac
done

transcodeJob(){
    local input_file=$1
    local temp_file=${input_file%.*}.av1.mkv

    # Skip if already converted
    local codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
                  -of default=noprint_wrappers=1:nokey=1 "$input_file")
    [[ $codec == "av1" ]] && return

    echo "Transcoding of $input_file started from $codec to av1"
    if ! ffmpeg -nostdin -hide_banner -loglevel error -stats -y \
    		-hwaccel qsv -c:v "${codec}_qsv" -i "$input_file" \
    		-c:v av1_qsv -preset veryslow -global_quality 20 \
    		-look_ahead_depth 40 -low_power 0 \
    		-c:a copy "$temp_file" \
    		2>>"$error_log"; then
        echo "Error transcoding $input_file" >&2
        return 1
    fi

    if [ "$skip_grain" = false ]; then
        generateGrain "$input_file" "$temp_file"
    else
        echo "Skipping grain processing for: $input_file"
    fi

    rm -f "${input_file%.*}.nfo"
    rm -f "$input_file"
    mv "$temp_file" "$input_file"

    if [ "$log" = true ]; then
        echo "$(date '+%F %T') $input_file"
    fi
}

export -f transcodeJob generateGrain
export skip_grain log error_log

# Find files and run in parallel with resume support
find . -type f \( -name "*.mkv" -o -name "*.mp4" \) |
  parallel --joblog "$job_log" --resume -j "$max_jobs" transcodeJob {}
