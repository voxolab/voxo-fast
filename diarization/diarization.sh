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
phase1=$4
phase2=$5
inputFormat=$6

wdir=$bdir
mkdir -p $wdir &> /dev/null

logfile=$wdir/seg.log

#Attention : sun java 1.6 ou +
javaMemory="-Xmx6G -Xms2G"
prog="java $javaMemory -cp $jar"
#opt="--logger=WARNING --help"
opt="--logger=CONFIG --help"

pms_gmm=$phase1/sms.gmms
silence_gmm=$phase1/s.gmms
gender_gmm=$phase1/gender.gmms

ubm_iv=$phase2/wld.gmm
efr_iv=$phase2/wld.efn.xml
cov_iv=$phase2/wld.mahanalobis.mat
tv_iv=$phase2/wld.tv.mat

prog_glpsol="glpsol"

echo "#####################################################"
echo "#   $show"
echo "#####################################################"

features=$wdir/%s.mfcc
fDescStart="$inputFormat,1:1:0:0:0:0,13,0:0:0"
fDesc="sphinx,1:1:0:0:0:0,13,0:0:0"
fDescFilter="sphinx,1:3:2:0:0:0,13,0:0:0:0"
fDescIV="sphinx,1:3:2:0:0:0,13,1:1:0:0"

thr_l=2
thr_h=3
thr_iv=100

#calcul les MFCC (wave --> mfcc)
$prog fr.lium.spkDiarization.tools.Wave2FeatureSet $opt --fInputMask=$audio --fInputDesc=$fDescStart --fOutputMask=$features --fOutputDesc=$fDesc --sInputMask="" --sOutputMask=$wdir/%s.uem.seg $show >>$logfile 2>&1

#verifier la qualité du MFCC, supprime des mfcc du fihier --sOutputMask
$prog fr.lium.spkDiarization.programs.MSegInit $opt --fInputMask=$features --fInputDesc=$fDesc --sInputMask=$wdir/%s.uem.seg --sOutputMask=$wdir/%s.i.seg  $show >>$logfile 2>&1


#GLR based segmentation, make small segments
$prog fr.lium.spkDiarization.programs.MSeg $opt --kind=FULL --sMethod=GLR  --help --fInputMask=$features --fInputDesc=$fDesc --sInputMask=$wdir/%s.i.seg --sOutputMask=$wdir/%s.s.seg $show >>$logfile 2>&1

#----------------
#Segmentation rapide
#$prog fr.lium.spkDiarization.programs.MSeg $opt --kind=DIAG --sMethod=GD  --help --fInputMask=$features --fInputDesc=$fDesc --sInputMask=$wdir/%s.i.seg --sOutputMask=$wdir/%s.s.seg $show

# linear clustering / 2e etape de segmentation
$prog fr.lium.spkDiarization.programs.MClust $opt --fInputMask=$features --fInputDesc=$fDesc --sInputMask=$wdir/%s.s.seg --sOutputMask=$wdir/%s.l.seg --cMethod=l --cThr=$thr_l $show >>$logfile 2>&1

#----------------
# hierarchical clustering
$prog fr.lium.spkDiarization.programs.MClust $opt --fInputMask=$features --fInputDesc=$fDesc --sInputMask=$wdir/%s.l.seg --sOutputMask=$wdir/%s.h.seg --cMethod=h --cThr=$thr_h $show >>$logfile 2>&1

#----------------
# re segmentation en 4 étapes
# initialize GMM
$prog fr.lium.spkDiarization.programs.MTrainInit $opt --nbComp=8 --kind=DIAG --fInputMask=$features --fInputDesc=$fDesc --sInputMask=$wdir/%s.h.seg --tOutputMask=$wdir/%s.init.gmms $show >>$logfile 2>&1
 
# EM computation of the GMM
$prog fr.lium.spkDiarization.programs.MTrainEM $opt --nbComp=8 --kind=DIAG --fInputMask=$features --fInputDesc=$fDesc --sInputMask=$wdir/%s.h.seg --tInputMask=$wdir/%s.init.gmms --tOutputMask=$wdir/%s.gmms $show >>$logfile 2>&1

#Viterbi decoding using GMM
$prog fr.lium.spkDiarization.programs.MDecode $opt --fInputMask=${features} --fInputDesc=$fDesc --sInputMask=$wdir/%s.h.seg --sOutputMask=$wdir/%s.d.seg --dPenality=250  --tInputMask=$wdir/%s.gmms $show >>$logfile 2>&1

# Adjust segment boundaries
$prog fr.lium.spkDiarization.tools.SAdjSeg $opt --fInputMask=$features --fInputDesc=$fDesc --sInputMask=$wdir/%s.d.seg --sOutputMask=$wdir/$show.adj.seg $show >>$logfile 2>&1

#----------------
#Speech/Music/Silence segmentation
$prog fr.lium.spkDiarization.programs.MDecode $opt --fInputDesc=$fDescFilter --fInputMask=$features --sInputMask=$wdir/%s.i.seg --sOutputMask=$wdir/%s.pms.seg --dPenality=10,10,50 --tInputMask=$pms_gmm $show >>$logfile 2>&1

#filter spk segmentation according pms segmentation
$prog fr.lium.spkDiarization.tools.SFilter $opt  --fInputDesc=$fDescFilter --fInputMask=$features --fltSegMinLenSpeech=150 --fltSegMinLenSil=25 --sFilterClusterName=j --fltSegPadding=25 --sFilterMask=$wdir/%s.pms.seg --sInputMask=$wdir/%s.adj.seg --sOutputMask=$wdir/%s.flt.seg $show >>$logfile 2>&1

#Split segment longer than 20s
$prog fr.lium.spkDiarization.tools.SSplitSeg $opt  --sFilterMask=$wdir/%s.pms.seg --sFilterClusterName=iS,iT,j --sInputMask=$wdir/%s.flt.seg --sOutputMask=$wdir/%s.spl.seg --fInputMask=$features --fInputDesc=$fDescFilter --tInputMask=$silence_gmm $show >>$logfile 2>&1

#-------------------------------------------------------------------------------
#Set gender and bandwith, %s.g.seg segmentation file for ASR
$prog fr.lium.spkDiarization.programs.MScore $opt --sGender --sByCluster --fInputDesc=$fDescIV --fInputMask=$features --sInputMask=$wdir/%s.spl.seg --sOutputMask=$wdir/%s.g.seg --tInputMask=$gender_gmm $show >>$logfile 2>&1

#I-vector speaker based clustering, for screen
$prog fr.lium.spkDiarization.programs.ivector.ILPClustering $opt --cMethod=es_iv --ilpThr=$thr_iv --sInputMask=$wdir/$show.g.seg --sOutputMask=$wdir/%s.iv.seg --fInputMask=$features --fInputDesc=$fDescIV --ilpGLPSolProgram=$prog_glpsol --tInputMask=$ubm_iv --nEFRMask=$efr_iv --nMahanalobisCovarianceMask=$cov_iv --tvTotalVariabilityMatrixMask=$tv_iv --ilpOutputProblemMask=$wdir/%s.ilp.problem.txt --ilpOutputSolutionMask=$wdir/%s.ilp.solution.txt $show >>$logfile 2>&1
