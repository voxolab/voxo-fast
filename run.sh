#!/bin/bash
export LC_ALL=C

audio=$1
show=`basename $audio .wav`
wdir=$show

mkdir -p $wdir &> /dev/null

avconv -i $audio -y -vn -acodec pcm_s16le -ac 1 $wdir/$show.wav

sox $wdir/$show.wav -r 16000 $wdir/$show.sph

./diarization/diarization.sh $wdir/$show.wav . ./diarization/dist/LIUM_SpkDiarization-9.0.jar ./diarization/dist/phase1_asr ./diarization/dist/phase2_i-vector audio16kHz2sphinx

cat $wdir/$show.g.seg | ./bin/51meignier2ctm.perl | ./bin/03kaldi.perl $show $show/$show.sph /home/vjousse/asr/src/kaldi/tools/sph2pipe_v2.5/sph2pipe 16000
#cat $show.g.seg | ./51meignier2ctm.perl | ./03kaldi.perl $show $show/$show.sph /home/demo/fast/Kaldi-5039/tools/sph2pipe_v2.5/sph2pipe 16000
./decode.sh $show
