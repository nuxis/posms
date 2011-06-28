#!/usr/bin/perl

use warnings;
use strict;

use Net::Telnet::Cisco;
use Net::Ping;


# This is default settings for Linksys SRW2024
my $defip = '192.168.1.254';
my $defmask = '255.255.255.0';
my $defgw = '192.168.1.1';
my $defuser = 'admin';
my $defpass = '';

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
	defuser => $defuser,
	defpass => $defpass,
	mgmtvlan => '100',
	realvlan => '101',
	realgw => '10.20.101.1',
	realmask => '255.255.255.0',
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
		output_log => "out-core$switch{core}.log", 
		input_log => "in-core$switch{core}.log", 
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


	# Closing the connection for now.
	$ios->close;


	# Here starts the interesting part... Thanks to the TG Tech:Server-crew for doing this before me.
	# We have to telnet to the gw to telnet to the (probably) linksys switch as it lacks a default route per now.
	# Some copy and pasting from the $ios-part above here... Could probably made a function of it but what the heck.

	tsleep (10);

	my $new = Net::Telnet::Cisco->new (
		Host => $switch{core},
		Errmode => 'return',
		output_log => "out-core$switch{core}.log", 
		input_log => "in-core$switch{core}.log", 
		Prompt => '/\S+[#>]/',
		);
	
	if (!defined ($new))
	{
		print "Could not connect to core $switch{core}\n";
		return 0;
	}

	print "Connected to core $switch{core}... Logging in.\n";
	
	$new->login ($switch{iosuser}, $switch{iospass}) or die ("Login failed on core $switch{core}");

	$new->enable;

	# Smart to check somewhere on the way...
	print $new->errmsg;

	print "Telnet'ing to switch $switch{defip}...\n";


	# cmd() waits for return... seems print() is a better option.
	#$new->cmd ("telnet $switch{defip} /source-interface $switch{interface}");
	$new->print ("telnet $switch{defip}");


	# Okay... now we got a connection to the switch...
	# The linksys telnet interface is a menu(!), but we can exit that after logging in.

	print "Waiting for login prompt\n";
	$new->waitfor ('/Password:/');

	print "Entering username\n";
	$new->print ("$switch{defuser}");

	# Default for new linksys firmware is to login after admin\n
	#$new->print ("$switch{defpass}\n");

	$new->print ("\cZ");

	print "Waiting for basic cli...\n";
	$new->waitfor ("/\>/");
	print "Got to the cli... Now start 'lcli'!\n";
	$new->print ("lcli\n");
	print "Waiting for username-prompt...\n";
	$new->waitfor ("/User Name\:/");
	print "Enter username $switch{defuser}\n";
	$new->print ("admin");


	print "Waiting for switch prompt\n";
	$new->waitfor('/#/');
	print "Got switch prompt...\n";


	print "Setting default gateway..\n";
	$new->cmd ("conf");
	$new->cmd ("interface vlan 1");
	$new->cmd ("ip address 192.168.1.254 255.255.255.0");
	$new->cmd ("ip default-gateway 192.168.1.1");
	$new->cmd ("exit");
	$new->print ("exit");

	print "Copying config for $switch{name} from $switch{tftpserver}...\n";
	$new->print ("copy tftp://$switch{tftpserver}/base/$switch{name}.conf startup-config\n\n");

#	print $new->last_prompt;

#	$new->waitfor ('/hh:mm:ss/');

	tsleep (10);
	$new->cmd ("\n");
	print "Reloading $switch{name}...\n";
	$new->cmd ("reload");
	$new->cmd ("reload");
	$new->cmd ("reload");
	sleep 1;
	print "Replying 'y'..\n";
	$new->cmd ("y");


	$new->errmsg;
	$new->close ();

	print "Connecting to core $switch{core}\n";

	undef $ios;
	$ios = Net::Telnet::Cisco->new (
		Host => $switch{core},
		Errmode => 'return',
		output_log => "out-core$switch{core}.log", 
		input_log => "in-core$switch{core}.log", 
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
	$ios->cmd ("description $switch{name}");
	$ios->cmd ("switchport trunk encap dot1q");
	$ios->cmd ("switchport mode trunk");
	$ios->cmd ("switchport trunk allowed vlan $switch{realvlan},$switch{mgmtvlan}");
	$ios->cmd ("exit");
	$ios->cmd ("vlan $switch{realvlan}");
	$ios->cmd ("exit");
	$ios->cmd ("no int vlan $switch{realvlan}");
	$ios->cmd ("int vlan $switch{realvlan}");
	$ios->cmd ("ip address $switch{realgw} $switch{realmask}");
	$ios->cmd ("exit");


## FIXME: more config here!

	$ios->cmd ("end");
	$ios->cmd ("wr");

	# Smart to check somewhere on the way...
	print $ios->errmsg;


	# Closing the connection for now.
	$ios->close;

}

sub tsleep
{
	my ($time) = @_;
	while ($time)
	{
		print "$time...\n";
		sleep (1);
		$time--;
	}
}


prov (%switch);
