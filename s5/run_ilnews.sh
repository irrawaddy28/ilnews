#!/bin/bash

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
set -e # exit on error
# This is a shell script, but it's recommended that you run the commands one by
# one by copying and pasting into the shell.

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

# If n = no. of frames reqd. to train 1 parameter in the AM,
#    M = number of mixtures in the AM,
#    D = size of each mixture in the AM (1 mean vec + 1 diag cov)
#    Fps = number of frames per second,
# then, n*M*D/Fps = reqd. duration of training set in seconds 
# Since size of train set = 7020 s, and setting n = 3, D = 80, Fps = 100
# M = (7020*100)/(3*80) ~ 3000. This is $totgauss
totgauss=3000  # 9000
numleaves=600 # 1800

#wsj0=/ais/gobi2/speech/WSJ/csr_?_senn_d?
#wsj1=/ais/gobi2/speech/WSJ/csr_senn_d?

#wsj0=/mnt/matylda2/data/WSJ0
#wsj1=/mnt/matylda2/data/WSJ1

#wsj0=/data/corpora0/LDC93S6B
#wsj1=/data/corpora0/LDC94S13B

#wsj0=/export/corpora5/LDC/LDC93S6B
#wsj1=/export/corpora5/LDC/LDC94S13B

ilcorpus=${corpus_dir}/ilnews/processed/without_punctuations
#ilcorpus=`pwd`/corpus
echo "ILN corpus is at $ilcorpus";

stage=$1;

if [[ $stage -eq 1 ]]; then
local/ilnews_data_prep.sh $ilcorpus || exit 1;

# Sometimes, we have seen WSJ distributions that do not have subdirectories 
# like '11-13.1', but instead have 'doc', 'si_et_05', etc. directly under the 
# wsj0 or wsj1 directories. In such cases, try the following:
#
# corpus=/exports/work/inf_hcrc_cstr_general/corpora/wsj
# local/cstr_wsj_data_prep.sh $corpus
# rm data/local/dict/lexiconp.txt
# $corpus must contain a 'wsj0' and a 'wsj1' subdirectory for this to work.

# local/wsj_prepare_dict.sh || exit 1;

utils/prepare_lang.sh data/local/dict "<UNK>" data/local/lang_tmp data/lang || exit 1;

local/ilnews_format_data.sh || exit 1;

exit 1;
 # We suggest to run the next three commands in the background,
 # as they are not a precondition for the system building and
 # most of the tests: these commands build a dictionary
 # containing many of the OOVs in the WSJ LM training data,
 # and an LM trained directly on that data (i.e. not just
 # copying the arpa files from the disks from LDC).
 # Caution: the commands below will only work if $decode_cmd 
 # is setup to use qsub.  Else, just remove the --cmd option.
 # NOTE: If you have a setup corresponding to the cstr_wsj_data_prep.sh style,
 # use local/cstr_wsj_extend_dict.sh $corpus/wsj1/doc/ instead.

 # Note: I am commenting out the RNNLM-building commands below.  They take up a lot
 # of CPU time and are not really part of the "main recipe."
 # Be careful: appending things like "-l mem_free=10G" to $decode_cmd
 # won't always work, it depends what $decode_cmd is.
  (
   local/wsj_extend_dict.sh $wsj1/13-32.1  && \
   utils/prepare_lang.sh data/local/dict_larger "<SPOKEN_NOISE>" data/local/lang_larger data/lang_bd && \
   local/wsj_train_lms.sh &&
   local/wsj_format_local_lms.sh # &&
 #
 #   (  local/wsj_train_rnnlms.sh --cmd "$decode_cmd -l mem_free=10G" data/local/rnnlm.h30.voc10k &
 #       sleep 20; # wait till tools compiled.
 #     local/wsj_train_rnnlms.sh --cmd "$decode_cmd -l mem_free=12G" \
 #      --hidden 100 --nwords 20000 --class 350 --direct 1500 data/local/rnnlm.h100.voc20k &
 #     local/wsj_train_rnnlms.sh --cmd "$decode_cmd -l mem_free=14G" \
 #      --hidden 200 --nwords 30000 --class 350 --direct 1500 data/local/rnnlm.h200.voc30k &
 #     local/wsj_train_rnnlms.sh --cmd "$decode_cmd -l mem_free=16G" \
 #      --hidden 300 --nwords 40000 --class 400 --direct 2000 data/local/rnnlm.h300.voc40k &
 #   )
   false && \ # Comment this out to train RNNLM-HS
   (
       num_threads_rnnlm=8
       local/wsj_train_rnnlms.sh --rnnlm_ver rnnlm-hs-0.1b --threads $num_threads_rnnlm \
	   --cmd "$decode_cmd -l mem_free=1G" --bptt 4 --bptt-block 10 --hidden 30  --nwords 10000 --direct 1000 data/local/rnnlm-hs.h30.voc10k  
       local/wsj_train_rnnlms.sh --rnnlm_ver rnnlm-hs-0.1b --threads $num_threads_rnnlm \
	   --cmd "$decode_cmd -l mem_free=1G" --bptt 4 --bptt-block 10 --hidden 100 --nwords 20000 --direct 1500 data/local/rnnlm-hs.h100.voc20k 
       local/wsj_train_rnnlms.sh --rnnlm_ver rnnlm-hs-0.1b --threads $num_threads_rnnlm \
	   --cmd "$decode_cmd -l mem_free=1G" --bptt 4 --bptt-block 10 --hidden 300 --nwords 30000 --direct 1500 data/local/rnnlm-hs.h300.voc30k 
       local/wsj_train_rnnlms.sh --rnnlm_ver rnnlm-hs-0.1b --threads $num_threads_rnnlm \
	   --cmd "$decode_cmd -l mem_free=1G" --bptt 4 --bptt-block 10 --hidden 400 --nwords 40000 --direct 2000 data/local/rnnlm-hs.h400.voc40k 
   )
  ) &
fi

if [[ $stage -eq 2 ]]; then
# Now make MFCC features.
# mfccdir should be some place with a largish disk where you
# want to store MFCC features.
mfccdir=mfcc
for x in train test; do 
 steps/make_mfcc.sh --cmd "$train_cmd" --nj 20 \
   data/$x exp/make_mfcc/$x $mfccdir || exit 1;
 steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir || exit 1;
done
fi

if [[ $stage -eq 3 ]]; then
utils/subset_data_dir.sh data/train 1000 data/train.1k 

#utils/subset_data_dir.sh --first data/train_si284 7138 data/train_si84 || exit 1

# Now make subset with the shortest 2k utterances from si-84.
#utils/subset_data_dir.sh --shortest data/train_si84 2000 data/train_si84_2kshort || exit 1;

# Now make subset with half of the data from si-84.
#utils/subset_data_dir.sh data/train_si84 3500 data/train_si84_half || exit 1;
fi

if [[ $stage -eq 4 ]]; then
# Note: the --boost-silence option should probably be omitted by default
# for normal setups.  It doesn't always help. [it's to discourage non-silence
# models from modeling silence.]
steps/train_mono.sh --boost-silence 1.25 --nj 3 --cmd "$train_cmd" \
  data/train data/lang exp/mono || exit 1;
  
  
utils/mkgraph.sh --mono data/lang_test_bg exp/mono exp/mono/graph


#(
# utils/mkgraph.sh --mono data/lang_test_tgpr exp/mono0a exp/mono0a/graph_tgpr && \
# steps/decode.sh --nj 10 --cmd "$decode_cmd" \
#      exp/mono0a/graph_tgpr data/test_dev93 exp/mono0a/decode_tgpr_dev93 && \
# steps/decode.sh --nj 8 --cmd "$decode_cmd" \
#   exp/mono0a/graph_tgpr data/test_eval92 exp/mono0a/decode_tgpr_eval92 
#) &

steps/decode.sh --config conf/decode.config --nj 1 --cmd "$decode_cmd" \
  exp/mono/graph data/test exp/mono/decode


# Get alignments from monophone system.
steps/align_si.sh --boost-silence 1.25 --nj 3 --cmd "$train_cmd" \
   data/train data/lang exp/mono exp/mono_ali || exit 1;
fi

if [[ $stage -eq 5 ]]; then
# train tri1 [first triphone pass]
steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
    $numleaves $totgauss data/train data/lang exp/mono_ali exp/tri1 || exit 1;

#while [ ! -f data/lang_test_tgpr/tmp/LG.fst ] || \
#   [ -z data/lang_test_tgpr/tmp/LG.fst ]; do
#  sleep 20;
#done
#sleep 30;
# or the mono mkgraph.sh might be writing 
# data/lang_test_tgpr/tmp/LG.fst which will cause this to fail.

# utils/mkgraph.sh data/lang_test_tgpr exp/tri1 exp/tri1/graph_tgpr || exit 1;


# steps/decode.sh --nj 10 --cmd "$decode_cmd" \
#   exp/tri1/graph_tgpr data/test_dev93 exp/tri1/decode_tgpr_dev93 || exit 1;
# steps/decode.sh --nj 8 --cmd "$decode_cmd" \
#  exp/tri1/graph_tgpr data/test_eval92 exp/tri1/decode_tgpr_eval92 || exit 1;


utils/mkgraph.sh data/lang_test_bg exp/tri1 exp/tri1/graph

steps/decode.sh --config conf/decode.config --nj 1 --cmd "$decode_cmd" \
  exp/tri1/graph data/test exp/tri1/decode

steps/align_si.sh --boost-silence 1.25 --nj 3 --cmd "$train_cmd" \
  data/train data/lang exp/tri1 exp/tri1_ali|| exit 1;
fi

if [[ $stage -eq 6 ]]; then
# Train tri2a, which is deltas + delta-deltas, on si84 data.
steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
  $numleaves $totgauss data/train data/lang exp/tri1_ali exp/tri2a || exit 1;

utils/mkgraph.sh data/lang_test_bg exp/tri2a exp/tri2a/graph || exit 1;

steps/decode.sh --nj 1 --cmd "$decode_cmd" \
  exp/tri2a/graph data/test exp/tri2a/decode || exit 1;
  
fi


if [[ $stage -eq 7 ]]; then
steps/train_lda_mllt.sh --boost-silence 1.25 --cmd "$train_cmd" \
   --splice-opts "--left-context=3 --right-context=3" \
   $numleaves $totgauss data/train data/lang exp/tri1_ali exp/tri2b || exit 1;

utils/mkgraph.sh data/lang_test_bg exp/tri2b exp/tri2b/graph || exit 1;

steps/decode.sh --nj 1 --cmd "$decode_cmd" \
  exp/tri2b/graph data/test exp/tri2b/decode || exit 1;
  
# you could run these scripts at this point, that use VTLN.
# local/run_vtln.sh
# local/run_vtln2.sh
 

# At this point, you could run the example scripts that show how VTLN works.
# We haven't included this in the default recipes yet.
# local/run_vtln.sh
# local/run_vtln2.sh

# Now, with dev93, compare lattice rescoring with biglm decoding,
# going from tgpr to tg.  Note: results are not the same, even though they should
# be, and I believe this is due to the beams not being wide enough.  The pruning
# seems to be a bit too narrow in the current scripts (got at least 0.7% absolute
# improvement from loosening beams from their current values).

#steps/decode_biglm.sh --nj 10 --cmd "$decode_cmd" \
#  exp/tri2b/graph_tgpr data/lang_test_{tgpr,tg}/G.fst \
#  data/test_dev93 exp/tri2b/decode_tgpr_dev93_tg_biglm

# baseline via LM rescoring of lattices.
#steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_tgpr/ data/lang_test_tg/ \
#  data/test_dev93 exp/tri2b/decode_tgpr_dev93 exp/tri2b/decode_tgpr_dev93_tg || exit 1;

# Trying Minimum Bayes Risk decoding (like Confusion Network decoding):
#mkdir exp/tri2b/decode_tgpr_dev93_tg_mbr 
#cp exp/tri2b/decode_tgpr_dev93_tg/lat.*.gz exp/tri2b/decode_tgpr_dev93_tg_mbr 
#local/score_mbr.sh --cmd "$decode_cmd" \
# data/test_dev93/ data/lang_test_tgpr/ exp/tri2b/decode_tgpr_dev93_tg_mbr

#steps/decode_fromlats.sh --cmd "$decode_cmd" \
#  data/test_dev93 data/lang_test_tgpr exp/tri2b/decode_tgpr_dev93 \
#  exp/tri2a/decode_tgpr_dev93_fromlats || exit 1


# Align tri2b system with si84 data.
steps/align_si.sh  --boost-silence 1.25 --nj 3 --cmd "$train_cmd" \
  data/train data/lang exp/tri2b exp/tri2b_ali  || exit 1;
fi

if [[ $stage -eq 8 ]]; then
local/run_mmi_tri2b.sh
fi

if [[ $stage -eq 9 ]]; then
# From 2b system, train 3b which is LDA + MLLT + SAT.
steps/train_sat.sh --boost-silence 1.25 --cmd "$train_cmd" \
  $numleaves $totgauss data/train data/lang exp/tri2b_ali exp/tri3b || exit 1;
  
utils/mkgraph.sh data/lang_test_bg exp/tri3b exp/tri3b/graph || exit 1;

steps/decode_fmllr.sh --nj 1 --cmd "$decode_cmd" \
  exp/tri3b/graph data/test exp/tri3b/decode || exit 1;
  
: <<'COMMENT'
# At this point you could run the command below; this gets
# results that demonstrate the basis-fMLLR adaptation (adaptation
# on small amounts of adaptation data).
local/run_basis_fmllr.sh

steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_tgpr data/lang_test_tg \
  data/test_dev93 exp/tri3b/decode_tgpr_dev93 exp/tri3b/decode_tgpr_dev93_tg || exit 1;
steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_tgpr data/lang_test_tg \
  data/test_eval92 exp/tri3b/decode_tgpr_eval92 exp/tri3b/decode_tgpr_eval92_tg || exit 1;


# Trying the larger dictionary ("big-dict"/bd) + locally produced LM.
utils/mkgraph.sh data/lang_test_bd_tgpr exp/tri3b exp/tri3b/graph_bd_tgpr || exit 1;

steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 8 \
  exp/tri3b/graph_bd_tgpr data/test_eval92 exp/tri3b/decode_bd_tgpr_eval92 || exit 1;
steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 10 \
  exp/tri3b/graph_bd_tgpr data/test_dev93 exp/tri3b/decode_bd_tgpr_dev93 || exit 1;

# amit: the calls below to lmrescore_const_arpa.sh, lmrescore.sh didn't work.
# lmrescore_const_arpa.sh doesn't work since it looks 
# for a non-existent file data/lang_test_bd_fgconst/G.carpa. Don't know
# how and where this is created. G.carpa must exist before you call lmrescore_const_arpa.sh.
# lmrescore.sh didn't work since it looks for a non-existent file data/lang_test_bd_fg/G.fst.
# Don't know how and where this is created.
# Example of rescoring with ConstArpaLm.
# steps/lmrescore_const_arpa.sh \
#  --cmd "$decode_cmd" data/lang_test_bd_{tgpr,fgconst} \
#  data/test_eval92 exp/tri3b/decode_bd_tgpr_eval92{,_fgconst} || exit 1;

#steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_bd_tgpr data/lang_test_bd_fg \
#  data/test_eval92 exp/tri3b/decode_bd_tgpr_eval92 exp/tri3b/decode_bd_tgpr_eval92_fg \
#  || exit 1;
#steps/lmrescore.sh --cmd "$decode_cmd" data/lang_test_bd_tgpr data/lang_test_bd_tg \
#  data/test_eval92 exp/tri3b/decode_bd_tgpr_eval92 exp/tri3b/decode_bd_tgpr_eval92_tg \
#  || exit 1;

# The command below is commented out as we commented out the steps above
# that build the RNNLMs, so it would fail.
# local/run_rnnlms_tri3b.sh

# The command below is commented out as we commented out the steps above
# that build the RNNLMs (HS version), so it would fail.
# wait; local/run_rnnlm-hs_tri3b.sh

# The following two steps, which are a kind of side-branch, try mixing up
( # from the 3b system.  This is to demonstrate that script.
 steps/mixup.sh --cmd "$train_cmd" \
   20000 data/train_si84 data/lang exp/tri3b exp/tri3b_20k || exit 1;
 steps/decode_fmllr.sh --cmd "$decode_cmd" --nj 10 \
   exp/tri3b/graph_tgpr data/test_dev93 exp/tri3b_20k/decode_tgpr_dev93  || exit 1;
)

COMMENT

# From 3b system, align all si284 data.
steps/align_fmllr.sh --boost-silence 1.25 --nj 3 --cmd "$train_cmd" \
  data/train data/lang exp/tri3b exp/tri3b_ali || exit 1;
fi

if [[ $stage -eq 10 ]]; then
# From 3b system, train another SAT system (tri4a) with all the si284 data.

steps/train_sat.sh  --cmd "$train_cmd" \
  4200 40000 data/train_si284 data/lang exp/tri3b_ali_si284 exp/tri4a || exit 1;
(
 utils/mkgraph.sh data/lang_test_tgpr exp/tri4a exp/tri4a/graph_tgpr || exit 1;
 steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" \
   exp/tri4a/graph_tgpr data/test_dev93 exp/tri4a/decode_tgpr_dev93 || exit 1;
 steps/decode_fmllr.sh --nj 8 --cmd "$decode_cmd" \
   exp/tri4a/graph_tgpr data/test_eval92 exp/tri4a/decode_tgpr_eval92 || exit 1;
) & 
fi

if [[ $stage -eq 11 ]]; then
# This step is just to demonstrate the train_quick.sh script, in which we
# initialize the GMMs from the old system's GMMs.
steps/train_quick.sh --nj 3 --cmd "$train_cmd" \
   900 4500 data/train data/lang ../../wsj/s5/exp/tri3b_ali_si284 exp/tri4b || exit 1;

utils/mkgraph.sh data/lang_test_bg exp/tri4b exp/tri4b/graph || exit 1;

steps/decode_fmllr.sh --nj 1 --cmd "$decode_cmd" \
  exp/tri4b/graph data/test exp/tri4b/decode || exit 1;
  
steps/align_fmllr.sh --boost-silence 1.25 --nj 3 --cmd "$train_cmd" \
  data/train data/lang exp/tri4b exp/tri4b_ali || exit 1; 
exit 0;  
   
# Amit: Run this in fg since we want exp/tri4b/{decode_bd_tgpr_dev93, decode_bd_tgpr_eval92}
# to be ready before we run Karel's run_dnn.sh recipe. If we run this in bg, Karel's dnn
# recipe might be executed before exp/tri4b/{decode_bd_tgpr_dev93, decode_bd_tgpr_eval92}
# is ready resulting in aborting this script.
#( 
 utils/mkgraph.sh data/lang_test_tgpr exp/tri4b exp/tri4b/graph_tgpr || exit 1;
 steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" \
   exp/tri4b/graph_tgpr data/test_dev93 exp/tri4b/decode_tgpr_dev93 || exit 1;
 steps/decode_fmllr.sh --nj 8 --cmd "$decode_cmd" \
  exp/tri4b/graph_tgpr data/test_eval92 exp/tri4b/decode_tgpr_eval92 || exit 1;

 utils/mkgraph.sh data/lang_test_bd_tgpr exp/tri4b exp/tri4b/graph_bd_tgpr || exit 1;
 steps/decode_fmllr.sh --nj 10 --cmd "$decode_cmd" \
   exp/tri4b/graph_bd_tgpr data/test_dev93 exp/tri4b/decode_bd_tgpr_dev93 || exit 1;
 steps/decode_fmllr.sh --nj 8 --cmd "$decode_cmd" \
  exp/tri4b/graph_bd_tgpr data/test_eval92 exp/tri4b/decode_bd_tgpr_eval92 || exit 1;
#) &

# Amit: commented this backgrd job since I don't need it
#( # run decoding with larger dictionary and pron-probs.  Need to get dict with
  ## pron-probs first.  [This seems to help by about 0.1% absolute in general.]
  #cp -rT data/local/dict_larger data/local/dict_larger_pp
  #rm -r data/local/dict_larger_pp/{b,f,*.gz,lexicon.txt}
  #steps/get_lexicon_probs.sh data/train_si284 data/lang exp/tri4b data/local/dict_larger/lexicon.txt \
    #exp/tri4b_lexprobs data/local/dict_larger_pp/lexiconp.txt || exit 1;
  #utils/prepare_lang.sh --share-silence-phones true \
    #data/local/dict_larger_pp "<SPOKEN_NOISE>" data/dict_larger/tmp data/lang_bd_pp
  #cmp data/lang_bd/words.txt data/lang_bd_pp/words.txt || exit 1;
  #for suffix in tg tgpr fg; do
    #cp -rT data/lang_bd_pp data/lang_test_bd_pp_${suffix}
    #cp data/lang_test_bd_${suffix}/G.fst data/lang_test_bd_pp_${suffix}/G.fst || exit 1;
  #done
  #utils/mkgraph.sh data/lang_test_bd_pp_tgpr exp/tri4b exp/tri4b/graph_bd_pp_tgpr || exit 1;
  #steps/decode_fmllr.sh --nj $nj_decode --cmd "$decode_cmd" \
    #exp/tri4b/graph_bd_pp_tgpr data/test_dev93 exp/tri4b/decode_bd_pp_tgpr_dev93 
  #steps/decode_fmllr.sh --nj $nj_decode --cmd "$decode_cmd" \
    #exp/tri4b/graph_bd_pp_tgpr data/test_eval92 exp/tri4b/decode_bd_pp_tgpr_eval92
#)
fi

if [[ $stage -eq 12 ]]; then
# Train and test MMI, and boosted MMI, on tri4b (LDA+MLLT+SAT on
# all the data).  Use 30 jobs.
#steps/align_fmllr.sh --nj 30 --cmd "$train_cmd" \
#  data/train_si284 data/lang exp/tri4b exp/tri4b_ali_si284 || exit 1;
steps/align_fmllr.sh --nj 10 --cmd "$train_cmd" \
  data/train_si284 data/lang exp/tri4b exp/tri4b_ali_si284 || exit 1;

# These demonstrate how to build a sytem usable for online-decoding with the nnet2 setup.
# (see local/run_nnet2.sh for other, non-online nnet2 setups).
# Amit: commented scripts below since I don't need em
# local/online/run_nnet2.sh
# local/online/run_nnet2_baseline.sh
# local/online/run_nnet2_discriminative.sh
# local/run_mmi_tri4b.sh
fi

if [[ $stage -eq 13 ]]; then
local/run_nnet2.sh
fi

if [[ $stage -eq 14 ]]; then
## Segregated some SGMM builds into a separate file.
#local/run_sgmm.sh

# You probably want to run the sgmm2 recipe as it's generally a bit better:
local/run_sgmm2.sh
fi

if [[ $stage -eq 15 ]]; then
# We demonstrate MAP adaptation of GMMs to gender-dependent systems here.  This also serves
# as a generic way to demonstrate MAP adaptation to different domains.
local/run_gender_dep.sh
fi

if [[ $stage -eq 16 ]]; then
# You probably want to run the hybrid recipe as it is complementary:
local/run_dnn.sh
fi

if [[ $stage -eq 17 ]]; then
# The next two commands show how to train a bottleneck network based on the nnet2 setup,
# and build an SGMM system on top of it.
#local/run_bnf.sh
#local/run_bnf_sgmm.sh
:
fi

if [[ $stage -eq 18 ]]; then
# You probably want to try KL-HMM 
#local/run_kl_hmm.sh
:
fi

# Getting results [see RESULTS file]
# for x in exp/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done


# KWS setup. We leave it commented out by default

# $duration is the length of the search collection, in seconds
#duration=`feat-to-len scp:data/test_eval92/feats.scp  ark,t:- | awk '{x+=$2} END{print x/100;}'`
#local/generate_example_kws.sh data/test_eval92/ data/kws/
#local/kws_data_prep.sh data/lang_test_bd_tgpr/ data/test_eval92/ data/kws/
#
#steps/make_index.sh --cmd "$decode_cmd" --acwt 0.1 \
#  data/kws/ data/lang_test_bd_tgpr/ \
#  exp/tri4b/decode_bd_tgpr_eval92/ \
#  exp/tri4b/decode_bd_tgpr_eval92/kws
#
#steps/search_index.sh --cmd "$decode_cmd" \
#  data/kws \
#  exp/tri4b/decode_bd_tgpr_eval92/kws
#
# If you want to provide the start time for each utterance, you can use the --segments
# option. In WSJ each file is an utterance, so we don't have to set the start time.
#cat exp/tri4b/decode_bd_tgpr_eval92/kws/result.* | \
#  utils/write_kwslist.pl --flen=0.01 --duration=$duration \
#  --normalize=true --map-utter=data/kws/utter_map \
#  - exp/tri4b/decode_bd_tgpr_eval92/kws/kwslist.xml

# # forward-backward decoding example [way to speed up decoding by decoding forward
# # and backward in time] 
# local/run_fwdbwd.sh
