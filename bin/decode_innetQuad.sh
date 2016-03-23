#!/bin/bash

# Copyright 2012-2013 Karel Vesely, Daniel Povey
# Apache 2.0

# Begin configuration section. 
nnet=               # non-default location of DNN (optional)
feature_transform=  # non-default location of feature_transform (optional)
model=              # non-default location of transition model (optional)
class_frame_counts= # non-default location of PDF counts (optional)
srcdir=             # non-default location of DNN-dir (decouples model dir from decode dir)
trans=
stage=0 # stage=1 skips lattice generation
nj=20
rescore=
phi=
cmd=run.pl
cmd2=run.pl
acwt=0.10 # note: only really affects pruning (scoring is on lattices).
beam=13.0
latbeam=8.0
max_active=7000 # limit of active tokens
max_mem=50000000 # approx. limit to memory consumption during minimization in bytes

skip_scoring=true
scoring_opts="--min-lmwt 4 --max-lmwt 15"

num_threads=1 # if >1, will use latgen-faster-parallel
parallel_opts="--threads $((num_threads+1))" # use 2 CPUs (1 DNN-forward, 1 decoder)
use_gpu="no" # yes|no|optionaly
ivector=0
# End configuration section.

echo "$0 $@"  # Print the command line for logging

[ -f ./path.sh ] && . ./path.sh; # source the path.
. parse_options.sh || exit 1;

if [ $# != 3 ]; then
   echo "Usage: $0 [options] <graph-dir> <data-dir> <decode-dir>"
   echo "... where <decode-dir> is assumed to be a sub-directory of the directory"
   echo " where the DNN and transition model is."
   echo "e.g.: $0 exp/dnn1/graph_tgpr data/test exp/dnn1/decode_tgpr"
   echo ""
   echo "This script works on plain or modified features (CMN,delta+delta-delta),"
   echo "which are then sent through feature-transform. It works out what type"
   echo "of features you used from content of srcdir."
   echo ""
   echo "main options (for others, see top of script file)"
   echo "  --config <config-file>                           # config containing options"
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo ""
   echo "  --nnet <nnet>                                    # non-default location of DNN (opt.)"
   echo "  --srcdir <dir>                                   # non-default dir with DNN/models, can be different"
   echo "                                                   # from parent dir of <decode-dir>' (opt.)"
   echo ""
   echo "  --acwt <float>                                   # select acoustic scale for decoding"
   echo "  --scoring-opts <opts>                            # options forwarded to local/score.sh"
   echo "  --num-threads <N>                                # N>1: run multi-threaded decoder"
   exit 1;
fi


graphdir=$1
data=$2
dir=$3

dirLat=`echo $dir | sed 's/^decode/mesLats/'`
[ -z $srcdir ] && srcdir=`dirname $dir`; # Default model directory one level up from decoding directory.
sdata=$data/split$nj;

mkdir -p $dir/log

[[ -d $sdata && $data/feats.scp -ot $sdata ]] || split_data.sh $data $nj || exit 1;
echo $nj > $dir/num_jobs

# Select default locations to model files (if not already set externally)
if [ -z "$nnet" ]; then nnet=$srcdir/final.nnet; fi
if [ -z "$model" ]; then model=$srcdir/final.mdl; fi
if [ -z "$feature_transform" ]; then feature_transform=$srcdir/final.feature_transform; fi
if [ -z "$class_frame_counts" ]; then class_frame_counts=$srcdir/ali_train_pdf.counts; fi
if [ -z "$trans" ]; then trans=$srcdir/final.mat; echo "trans :$trans"; fi
#splice_opts=`cat $srcdir/splice_opts 2>/dev/null` # frame-splicing options.
# Check that files exist
for f in $sdata/1/feats.scp $nnet $model $feature_transform $class_frame_counts $graphdir/HCLG.fst.map; do
  [ ! -f $f ] && echo "$0: missing file $f" && exit 1;
done

# Possibly use multi-threaded decoder
thread_string=
[ $num_threads -gt 1 ] && thread_string="-parallel --num-threads=$num_threads" 
#forward_thread_string=
# [  $use_gpu  != "yes" ]  &&  forward_thread_string="-parallel --num-threads=$num_threads"
forward_thread_string=""

  
# PREPARE FEATURE EXTRACTION PIPELINE
# Create the feature stream:
feats="ark,s,cs:copy-feats scp:$sdata/JOB/feats.scp ark:- |"
# Optionally add cmvn
if [ -f $srcdir/norm_vars ]; then
  norm_vars=$(cat $srcdir/norm_vars 2>/dev/null)
  [ ! -f $sdata/1/cmvn.scp ] && echo "$0: cannot find cmvn stats $sdata/1/cmvn.scp" && exit 1
  feats="$feats apply-cmvn --norm-vars=$norm_vars --utt2spk=ark:$sdata/JOB/utt2spk scp:$sdata/JOB/cmvn.scp ark:- ark:- |"
  #feats="$feats apply-cmvn-sliding --center=false --norm-vars=$norm_vars scp:$sdata/JOB/cmvn.scp ark:- ark:- |"
fi
# Optionally add deltas
if [ -f $srcdir/delta_order ]; then
  delta_order=$(cat $srcdir/delta_order)
  feats="$feats add-deltas --delta-order=$delta_order ark:- ark:- |"
fi
if [ -f $trans ]; then
feats="$feats splice-feats $splice_opts ark:- ark:- | transform-feats $srcdir/final.mat ark:- ark:- |"

fi

ici=`pwd`
[ !  -d $dirLat ] && mkdir -p $dirLat
echo $feats
# Run the decoding in the queue
if [ $stage -le 0 ]; then
  $cmd $parallel_opts JOB=1:$nj $dir/log/decode.JOB.log \
    nnet-forward$forward_thread_string $param_ivector --feature-transform=$feature_transform --no-softmax=true --class-frame-counts=$class_frame_counts --use-gpu=$use_gpu $nnet "$feats" ark:- \| \
    latgen-faster-mapped$thread_string --max-active=$max_active --max-mem=$max_mem --beam=$beam \
    --lattice-beam=$latbeam --map --acoustic-scale=$acwt --allow-partial=true --word-symbol-table=$graphdir/words.txt --determinize-lattice=false \
    $model $graphdir/HCLG.fst.map  ark:- ark:-   \| \
	lattice-rescore-ngram-parallel --sequence=false --res-beam=1.7990894680536321e+01 --res-prebeam=9.6952974701867127e+00 --res-lattice-beam=1.0705767638403191e+01 --num-threads=$num_threads  --res-wip=0.545441457072237 --res-filProb=0.0014731059878509 --res-silProb=0.393561576959076 --res-fudge=1.6842438228765488e+01 --res-phi=$phi $model  ark:-  $rescore/G.fst.sort.map ark:- \| \
 lattice-align-words $graphdir/phones/word_boundary.int $model ark:- ark:- \| lattice-to-ctm-conf  --flush=true  --decode-mbr=true --acoustic-scale=0.07 ark:- - \| \
    utils/int2sym.pl -f 5 $graphdir/words.txt \| bin/convertTer_ctm.pl $sdata/JOB/segments  \>$dirLat/resul.JOB.ctm  || exit 1

fi
