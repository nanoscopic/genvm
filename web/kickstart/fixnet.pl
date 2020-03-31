#!/usr/bin/perl -w
use strict;

my @netlines = `ip -o link`;

my $npFile = "/etc/netplan/vbox.yaml";
open( my $npFh, ">$npFile" ) or die "Cannot write to $npFile";

print $npFh "network:\n  version: 2\n  renderer: networkd\n  ethernets:\n";

for my $netline ( @netlines ) {
	if( $netline =~ m/(enp[0-9a-z]+)/ ) {
		my $interface = $1;
		print STDERR "Adding interface $interface to netplan\n";
		print $npFh "    $interface:\n";
		print $npFh "      dhcp4: yes\n";
	}
}

close $npFh;
`netplan apply`;
exit 0;
