#!/usr/bin/env bash

source path.sh

if [ ! -d $KALDI_ROOT ]; then
    echo "It seems that your KALDI_ROOT dir doesn't exist. The current value is \"$KALDI_ROOT\"."
    echo "Please be sure to edit path.sh with the correct values."
    exit 1
fi

utils_link="utils"
steps_link="steps"
local_link="local"

rm $utils_link $steps_link $local_link 2> /dev/null

ln -s $KALDI_ROOT/egs/swbd/s5b/utils $utils_link
ln -s $KALDI_ROOT/egs/swbd/s5b/steps $steps_link
ln -s $KALDI_ROOT/egs/swbd/s5b/local $local_link

if [ ! -d $KALDI_MODELS ]; then
    echo "It seems that your KALDI_MODELS dir doesn't exist. The current value is \"$KALDI_MODELS\"."
    echo "Please be sure to edit path.sh with the correct values."
    exit 1
fi

if [ ! -e $KALDI_MODELS/graph ] || [ ! -e $KALDI_MODELS/graph/HCLG.fst.map ] ; then
    echo "You need a \"graph\" directory (or symlink) in your $KALDI_MODELS dir."
    echo "This dir should contain a \"HCLG.fst.map\" file (mapped with openfst)."
    exit 1
fi


if [ ! -e $KALDI_MODELS/model ] || [ ! -e $KALDI_MODELS/model/final.nnet ]; then
    echo "You need a \"model\" directory (or symlink) in your $KALDI_MODELS dir."
    echo "This dir should contain a \"final.nnet\" file."
    exit 1
fi


if [ ! -e $KALDI_MODELS/3g ] || [ ! -e $KALDI_MODELS/3g/G.fst.phi.sort ]; then
    echo "You need a \"3g\" directory (or symlink) in your $KALDI_MODELS dir."
    echo "This dir should contain a \"G.fst.phi.sort\" file."
    exit 1
fi
