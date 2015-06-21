#!/bin/bash

# Copyright 2010-2012 Microsoft Corporation  Johns Hopkins University (Author: Daniel Povey)

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.

# Call this script from one level above, e.g. from the s3/ directory.  It puts
# its output in data/local/.

# The parts of the output of this that will be needed are
# [in data/local/dict/ ]
# lexicon.txt
# extra_questions.txt
# nonsilence_phones.txt
# optional_silence.txt
# silence_phones.txt

# run this from ../
dir=data/local/dict
mkdir -p $dir
add_NSN=false
remove_stressmkrs=true

# (1) Get the CMU dictionary
svn co  https://svn.code.sf.net/p/cmusphinx/code/trunk/cmudict \
  $dir/cmudict ||
  { [ -d conf/cmudict ] && mkdir -p $dir/cmudict && cp -r conf/cmudict/* $dir/cmudict; }  ||\
  exit 1;

# can add -r 10966 for strict compatibility.

# Remove stress markrs from dict and phones 
$remove_stressmkrs && \
{
	sed -i 's:[0-9]::g' $dir/cmudict/cmudict.0.7a.symbols	
	cat $dir/cmudict/cmudict.0.7a.symbols | sort -u -o $dir/cmudict/cmudict.0.7a.symbols
	cat $dir/cmudict/cmudict.0.7a | perl -ane 'if(!m:^;;;:) { $word = $F[0]; shift @F; @G = map{s/\d+//g; $_;} @F; print "$word   @G\n";}'\
	> $dir/cmudict/cmudict.0.7atmp	
	mv $dir/cmudict/cmudict.0.7atmp $dir/cmudict/cmudict.0.7a
}

#(2) Dictionary preparation:

# Make phones symbol-table (adding in silence and verbal and non-verbal noises at this point).
# We are adding suffixes _B, _E, _S for beginning, ending, and singleton phones.

# silence phones, one per line.
if [ $add_NSN = "true" ];then
	(echo SIL; echo SPN; echo NSN) > $dir/silence_phones.txt
else
	(echo SIL; echo SPN; ) > $dir/silence_phones.txt
fi
echo SIL > $dir/optional_silence.txt

# nonsilence phones; on each line is a list of phones that correspond
# really to the same base phone.
cat $dir/cmudict/cmudict.0.7a.symbols | perl -ane 's:\r::; print;' | \
 perl -e 'while(<>){
  chop; m:^([^\d]+)(\d*)$: || die "Bad phone $_";
  $phones_of{$1} .= "$_ "; }
  foreach $list (values %phones_of) {print $list . "\n"; } ' \
  > $dir/nonsilence_phones.txt || exit 1;

# A few extra questions that will be added to those obtained by automatically clustering
# the "real" phones.  These ask about stress; there's also one for silence.
cat $dir/silence_phones.txt| awk '{printf("%s ", $1);} END{printf "\n";}' > $dir/extra_questions.txt || exit 1;
cat $dir/nonsilence_phones.txt | perl -e 'while(<>){ foreach $p (split(" ", $_)) {
  $p =~ m:^([^\d]+)(\d*)$: || die "Bad phone $_"; $q{$2} .= "$p "; } } foreach $l (values %q) {print "$l\n";}' \
 >> $dir/extra_questions.txt || exit 1;

grep -v ';;;' $dir/cmudict/cmudict.0.7a | \
 perl -ane 'if(!m:^;;;:){ s:(\S+)\(\d+\) :$1 :; print; }' \
  > $dir/lexicon1_raw_nosil.txt || exit 1;

# Add to cmudict the silences, noises etc.
if [ $add_NSN = "true" ];then
	(echo '!SIL SIL'; echo '<SPOKEN_NOISE> SPN'; echo '<UNK> SPN'; echo '<NOISE> NSN'; ) | \
	cat - $dir/lexicon1_raw_nosil.txt  > $dir/lexicon2_raw.txt || exit 1;
else
	(echo '!SIL SIL'; echo '<SPOKEN_NOISE> SPN'; echo '<UNK> SPN'; ) | \
	cat - $dir/lexicon1_raw_nosil.txt  > $dir/lexicon2_raw.txt || exit 1;	
fi

# lexicon.txt is without the _B, _E, _S, _I markers.
# This is the input to wsj_format_data.sh
[ ! -f $dir/lexicon2_raw_nostress.txt ] && cp $dir/lexicon2_raw.txt $dir/lexicon.txt
#[ -f $dir/lexicon2_raw_nostress.txt ] && cp $dir/lexicon2_raw_nostress.txt $dir/lexicon.txt


echo "Dictionary preparation succeeded"
