#!/usr/bin/perl -w
use strict;

my $folder = "/root/runonce/scripts";
my $donef = "/root/runonce/done";
if( ! -e $donef ) {
	mkdir $donef;
}
my $outputf = "/root/runonce/output";
if( ! -e $outputf ) {
	mkdir $outputf;
}

opendir( my $dh, $folder );
my @files = readdir( $dh );
closedir( $dh );

for my $file ( @files ) {
	next if( $file =~ m/^\.+$/ );
	my $full = "$folder/$file";
	my $done = "$donef/$file";
	my $output = "$outputf/$file";
	my $output2 = "$outputf/$file-error";
	if( -e $done ) {
		unlink $done;
	}
	chmod "0700", $full;
	`$full > $output 2> $output2`;
	rename $full, $done;
}