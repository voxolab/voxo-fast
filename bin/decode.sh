#!/bin/bash
SECONDS=0

source cmd.sh
source path.sh

export LC_ALL=C

name=$1
# Default GPU to yes if second parameter is not set
gpu=${2:-yes}
threads=${3:-8}
lm=${4:-3g}
graph=${5:-graph}
model=${6:-model}

ivector=200
nj=1
mfccdir=${name}/mfcci
vaddir=/${name}/mfcci
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


phi=`grep '#0' $graph/words.txt | cut -d ' ' -f 2`
nj=1

echo "PHI: $phi"

./bin/decode_innetQuad.sh --nnet $model/final.nnet --srcdir $model/ --phi $phi --rescore $lm --num_threads $threads --use_gpu $gpu  --skip_scoring true --nj $nj --cmd "$decode_cmd" --cmd2 "$rescore_cmd"  $graph/ ${name} ${name}/results || exit 1
date
duration=$SECONDS
echo "Computed in $(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
