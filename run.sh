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

audio=`readlink -e $1`
filename=$(basename "$audio")
extension="${filename##*.}"
show="${filename%.*}"

cd $DIR

source path.sh
output_dir="$DIR/output/"
wdir=$output_dir$show

mkdir -p $wdir &> /dev/null
mkdir -p $wdir/seg &> /dev/null
mkdir -p $wdir/decode &> /dev/null
mkdir -p $wdir/audio &> /dev/null

avconv -i $audio -y -vn -acodec pcm_s16le -ac 1 $wdir/audio/$show.wav

sox $wdir/audio/$show.wav -r 16000 $wdir/audio/$show.sph

./diarization/diarization.sh $wdir/audio/$show.wav $wdir/seg ./diarization/dist/LIUM_SpkDiarization-9.0.jar ./diarization/dist/phase1_asr ./diarization/dist/phase2_i-vector audio16kHz2sphinx

cat $wdir/seg/$show.g.seg | ./bin/51meignier2ctm.perl | ./bin/03kaldi.perl $wdir/decode $wdir/audio/$show.sph $KALDI_ROOT/tools/sph2pipe_v2.5/sph2pipe 16000
./decode.sh $wdir/decode
if [ -f "$wdir/decode/results/resul.1.ctm" ]
then
    sort -n -k3 $wdir/decode/results/resul.1.ctm | iconv -f iso-8859-1 -t utf8 > $wdir/$show.ctm
fi

