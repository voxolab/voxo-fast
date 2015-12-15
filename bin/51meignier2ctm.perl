#!/usr/bin/perl -w
use strict;
my $text="S F0 T F2";
my %dico= split(" ",$text);

while (<>) {
    next if (/^;;/);
    chomp;
    my (@res,$locu,$debut,$fin,$type);
    @res= split /\s+/;
#    ($locu) = $res[7]=~ /S(\d+)_/;
    $locu=$res[7];
    $debut = sprintf "%.2f",$res[2]/100;
    $fin = sprintf "%.2f", ($res[3]+$res[2])/100;
   $type = $dico{$res[5]};
print join(" ",@res[0..1],$debut,$fin,join("_",$type,join("-",$res[4],$locu))),"\n";
}
