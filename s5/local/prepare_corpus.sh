#!/bin/bash

rawdir=$1
outdir=$2
wavextn="mp3"
textextn="txt"
# raw directory contains a list of transcription files and corresponding audio files.
# Each trans file contains a sequence of time aligned (paragraph level) transcriptions and is assumed 
# to be in the following format: 
# <start time 1> <end time 1> <transcription 1> 
# <start time 2> <end time 2> <transcription 2> 
# .
# .
# <start time n> <end time n> <transcription n> 
#
# where,
# <start/end time> = <d><d>m<d><d>.<d><d><d>s 
# <transcription> = "SIL ... SIL"
#
# E.g.
# 0m15.656s 0m28.529s "SIL Recent events ...  minorities. SIL"  
# 1m29.117s 1m45.246s "SIL One might also conclude  ... quell. SIL"
#
# Therefore, the first utterance starts at 0 minutes, 15.656 seconds,
# ends at 0 minutes, 28.529 seconds, and contains the transcription
# "SIL Recent events ...  minorities. SIL".

tmpdir=data/local/tmp
mkdir -p $tmpdir

# create scp file: <audio file>  <trans file>
# E.g.
# raw/train/1.mp3		raw/train/1.txt
# raw/train/2.mp3		raw/train/2.txt
paste <(find $rawdir -type f -iname "*.$wavextn"|sort) <(find $rawdir -type f -iname "*.$textextn"|sort) > $tmpdir/wavtrans.scp
#sed -i "s:$rawdir:$outdir:g" $tmpdir/wavtrans.scp

# Use the start and end times from each trans file to chop utterances
# from the audio file. Furthermore, create a trans file for each chopped 
# utterance.
# 
# E.g.
# If there are 10 transcriptions in 1.txt, and outdir=out, then generate:
# out/train/1_1.mp3 	out/train/1_1.txt   
# out/train/1_2.mp3 	out/train/1_2.txt
# .
# out/train/1_10.mp3 	out/train/1_10.txt
mkdir -p $outdir 
i=0
while read line
do   
   wav=$(echo $line| cut -d' ' -f1); wavf=$(basename $wav); # filename.extn
   trans=$(echo $line| cut -d' ' -f2); transf=$(basename $trans); # filename.extn
   i=$((i+1))
   #echo "$i:  $wav $trans"   
   
   wavname="${wavf%.*}" #filename only, no extn
   transname="${transf%.*}" #filename only, no extn
   
   [[ "$wavname" == "$transname" ]] || { echo "Error: Filenames do not match: $wav, $trans"; exit 1; }
   
   # $trans is the transcription file with full path, $thisoutdir is where we
   # want to save the chopped utterances (both in txt and wav)
   # E.g. if rawdir=raw, trans=raw/train/1.txt, outdir=out,
   # then thisoutdir should be "out/train" so that we save
   # out/train/1_1.txt, out/train/1_2.txt etc. instead of 
   # out/1_1.txt, out/1_2.txt etc. Therefore, we maintain the same internal
   # tree b/w $rawdir and $outdir by using $thisoutdir
   thisoutdir=$(echo $trans| sed  "s:$rawdir:$outdir:g") 
   thisoutdir=$(dirname $thisoutdir)    
   
   perl local/trans_raw2process.pl $trans $thisoutdir   
   
done < $tmpdir/wavtrans.scp
