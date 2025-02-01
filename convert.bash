# Loop through all .mkv files
for i in *.mkv;
do
	# Skip already generated AV1 files
	[[ $i == "av1"* ]] && continue

	# Transcode each mkv
	 ffmpeg -y -hwaccel vaapi -hwaccel_output_format vaapi -i "$i" -vf 'hwmap=derive_device=qsv,format=qsv' -c:v av1_qsv -global_quality 20 -preset veryslow "av1_$i";
	
	# Begin film grain synth
	# Compute Grain Diff
	grav1synth diff "$i" "av1_$i" -o "${i%.*}.txt";
	# Apply Grain Diff
	grav1synth apply "av1_$i" -o "av1_$i" -g "${i%.*}.txt";
	
	# Clean up
	rm  "${i%.*}.txt";
	
done
