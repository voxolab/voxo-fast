#!/bin/bash

# Nice snippet to get the current DIR
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

audio=$1
show=`basename $audio .wav`

bdir=$2
jar=$3
gmms=$4

wdir=$bdir/$show
mkdir -p $wdir &> /dev/null

logfile=$wdir/seg.log

#Attention : sun java 1.6 ou +
javaMemory="-Xmx6G -Xms2G"
prog="java $javaMemory -cp $jar"
#opt="--logger=WARNING --help"
opt="--logger=CONFIG --help"

echo "#####################################################"
echo "#   $show"
echo "#####################################################"

LOCALCLASSPATH=$jar

fDescD="audio8kHz2sphinx,1:3:2:0:0:0,13,1:1:300:2"

# linear clustering
ubm=$gmms
dseg=$wdir/%s.rs.seg
java -Xmx2048m -classpath "$LOCALCLASSPATH" fr.lium.experimental.spkDiarization.programs.EHMMv2 --help --typeEHMM=2Spk --tInputMask=$ubm --emInitMethod=copy --emCtrl=1,1,0.01 --varCtrl=0.01,10.0 --help --fInputMask=$audio --fInputDesc=$fDescD --sInputMask="" --sOutputMask=$dseg --mapCtrl=linear,0.9,0:1:0 --dPenality=50 --saveAllStep $show

cp $wdir/$show.rs.seg $bdir/$show.g.seg
cp $wdir/$show.rs.seg $bdir/$show.iv.seg
