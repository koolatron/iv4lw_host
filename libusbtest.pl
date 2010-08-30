#!/usr/bin/perl

use strict;
use Getopt::Long;
use Device::USB;
use Time::HiRes qw(gettimeofday);

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

     set actions require -params PARAMS.  PARAMS may be "now" for settime (sets clock from system time)

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
my $CUSTOM_RQ_SET_TIME		= 11;
my $CUSTOM_RQ_GET_TIME		= 12;

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
	print STDOUT "Setting state to:     ".$opts{params}."\n";
	setState($opts{params});
	print STDOUT "Read current state:   ".getState()."\n";
}

if ($opts{action} eq 'setbuffer') {
	die "Need to specify parameters for setstate!" unless $opts{params};
	print STDOUT "Setting buffer to:   ".$opts{params}."\n";
	setBuffer($opts{params});
	print STDOUT "Read current buffer: ".getBuffer(),"\n";
}

if ($opts{action} eq 'settime') {
	die "Need to specify parameters for settime!" unless $opts{params};
	print STDOUT "Read current time:   ".getTime()."\n";
	print STDOUT "Setting time to:     ".$opts{params}."\n";
	setTime($opts{params});
	print STDOUT "Read current time:   ".getTime()."\n";
}

if ($opts{action} eq 'getstate') {
	print STDOUT "Read current state:  ".getState()."\n";
}

if ($opts{action} eq 'getbuffer') {
	print STDOUT "Read current buffer: ".getBuffer()."\n";
}

if ($opts{action} eq 'gettime') {
	print STDOUT "Read current time:   ".getTime()."\n";
}

sub setBuffer {
	my $buffer = shift;
	$buffer = substr $buffer, 0, 4;		# chop buffer to 4 chars
	$buffer =~ tr/a-z/A-Z/;			# convert to uppercase
	my $ret = $dev->control_msg( 64, $CUSTOM_RQ_SET_BUFFER, 0, 0, $buffer, 4, 5000 );
	print VERBOSE "setBuffer: returned $ret\n";
}

sub getBuffer {
	my $ret = $dev->control_msg( 192, $CUSTOM_RQ_GET_BUFFER, 0, 0, my $buffer = "\0", 8, 5000 );
	print VERBOSE "getBuffer: returned $ret\n";

	return $buffer;
}

sub setState {
	my $state = shift;

	my $ret = $dev->control_msg( 64, $CUSTOM_RQ_SET_STATE, ord($state), 0, my $buffer = "\0", 0, 5000 );
	print VERBOSE "setState: returned $ret\n";
}

sub getState {
	my $ret = $dev->control_msg( 192, $CUSTOM_RQ_GET_STATE, 0, 0, my $buffer = "\0", 1, 5000 );
	print VERBOSE "getState: returned $ret\n";

	return $buffer;
}

sub setTime {
	my $timeArg = shift;

	if ($timeArg eq 'now') {
		my @timeData = localtime(time);
		my @hiResTimeData = gettimeofday();
		my $ticks = (($hiResTimeData[1] - ($hiResTimeData[1] % 4000)) / 4000);  # convert uS to ticks
		$timeArg = $timeData[2].":".$timeData[1].":".$timeData[0].":".$ticks;
	}

	my @hms = split /:/, $timeArg;

	unless ($hms[3]) { $hms[3] = 0; }
	unless ($hms[2]) { $hms[2] = 0; }	# make seconds and ticks optional

	my $buffer = pack ("CCCC", $hms[3], $hms[2], $hms[1], $hms[0]);

	my $ret = $dev->control_msg( 64, $CUSTOM_RQ_SET_TIME, 0, 0, $buffer, 4, 5000 );
	print VERBOSE "setTime: returned $ret\n";
}

sub getTime {
	my $ret = $dev->control_msg( 192, $CUSTOM_RQ_GET_TIME, 0, 0, my $buffer = "\0", 4, 5000 );

	my @hms = unpack ("CCCC", $buffer);

	return sprintf ("%02d:%02d:%02d:%03d", $hms[3], $hms[2], $hms[1], $hms[0]);
}

0;
