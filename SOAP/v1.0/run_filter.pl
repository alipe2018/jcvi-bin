#! /usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);


die "Version: 1.2\nData: 2010-02-03\nUsage:$0 <lane.lst> <lib.lst> [maxjob, default 10]\n" if @ARGV<2;

my $lane_lst = shift;
my $lib_lst = shift;
my $Maxjob = shift;

$Maxjob ||= 10;

my $file_name = `basename $lane_lst`;
chomp $file_name;


my %Lib;
my $vf="";
open IN,$lib_lst or die "$!";
while(<IN>){
	if (/^(\S+)\s+(\d+)/){
		$Lib{$1}=$2;
		mkdir($1) unless (-d $1);
	}else{
		next;
	}
}
close IN;

open OUT1, ">$file_name.filter.sh" or die "$!";
open OUT2, ">$file_name.dup.sh" or die "$!";
open OUT3, ">$file_name.stat.sh" or die "$!";

if ( -e "$file_name.stat.xls" ){
	my $tag = time;
	print STDERR "$file_name.stat.xls  already exists! \n";
	print STDERR "mv  $file_name.stat.xls $file_name.stat.xls.$tag \n";
	`mv  $file_name.stat.xls $file_name.stat.xls.$tag`;
}

open IN,$lane_lst or die "$!";

my $stat_output = '';
my $num = 0;
while(<IN>){
	next if !/_1\.fq/;
	chomp;
	$num++;
	
	my ($f1,$start1,$end1,$B_cutoff) = split(/\s+/);
	$start1 ||= 0;
	$end1 ||= 0;
	$B_cutoff ||= 40;
	
	my $line2 = <IN>;
	chomp $line2;
	my ($f2,$start2,$end2,$N_num) = split(/\s+/,$line2);
	$start2 ||= 0;
	$end2 ||= 0;
	#$N_num ||= 10;
	if(not defined $N_num or $N_num eq "")
	{$N_num ||= 10;}
	
	my $name = `basename $f1`;
	chomp $name;
	my $name2 = `basename $f2`;
	chomp $name2;
	my $lib;
	if ( $name =~/L\d+_([^_]+)_1\.fq/ ){
		$lib = $1;
	}else{
		die;
	}
	next if not exists $Lib{$lib};
	print OUT1 "$Bin/filter_data_gz -y -z -w $N_num -B $B_cutoff -l $Lib{$lib} -a $start1 -b $end1 -c $start2 -d $end2 $f1 $f2 ./$lib/$name.reads.stat ./$lib/$name.clean.tmp  ./$lib/$name2.clean.tmp && mv ./$lib/$name.clean.tmp ./$lib/$name.clean && mv ./$lib/$name2.clean.tmp ./$lib/$name2.clean && echo OK \n" ;
	print OUT2 "$Bin/duplication ./$lib/$name.clean ./$lib/$name2.clean ./$lib/$name.clean.dup.clean ./$lib/$name2.clean.dup.clean ./$lib/$name.clean.dup.stat && rm ./$lib/$name.clean ./$lib/$name2.clean && echo OK \n";
	#print OUT2 "$Bin/duplication ./$lib/$name.clean ./$lib/$name2.clean ./$lib/$name.clean.dup.clean ./$lib/$name2.clean.dup.clean ./$lib/$name.clean.dup.stat && rm ./$lib/$name.clean ./$lib/$name2.clean && echo OK \n";
	my $parameter="$start1"."_"."$end1"."_"."$start2"."_"."$end2"."_"."$B_cutoff"."_"."$N_num";
	print OUT3 "$Bin/stat.pl $lib_lst ./$lib/$name.reads.stat ./$lib/$name.clean.dup.stat $parameter >>$file_name.stat.xls \n";
	if($Lib{$lib}<1000){$vf="7G";}
	else{$vf="5G";}

}
close IN;
close OUT1;
close OUT2;
close OUT3;

print STDERR "Runing low quality filtering ... \n";
#`perl $Bin/qsub-sge.pl -maxjob $Maxjob -resource vf=300M -reqsub $file_name.filter.sh`;
`sh $file_name.filter.sh`;
print STDERR "Finished. \n";
print STDERR "Runing duplicate filtering ... \n";
#`perl $Bin/qsub-sge.pl -maxjob $Maxjob -resource vf=$vf -reqsub $file_name.dup.sh`;
`sh $file_name.dup.sh`;
print STDERR "Finished. \n";
print STDERR "Runing stat. ... \n";
`sh $file_name.stat.sh`;
print STDERR "All finished. \n";

