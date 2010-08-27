#!/usr/bin/perl

use strict;
use Getopt::Long;
use Device::USB;

my %opts;
if (!&GetOptions(\%opts,
	'verbose',
	'action=s',
	'params=s',
   ) || (!$opts{action})) {
	die <<USAGE;
usage: $0 -action ACTION [-params PARAMS] [-verbose]

Valid actions:
     setstate      sets state buffer in device
     getstate      gets state buffer from device
     setbuffer     sets contents of display buffer
     getbuffer     gets current contents of display buffer
     settime       sets time buffer in device
     gettime       gets time buffer from device

     set actions require -params PARAMS.

Optional arguments:
     verbose       print useful debugging information to console
     vendor        override vendor ID string when searching for device
     product       override product ID string when searching for device
USAGE
}

if ($opts{verbose}) {
	open VERBOSE, ">&", \*STDOUT or die "FATAL: Can't dupe STDOUT for debugging: $!\n";
} else {
	open VERBOSE, ">/dev/null";
}

my $VENDOR = 0x16c0;
my $PRODUCT = 0x05dc;

my $usb = Device::USB->new();
my $dev = $usb->find_device( $VENDOR, $PRODUCT );

my $CUSTOM_RQ_SET_STATE 	= 1;
my $CUSTOM_RQ_GET_STATE 	= 2;
my $CUSTOM_RQ_SET_BUFFER 	= 3;
my $CUSTOM_RQ_GET_BUFFER	= 4;
my $CUSTOM_RQ_SET_HOURS 	= 5;
my $CUSTOM_RQ_GET_HOURS 	= 6;
my $CUSTOM_RQ_SET_MINS 		= 7;
my $CUSTOM_RQ_GET_MINS 		= 8;
my $CUSTOM_RQ_SET_SECS 		= 9;
my $CUSTOM_RQ_GET_SECS 		= 10;

printf VERBOSE "Device: %04X:%04X\n", $dev->idVendor(), $dev->idProduct();

$dev->open();

print VERBOSE "Manufacturer:   ", $dev->manufacturer(), "\n",
              "Product string: ", $dev->product(), "\n";

$dev->detach_kernel_driver_np( 0 );
$dev->set_configuration( 1 );
$dev->claim_interface( 0 );

#64 sends, #192 receives
# request type, request, value, index, *bytes, size, timeout

if ($opts{action} eq 'setstate') {
	die "Need to specify parameters for setstate!" unless $opts{params};
	setState($opts{params});
	print STDOUT "Set state to:   ".$opts{params}."\n";
	print STDOUT "Current state:  ".getState()."\n";
}

if ($opts{action} eq 'setbuffer') {
	die "Need to specify parameters for setstate!" unless $opts{params};
	setBuffer($opts{params});
	print STDOUT "Set buffer to:  ".$opts{params}."\n";
	print STDOUT "Current buffer: ".getBuffer(),"\n";
}

if ($opts{action} eq 'settime') {
	die "Need to specify parameters for settime!" unless $opts{params};
	setTime($opts{params});
	print STDOUT "Set time to:    ".$opts{params}."\n";
	print STDOUT "Current time:   ".getTime()."\n";
}

if ($opts{action} eq 'getstate') {
	print STDOUT "Current state:  ".getState()."\n";
}

if ($opts{action} eq 'getbuffer') {
	print STDOUT "Current buffer: ".getBuffer()."\n";
}

sub setBuffer {
	my $buffer = shift;
	$buffer = substr $buffer, 0, 4;		# chop buffer to 4 chars
	$buffer =~ tr/a-z/A-Z/;			# convert to uppercase
	$dev->control_msg( 64, $CUSTOM_RQ_SET_BUFFER, 0, 0, $buffer, 4, 5000 );
	print VERBOSE "Set display buffer to: $buffer\n";
}

sub getBuffer {
	$dev->control_msg( 192, $CUSTOM_RQ_GET_BUFFER, 0, 0, my $buffer = "\0", 8, 5000 );
	print VERBOSE "Contents of display buffer: ".$buffer."\n";

	return $buffer;
}

sub setState {
	my $state = shift;

	$dev->control_msg( 64, $CUSTOM_RQ_SET_STATE, ord($state), 0, my $buffer = "\0", 0, 5000 );
	print VERBOSE "Set hours variable to: $state\n";
}

sub getState {
	$dev->control_msg( 192, $CUSTOM_RQ_GET_STATE, 0, 0, my $buffer = "\0", 1, 5000 );
	print VERBOSE "Contents of state variable: $buffer\n";

	return $buffer;
}

sub setTime {
	my $timeArg = shift;

	if ($timeArg eq 'now') {
		my @timeData = localtime(time);
		$timeArg = $timeData[2].":".$timeData[1].":".$timeData[0];
	}

	my @hms = split /:/, $timeArg;

	setHours($hms[0]);
	setMins($hms[1]);
	setSecs($hms[2]);
}

sub getTime {
	my $hours = getHours();
	my $mins = getMins();
	my $secs = getSecs();

	return sprintf("%02d:%02d:%02d", $hours, $mins, $secs);
}

sub setHours {
	my $hours = shift;

	$dev->control_msg( 64, $CUSTOM_RQ_SET_HOURS, $hours, 0, my $buffer = "\0", 0, 5000 );
	print VERBOSE "Set hours variable to: $hours\n";
}

sub setMins {
	my $mins = shift;

	$dev->control_msg( 64, $CUSTOM_RQ_SET_MINS, $mins, 0, my $buffer = "\0", 0, 5000 );
	print VERBOSE "Set mins variable to: $mins\n";
}

sub setSecs {
	my $secs = shift;

	$dev->control_msg( 64, $CUSTOM_RQ_SET_SECS, $secs, 0, my $buffer = "\0", 0, 5000 );
	print VERBOSE "Set secs variable to: $secs\n";
}

sub getHours {
	$dev->control_msg( 192, $CUSTOM_RQ_GET_HOURS, 0, 0, my $buffer = "\0", 1, 5000 );
	print VERBOSE "Contents of hours variable: $buffer\n";

	return ord($buffer);
}

sub getMins {
	$dev->control_msg( 192, $CUSTOM_RQ_GET_MINS, 0, 0, my $buffer = "\0", 1, 5000 );
	print VERBOSE "Contents of minutes variable: $buffer\n";

	return ord($buffer);
}

sub getSecs {
	$dev->control_msg( 192, $CUSTOM_RQ_GET_SECS, 0, 0, my $buffer = "\0", 1, 5000 );
	print VERBOSE "Contents of seconds variable: $buffer\n";

	return ord($buffer);
}
0;
