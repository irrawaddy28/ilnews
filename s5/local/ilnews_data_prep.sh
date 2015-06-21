#!/bin/bash

# Copyright 2015-2020  SST Lab, UIUC
# Apache 2.0.

if [[ $# -ne 1 ]]; then
   echo "Argument should the directory where IL corpus is saved."
   exit 1;
fi

ilcorpus=$1;

dir=`pwd`/data/local/data
lmdir=`pwd`/data/local/nist_lm
tmpdir=`pwd`/data/local/lm_tmp
dictdir=`pwd`/data/local/dict
conf=`pwd`/conf
local=`pwd`/local


mkdir -p $dir $lmdir $tmpdir $dictdir
local=`pwd`/local
utils=`pwd`/utils
wavextn="wav"
textextn="txt"

. ./path.sh # Needed for KALDI_ROOT
export PATH=$PATH:$KALDI_ROOT/tools/irstlm/bin
sph2pipe=$KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe
if [ ! -x $sph2pipe ]; then
   echo "Could not find (or execute) the sph2pipe program at $sph2pipe";
   exit 1;
fi


rm -rf $dir/* $lmdir/* $dictdir/*

# Create the CMU dict
$local/wsj_prepare_dict.sh || exit 1;

cd $dir

# Make a filelist of transcription files 
# <locn of txt file 1>
# <locn of txt file 2> 
find $ilcorpus -iname "*.$textextn" > trans.flist

# Convert trans filelist to trans scp
# <uttid 1> <locn of txt file 1>
# <uttid 2> <locn of txt file 2> 
cat trans.flist |awk -F"/" '{print $NF}'|sed "s:\.$textextn$::g" | paste - trans.flist  | sort > trans.scp

# Convert trans.scp to trans.txt
# <uttid 1> <transcription in txt file 1>
# <uttid 2> <transcription in txt file 2>
# Can do this either by a) paste or b) perl. Both produce identical results.
# a)
# paste <(cat trans.scp|awk '{print $1}') <(cat trans.scp|awk '{print $2}'|xargs cat) > trans.txt
#
# b)
cat trans.scp|perl -ane '$uttid=$F[0]; 
				open(FILE,$F[1]) || die "Error: no file found. $F[1]"; 
				$text = do {local $/; <FILE> }; 
				print "$uttid", "\t", "$text";' > trans.txt || exit 1;
				
# Create train_wav.scp, train.txt, test_wav.scp, test.txt
for x in train test; do
   find $ilcorpus/$x -iname "*.$wavextn" > ${x}_wav.flist
   $local/flist2scp.pl ${x}_wav.flist | sort > ${x}_wav.scp
   join -1 1 -2 1 ${x}_wav.scp  trans.txt | cut -d" " -f1,3- > $x.txt || exit 1;
   # Using WSJ dictionary, convert OOV words to UNK
   cp ${x}.txt ${x}_nounk.txt; 
   cat ${x}_nounk.txt| perl $local/replace_oov_in_trans.pl $dictdir/lexicon.txt "<UNK>" ${x}_oovcount.txt > ${x}.txt   
   # cp trans.txt trans_nounk.txt; 
   # cat trans_nounk.txt| perl $local/replace_oov_in_trans.pl $dictdir/lexicon.txt "<UNK>" oovcount.txt > trans.txt
done

# Make the utt2spk and spk2utt files.
for x in train test; do
   cat ${x}_wav.scp | awk '{print $1}' | perl -ane 'chop; m:^(\w+?)_(\w+?)_(\w+)$:; print "$_ $1_$2\n";' > $x.utt2spk  # non-greedy match (\w+?) vs greedy match (\w+)
   cat $x.utt2spk | $utils/utt2spk_to_spk2utt.pl > $x.spk2utt || exit 1;
done

# Make the spk2gender file
cat trans.scp | awk '{print $1}' | perl -ane 'chop; m:^(\w+?)_(\w+?)_(\w+)$:; print "$1_$2 $2\n";' |sort -u > spk2gender

# Create lm
# (2) Create the phone bigram LM
  [ -z "$IRSTLM" ] && \
    echo "LM building won't work without setting the IRSTLM env variable" && exit 1;
  ! which build-lm.sh 2>/dev/null  && \
    echo "IRSTLM does not seem to be installed (build-lm.sh not on your path): " && \
    echo "go to <kaldi-root>/tools and try 'make irstlm_tgt'" && exit 1;

  cut -d' ' -f2- train.txt | sed -e 's:^:<s> :' -e 's:$: </s>:' \
    > lm_train.txt
  build-lm.sh -i lm_train.txt -n 3 -o $tmpdir/lm_bg.ilm.gz

  compile-lm $tmpdir/lm_bg.ilm.gz -t=yes /dev/stdout | \
  grep -v unk | gzip -c > $lmdir/lm_bg.arpa.gz 

echo "Dictionary & language model preparation succeeded"
exit 0;

# Copy the language models from conf/lm

# in case we want to limit lm's on most frequent words, copy lm training word frequency list
# cp links/13-32.1/wsj1/doc/lng_modl/vocab/wfl_64.lst $lmdir
# chmod u+w $lmdir/*.lst # had weird permissions on source.

# The 20K vocab, open-vocabulary language model (i.e. the one with UNK), without
# verbalized pronunciations.   This is the most common test setup, I understand.

# bigram
# cp links/13-32.1/wsj1/doc/lng_modl/base_lm/bcb20onp.z $lmdir/lm_bg.arpa.gz || exit 1;
# $ chmod u+w $lmdir/lm_bg.arpa.gz

# trigram would be:
cp $conf/lm/lm_tg.arpa.gz $lmdir/lm_tg.arpa.gz || exit 1;
prune-lm --threshold=1e-7 $lmdir/lm_tg.arpa.gz $lmdir/lm_tgpr.arpa || exit 1;
gzip -f $lmdir/lm_tgpr.arpa || exit 1;

# repeat for 5k language models
# bigram
# cp links/13-32.1/wsj1/doc/lng_modl/base_lm/bcb05onp.z  $lmdir/lm_bg_5k.arpa.gz || exit 1;
# chmod u+w $lmdir/lm_bg_5k.arpa.gz

# trigram would be: !only closed vocabulary here!
cp $conf/lm/lm_tg_5k.arpa.gz $lmdir/lm_tg_5k.arpa.gz || exit 1;
chmod u+w $lmdir/lm_tg_5k.arpa.gz
gunzip $lmdir/lm_tg_5k.arpa.gz
tail -n 4328839 $lmdir/lm_tg_5k.arpa | gzip -c -f > $lmdir/lm_tg_5k.arpa.gz
rm $lmdir/lm_tg_5k.arpa

prune-lm --threshold=1e-7 $lmdir/lm_tg_5k.arpa.gz $lmdir/lm_tgpr_5k.arpa || exit 1;
gzip -f $lmdir/lm_tgpr_5k.arpa || exit 1;

echo "Data preparation succeeded"
