#!/bin/bash

# Loop through all .mkv files
skip_grain=false
log=true
job_count=0
max_jobs=3

# Generate film grain
generateGrain(){
        local F=$1
        local TEMPF=$2

        # Location of the grain file. Same name as the file but with a txt suffix instead of mkv
        local GRAINF=${F%.*}.txt

        echo "Grain generation for $F started"
        # Begin film grain synth
        # Compute Grain Diff
        grav1synth diff "$F" "$TEMPF" -o "$GRAINF";
        # Apply Grain Diff
        grav1synth apply "$TEMPF" -o "$TEMPF" -g "$GRAINF";

        # Clean up grain file
        rm "$GRAINF";
}

# Parse script arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-grain)
      skip_grain=true
      shift
      ;;

    --no-log)
      log=false
      shift
      ;;
	  
	--worker-count)
      max_jobs=$2
      shift 2
      ;;

    *)
      shift
      ;;
  esac
done

transcodeJob(){
	# Bit Easier to read this way, F is the original file (passed as first argument)
	# TEMPF is the original file but with a av1.mkv suffix instead of just .mkv
	local F=$1
	local TEMPF=${F%.*}.av1.mkv
	
	# Get the codec type, will skip if av1... no point reencoding av1->av1
	local FTYPE=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $file)
	
	
	# Skip already generated AV1 files
	[[ $FTYPE == "av1" ]] && continue
	
	# Transcode each mkv to av1 using hardware accel
	echo "Transcoding of $F started from $FTYPE to av1"
	ffmpeg -hide_banner -loglevel error -stats -y -hwaccel vaapi -hwaccel_output_format vaapi -i "$F" -vf 'hwmap=derive_device=qsv,format=qsv' -c:v av1_qsv -global_quality 20 -preset veryslow "$TEMPF";
	
	if [ "$skip_grain" = false ]; then
			# Pass file and temp file names into script
			generateGrain "$F" "$TEMPF"
	else
			echo "Skipping grain processing for: $F"
	fi
	
	# Clean up
	rm "${F%.*}.nfo";
	rm "$F";
	
	# Remove temp naming
	mv "$TEMPF" "$F";
	
	# If logging is not disabled then log too
	[[ "$log" == true ]] && echo "$F" >> av1_conversion;


}


# Find all files recursively, the IFS bit handles spaces in the name
find . -type f -name "*.mkv" | while IFS= read -r file;
do
    if (( job_count >= max_jobs )); then
        wait -n  # Wait for any job to finish
        ((job_count--))
    fi
	
	# Run the job in the background and increment the job count
    transcodeJob "$file" &
    ((job_count++))
done
