# AV1 Conversion Script
Just a little script I made to recursivly reencode all non AV1 mkv files to AV1 ones using my intel arc A380

Currently only supports QSV, I use vaapi to deencode and QSV to encode due to a bug on my system, it works for me but if you want to use a different codec just change that one line. 

## Requirements: 
`FFMPEG` (with av1_qsv compiled in)

`FFPROBE`

`grav1synth`

## Arguments: 
  `--skip-grain` Has no parameters (Massively faster if film grain is unneeded)
  
  `--no-log`     Has no parameters
  
  `--worker-count` default is 3, but put here however many parallel jobs you want

## Running:
To run this script I recommend doing `nohup Convert2AV1.bash [arg] &`
