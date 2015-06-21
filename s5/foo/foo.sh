
#!/bin/bash
# aggregate all words in iln
cat data/local/data/trans.txt |cut -d" " -f2- | tr -s [:space:] ' '|tr ' ' '\n'|sort -u > words.txt

# find the ascii numbers of each word
cat words.txt | perl -ape 'print join( " | ", map { ord } split //, $_), " ";' > ascii.txt


# words present in ilnews corpus but not in cmu dictionary
cat '/media/data/workspace/work/kaldi/egs/wsj/s5/data/local/dict/cmudict/cmudict.0.7a' | \
perl -ane 's:\r::; print;' |perl -ane 'm/^;;;/ || print;'|awk '{print $1}'|sort -u |\
comm -23 words.txt -

# words present in ilnews corpus but not present in lang model (lm_tgpr.arpa)
awk '{print $2}' lm_tgpr.arpa|sort -u |comm -23 words.txt -
