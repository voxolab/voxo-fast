#!/usr/bin/perl -w
use strict;
my $rep=$ARGV[0];
my $wavFile=$ARGV[1];
my $rate=sprintf("%.2f",$ARGV[2]);
open (CTL,"|sort >$ARGV[0]/segments") or die "pas ouvert CTL\n";
open (TRANS,"|sort >$ARGV[0]/text") or die "pas ouvert TRANS\n";
open (UTT,"|sort >$ARGV[0]/utt2spk") or die "pas ouvert UTT\n";
#open (UTT,"|sort -n -t\# -k3 >$ARGV[0]/utt2spk") or die "pas ouvert UTT\n";
open (SPK,"|sort >$ARGV[0]/spk2utt") or die "pas ouvert UTT\n";
open (WAV,"|sort >$ARGV[0]/wav.scp") or die "pas ouvert wav\n";
open (STM,"|sort >$ARGV[0]/pour.stm") or die "pas ouvert wav\n";
my  %longueur;
my %vuWav;
my %spk;
while (<STDIN>) {

    my @res = /\S+/g;
    next unless($res[0] ne ";;");

    if (! defined($longueur{$res[0]})) {
        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks)=stat($wavFile);
        print STDERR "[03kaldi.perl] $wavFile\n" unless (defined ($dev));
        #next  unless (defined ($dev));

#	print STDERR "$dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,$blksize,$blocks\n" if (defined($dev));
        $longueur{$res[0]}=sprintf("%.2f",((($size -1024)/2) -320)/$rate);
        print STDERR "[03kaldi.perl] Treating show '$res[0]', detected time $longueur{$res[0]}\n";
    }
    my $tailleMax=$longueur{$res[0]};
    $res[3] =($res[3]>$tailleMax) ? $tailleMax : $res[3];
    my $debut =  $res[2]*100;
    my $fin =    $res[3]*100-1;
#    next if ($fin-$debut >10000 );
    $debut = ($debut <0) ? 0: $debut;


    printf CTL "%s#%s#%s:%s#  %s %s %s\n",$res[0],$res[4],$res[2],$res[3] ,$res[0],$res[2],$res[3]; 
    printf TRANS "%s#%s#%s:%s#  %s\n", $res[0],$res[4],$res[2],$res[3],join(' ',@res[5..$#res]);
    printf UTT  "%s#%s#%s:%s#  %s#%s\n",$res[0],$res[4],$res[2],$res[3], $res[0],$res[4];
    printf STM "%s 1 %s %s %s\n",$res[0],$res[2],$res[3],$res[4];
    my $utt=sprintf  "%s#%s#%s:%s#" ,$res[0],$res[4],$res[2],$res[3];
    my $spk=sprintf "%s#%s",$res[0],$res[4];
    push @{$spk{$spk}},$utt;
    printf WAV "%s $wavFile\n",$res[0] unless (defined($vuWav{$res[0]}));
    $vuWav{$res[0]}=1;
}
foreach my $spk (sort keys %spk) {
    my @val=@{$spk{$spk}};
    print SPK join(' ',$spk,@val),"\n";
}
close(SPK);
close(CTL);
close(TRANS);
close(UTT)
