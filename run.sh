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
gpu=${2:-yes}
threads=${3:-8}

# Move to the dir containing this file
# Kaldi scripts are often expecting the path 
# to be relative
cd $DIR

# Source Kaldi paths
source path.sh

# Create output dir
output_dir="$DIR/output/"
wdir=$output_dir$show

mkdir -p $wdir &> /dev/null
mkdir -p $wdir/seg &> /dev/null
mkdir -p $wdir/decode &> /dev/null
mkdir -p $wdir/audio &> /dev/null

# Convert to wav, then to sphere format
avconv -i $audio -y -vn -acodec pcm_s16le -ac 1 $wdir/audio/$show.wav
sox $wdir/audio/$show.wav -r 16000 $wdir/audio/$show.sph

# Diarization (segmentation/classification)
./diarization/diarization.sh $wdir/audio/$show.wav $wdir/seg ./diarization/dist/LIUM_SpkDiarization-9.0.jar ./diarization/dist/phase1_asr ./diarization/dist/phase2_i-vector audio16kHz2sphinx

# Prepare files for the decode procss
cat $wdir/seg/$show.g.seg | ./bin/51meignier2ctm.perl | ./bin/03kaldi.perl $wdir/decode $wdir/audio/$show.sph $KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe 16000

# Start decoding
./bin/decode.sh $wdir/decode $gpu $threads

# If the ctm has been produced (everything is ok)
# sort it and convert it to utf-8

if [ -f "$wdir/decode/results/resul.1.ctm" ]
then
    sort -n -k3 $wdir/decode/results/resul.1.ctm | iconv -f iso-8859-1 -t utf8 > $wdir/$show.ctm
fi

