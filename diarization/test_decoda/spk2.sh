#!/bin/bash
#for audio in data/*.wav; do
audio="data/160610-083041-25037875.wav"
show=`basename $audio .wav`
datadir=spk2_out

mkdir $datadir

LOCALCLASSPATH=./bin/LIUM_SpkDiarization-9.0.jar

fDescD="audio8kHz2sphinx,1:3:2:0:0:0,13,1:1:300:2"

# linear clustering
ubm=./gmm/train.32.gmms
dseg=./$datadir/%s.rs.seg
java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.experimental.spkDiarization.programs.EHMMv2 --help --typeEHMM=2Spk --tInputMask=$ubm --emInitMethod=copy --emCtrl=1,1,0.01 --varCtrl=0.01,10.0 --help --fInputMask=$audio --fInputDesc=$fDescD --sInputMask="" --sOutputMask=$dseg --mapCtrl=linear,0.9,0:1:0 --dPenality=50 --saveAllStep $show

#done
