#!/bin/bash
export LC_ALL=C

# Nice snippet to get the current DIR
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Get File infos
audio=`readlink -e $1`
filename=$(basename "$audio")
extension="${filename##*.}"
show="${filename%.*}"

# Get param values or default values
output_dir=${2:-$DIR/output/}
gpu=${3:-yes}
threads=${4:-8}
lm=${5:-3g}
graph=${6:-graph}
model=${7:-model}
diarization=${8:-diarization.sh}

# Move to the dir containing this file
# Kaldi scripts are often expecting the path 
# to be relative
cd $DIR

# Source Kaldi paths
source path.sh

# Create output dir
wdir=$output_dir$show

mkdir -p $wdir &> /dev/null
mkdir -p $wdir/seg &> /dev/null
mkdir -p $wdir/decode &> /dev/null
mkdir -p $wdir/audio &> /dev/null

# Convert to wav, then to sphere format
# Ubuntu 14 has avconv instead of ffmpeg...
if hash avconv 2>/dev/null; then
  conv_bin=avconv
else
  conv_bin=ffmpeg
fi

if [ ! -f $audio ]; then
    echo "File $audio not found!"
    exit -1
fi

#$conv_bin -i $audio -y -vn -acodec pcm_s16le -ac 1 $wdir/audio/$show.wav

# Don't convert, it should already be done
cp $audio $wdir/audio/$show.wav

if [ ! -f $wdir/audio/$show.wav ]; then
    echo "File $wdir/audio/$show.wav not found!"
    exit -1
fi
sox $wdir/audio/$show.wav -r 8000 $wdir/audio/$show.sph

# Diarization (segmentation/classification)
./diarization/$diarization $wdir/audio/$show.wav $wdir/seg ./diarization/dist/LIUM_SpkDiarization-9.0.jar ./diarization/dist/phase1_asr ./diarization/dist/phase2_i-vector audio8kHz2sphinx

# Prepare files for the decode procss
cat $wdir/seg/$show.g.seg | ./bin/51meignier2ctm.perl | ./bin/03kaldi.perl $wdir/decode $wdir/audio/$show.sph $KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe 8000

# Start decoding
./bin/decode_phone.sh $wdir/decode $gpu $threads $lm $graph $model $models

# If the ctm has been produced (everything is ok)
# sort it and convert it to utf-8

if [ -f "$wdir/decode/results/resul.1.ctm" ]
then
    encoding=`file -bi $wdir/decode/results/resul.1.ctm`
    if [[ $encoding == *"8859"* ]]
    then
        sort -n -k3 $wdir/decode/results/resul.1.ctm | iconv -f iso-8859-1 -t utf8 > $wdir/$show.ctm
    else
        sort -n -k3 $wdir/decode/results/resul.1.ctm > $wdir/$show.ctm
    fi
fi
