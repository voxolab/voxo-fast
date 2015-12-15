#!/bin/bash
SECONDS=0

source cmd.sh

export LC_ALL=C

name=$1
ivector=200
nj=1
mfccdir=${name}/mfcci
vaddir=/${name}/mfcci
models="/home/vjousse/asr/modeles"
date

nji=1
steps/make_mfcc.sh --mfcc-config conf/mffcIvector.conf --nj ${nji} --cmd \"$train_cmd\" ${name} ${name}/log $mfccdir || exit 1

mv ${name}/feats.scp ${name}/feati.scp
steps/make_fbank.sh  --nj ${nj} --cmd "$train_cmd"  $name   $name/log   $name/bankDir || exit 1;
steps/compute_cmvn_stats.sh   $name   $name/log   $name/bankDir
##### bug sur cmvn le fichier pour ivector et feat est le meme

date 

taille=`wc -l $name/segments| cut -d " " -f 1`
if [ $taille == 0 ]; then
    echo "segments vides ----------------------------"
    exit 0
fi


phi=`grep '#0' $models/graph/words.txt | cut -d ' ' -f 2`
nj=1

echo "PHI: $phi"

./bin/decode_innetQuad.sh --nnet $models/model/final.nnet --srcdir $models/model/ --phi $phi --rescore $models/3g --num_threads 8 --use_gpu yes  --skip_scoring true --nj $nj --cmd "$decode_cmd" --cmd2 "$rescore_cmd"  $models/graph/ ${name} ${name}/results || exit 1
date
duration=$SECONDS
echo "Computed in $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
