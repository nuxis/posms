#!/usr/bin/perl

use warnings;
use strict;

use Net::Telnet::Cisco;
use Net::Ping;


# This is default settings for Linksys SRW2024
my $defip = '192.168.1.254';
my $defmask = '255.255.255.0';
my $defgw = '192.168.1.1';


# This is per switch settings!
my %switch = (
	name => 'rad1',
	interface => 'gig 1/0/11',
	core => '10.20.4.3',
	defip => $defip,
	defmask => $defmask,
	defgw => $defgw,
	server => '10.20.4.11',
	);



sub prov
{
	my %switch = @_;

	print "\n";
	print "Pinging default gw...\n";
	my $ping = Net::Ping->new();
	if ($ping->ping ($defgw, 5))
	{
		print "$defgw is already responding!\n";
		return 0;
	}

	print "$defgw does not respond. Starting config...\n";
}



prov (%switch);
