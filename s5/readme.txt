Expt Number. Expt description
0. None below
1. Remove NSN
2. Remove stressed phones
3. Boost silence
4. Use trigram LM
5. Remove punctuation marks a) numGauss=9000 b) 3000  
(numleaves = numGauss/5)
6. Use WSJ as seed model

train: (punctuation, no punctuation)
words = 24506, 22051 
unique words = 3931, 3925
oovs = 320, 320
unique oovs = 180, 180

wav files = 561
wav durn = 117 minutes

oov/words = 1.31 oov per 100 words, 1.45 oov words per 100 words
oov/durn = 320/117 = 2.74 oov per minute, 2.74 oov per minute

test:
words = 5121, 4613
unique words = 1449, 1444
oov = 85, 85
unique oov = 45, 45

wav files = 125
wav durn = 25 minutes

oov/words = 1.66 oov per 100 words, 1.84 oov words per 100 words
oov/durn = 85/25 = 3.40 oov per minute, 3.40 oov per minute

Best result (expt no. 12345 (b) - i.e. remove punctuations and numGauss=3000)
expt_12345/b/exp/tri3b/decode/wer_15:
%WER 42.99 [ 1983 / 4613, 409 ins, 230 del, 1344 sub ]
%SER 98.40 [ 123 / 125 ]
Scored 125 sentences, 0 not present in hyp.



Commands to run:
Step 1: Convert raw to processed corpus (Do this only if you do not have processed corpus already)
# perl local/prepare_corpus.sh <i/p dir: raw corpus> <o/p dir: proc. corpus>
> perl local/prepare_corpus.sh /ws/rz-cl-2/hasegawa/amitdas/corpus/ilnews/raw /ws/rz-cl-2/hasegawa/amitdas/corpus/ilnews/processed/without_punctuations

Step 2: 
> ./run_ilnews.sh 1; ./run_ilnews.sh 2; ./run_ilnews.sh 4; ./run_ilnews.sh 5; ./run_ilnews.sh 6; ./run_ilnews.sh 7; ./run_ilnews.sh 9

Utilities:
# aggregate all words ILN
cat data/local/data/trans.txt |cut -d" " -f2- | tr -s [:space:] ' '|tr ' ' '\n'|sort -u > words.txt

# find the ascii numbers of each word
 cat words.txt | perl -ape 'print join( " | ", map { ord } split //, $_), " ";' > ascii.txt

# find words in iln that are not present in cmudict
comm -23 words.txt <(cat ../../wsj/s5/data/local/dict/cmudict/cmudict.0.7a| perl -ane 'print $_ if ($_ !~ m/^;;;/);'|cut -d' ' -f1|sort -u)|wc -l

# count the wav file duration of all train 
find corpus/train -type f -iname "*.wav"|xargs -I {}  avconv -i {}  2>&1 |grep "Duration"|awk -F":" '{print $4}'|sed 's/[^0-9.]//g'|awk '{tot += $1} END {print tot}'

