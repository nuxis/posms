#!/usr/bin/perl

use warnings;
use strict;

use Net::Telnet::Cisco;
use Net::Ping;


# This is default settings for Linksys SRW2024
my $defip = '192.168.1.254';
my $defmask = '255.255.255.0';
my $defgw = '192.168.1.1';

# Party settings
my $tftpserver = '10.20.4.11';
my $iosuser = 'pms';
my $iospass = 'Polar11';


# This is per switch settings!
my %switch = (
	name => 'rad1',
	interface => 'gig 1/0/11',
	core => '10.20.4.3',
	defip => $defip,
	defmask => $defmask,
	defgw => $defgw,
	tftpserver => $tftpserver,
	iosuser => $iosuser,
	iospass => $iospass,
	);



sub prov
{
	my %switch = @_;
	print "\n";


	print "Pinging default gw...\n";
	my $ping = Net::Ping->new();
	if ($ping->ping ($switch{defgw}, 5))
	{
		print "$switch{defgw} is already responding!\n";
		return 0;
	}

	print "$switch{defgw} does not respond. Starting config...\n";


	print "Connecting to core $switch{core}\n";

	my $ios = Net::Telnet::Cisco->new (
		Host => $switch{core},
		Errmode => 'return',
		output_log => "output-core$switch{core}.log", 
		input_log => "input-core$switch{core}.log", 
		Prompt => '/\S+[#>]/',
		);
	
	if (!defined ($ios))
	{
		print "Could not connect to core $switch{core}\n";
		return 0;
	}

	print "Connected to core $switch{core}... Logging in.\n";
	
	$ios->login ($switch{iosuser}, $switch{iospass}) or die ("Login failed on core $switch{core}");

	$ios->enable;

	# Smart to check somewhere on the way...
	print $ios->errmsg;


	# This does it easier... Alfa
	$ios->cmd ("term length 0");

	print "Configuring $switch{core} $switch{interface}\n";

	$ios->cmd ("conf t");
	$ios->cmd ("default int $switch{interface}");
	$ios->cmd ("int $switch{interface}");
	$ios->cmd ("no shut");
	$ios->cmd ("description $switch{name} * config *");
	$ios->cmd ("no switchport");
	$ios->cmd ("ip address $switch{defgw} $switch{defmask}");
	$ios->cmd ("end");

	# Smart to check somewhere on the way...
	print $ios->errmsg;
}



prov (%switch);
