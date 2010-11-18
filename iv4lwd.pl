#!/usr/bin/perl

use strict;
use Getopt::Long;
use Device::USB;
use Time::HiRes qw(gettimeofday);
use Time::HiRes qw(usleep);
use Sys::Syslog;
use POSIX qw(setsid);

my %opts;
if (!&GetOptions(\%opts,
    'daemonize',
    'run',
   ) || (!$opts{run})) {
    exit(1);
}

$SIG{TERM} =\&sigterm;

my $VENDOR = 0x16c0;
my $PRODUCT = 0x05dc;

my $CUSTOM_RQ_SET_STATE     = 1;
my $CUSTOM_RQ_GET_STATE     = 2;
my $CUSTOM_RQ_SET_BUFFER    = 3;
my $CUSTOM_RQ_GET_BUFFER    = 4;
my $CUSTOM_RQ_SET_TIME      = 11;
my $CUSTOM_RQ_GET_TIME      = 12;

my $dev;

if ($opts{daemonize}) {
    &daemonize;
}

init();
main();
cleanUp();

exit(0);


sub setBuffer {
    my $buffer = shift;
    $buffer = substr $buffer, 0, 4;     # chop buffer to 4 chars
    $buffer =~ tr/a-z/A-Z/;         # convert to uppercase
    my $ret = $dev->control_msg( 64, $CUSTOM_RQ_SET_BUFFER, 0, 0, $buffer, 4, 5000 );
    syslog("debug", "setBuffer: returned $ret");
}

sub getBuffer {
    my $ret = $dev->control_msg( 192, $CUSTOM_RQ_GET_BUFFER, 0, 0, my $buffer = "\0", 8, 5000 );
    syslog("debug", "getBuffer: returned $ret");

    return $buffer;
}

sub setState {
    my $state = shift;

    my $ret = $dev->control_msg( 64, $CUSTOM_RQ_SET_STATE, ord($state), 0, my $buffer = "\0", 0, 5000 );
    syslog("debug", "setState: returned $ret");
}

sub getState {
    my $ret = $dev->control_msg( 192, $CUSTOM_RQ_GET_STATE, 0, 0, my $buffer = "\0", 1, 5000 );
    syslog("debug", "getState: returned $ret");

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
    unless ($hms[2]) { $hms[2] = 0; }   # make seconds and ticks optional

    my $buffer = pack ("CCCC", $hms[3], $hms[2], $hms[1], $hms[0]);

    my $ret = $dev->control_msg( 64, $CUSTOM_RQ_SET_TIME, 0, 0, $buffer, 4, 5000 );
    syslog("debug", "setTime: returned $ret");
}

sub getTime {
    my $ret = $dev->control_msg( 192, $CUSTOM_RQ_GET_TIME, 0, 0, my $buffer = "\0", 4, 5000 );

    my @hms = unpack ("CCCC", $buffer);

    return sprintf ("%02d:%02d:%02d:%03d", $hms[3], $hms[2], $hms[1], $hms[0]);
}

sub scrollString {
    my $message = "     ".shift;
    
    # convert to uppercase
    $message =~ tr/a-z/A-Z/;
    $message =~ tr/ /\//;
    
    # stick it in an array for easy manipulation
    my @message = split //, $message;

    my $index = 0;
    my $done = 0;

    # get the current state
    my $initialState = getState();

    # set state to U so we see changes
    setState("U");

    while ($done != 1) {
        my $substring;

        my $a = ++$index;
        my $b = $index+1;
        my $c = $index+2;
        my $d = $index+3;
        
        if ($a > $#message) {
            $a = "/";
            $done = 1;
        } else {
            $a = $message[$a];
        }

        if ($b > $#message) {
            $b = "/";
        } else {
            $b = $message[$b];
        }
 
        if ($c > $#message) {
            $c = "/";
        } else {
            $c = $message[$c];
        }

        if ($d > $#message) {
            $d = "/";
        } else {
            $d = $message[$d];
        } 

        my $substring = $a.$b.$c.$d;

        setBuffer($substring);

        usleep(200000);
    }

    setState($initialState);
}

sub randword {
    my $nwords = shift;

    my @allwords = `cat /usr/share/dict/words | egrep '^.{4}\$'`;

    my $initialState = getState();

    setState('U');

    while ($nwords-- > 0) {
        my $thisword = $allwords[int(rand($#allwords))];
        chomp $thisword;

        setBuffer($thisword);
        
        sleep(1);
    }

    setState($initialState);
}


sub walk {
    my $nwords = shift;

    my @allwords = `cat /usr/share/dict/words | egrep '^.{4}\$'`;
    
    my $initialState = getState();

    # choose an intial random word in @allwords
    my $thisword = $allwords[int(rand($#allwords))];
    chomp $thisword;
 
    for ($nwords; $nwords > 0; $nwords--) {

        # iterate
        my @thiswordarray = split //, $thisword;

        my @nextwords;

        # which letter?
        my $letter = int(rand(3));

        if ($letter == 0) {
            @nextwords = `cat /usr/share/dict/words | egrep -i '^.$thiswordarray[1]$thiswordarray[2]$thiswordarray[3]\$'`;
        }
        if ($letter == 1) {
            @nextwords = `cat /usr/share/dict/words | egrep -i '^$thiswordarray[0].$thiswordarray[2]$thiswordarray[3]\$'`;
        }
        if ($letter == 2) {
            @nextwords = `cat /usr/share/dict/words | egrep -i '^$thiswordarray[0]$thiswordarray[1].$thiswordarray[3]\$'`;
        }
        if ($letter == 3) {
            @nextwords = `cat /usr/share/dict/words | egrep -i '^$thiswordarray[0]$thiswordarray[1]$thiswordarray[2].\$'`;
        }

        my $nextword = $nextwords[int(rand($#nextwords))];

        if ($thisword =~ /$nextword/i) {
            $thisword = $allwords[int(rand($#allwords))];
            $nwords++;
            next;
        }

        $thisword = $nextword;

        $thisword =~ tr/[a-z]/[A-Z]/;

        setState('U');
        setBuffer($thisword);
    
        sleep(1);
    }

    setState($initialState);
}
    
sub init {
    openlog($0, "pid", "local0");
    syslog("info", "iv4lwd starting...");

    syslog("info", "Scanning bus for $VENDOR:$PRODUCT");
    my $usb = Device::USB->new();
    $dev = $usb->find_device( $VENDOR, $PRODUCT );

    unless ($dev) {
        syslog("info", "Couldn't find device.  Time to die, Mister Bond.");
        closelog();
        exit(1);
    }

    syslog("info", "Wicked!  Found it.");

    $dev->open();

    $dev->detach_kernel_driver_np( 0 );
    $dev->set_configuration( 1 );
    $dev->claim_interface( 0 );
}

sub cleanup {
    syslog("info", "Cleaning up...");
    $dev->release_interface( 0 );
    closelog();
}

sub daemonize {
    chdir '/';
    defined(my $pid = fork);
    exit if $pid;
    setsid;
    umask 0;
}

sub sigterm {
    syslog("info", "Caught SIGTERM.  Dying gracefully.");
    cleanup();
    exit(1);
}

sub main {
    my @time; 

    while (1) {
        @time = localtime(time);
        if (($time[1] == 0) && ($time[0] == 0)) {
            setTime('now');
        }

        if (-e "/tmp/iv4lw") {
            my $string = `cat /tmp/iv4lw`;
            chomp $string;

            if ($string =~ /scroll\s(.*)/) {
                scrollString($1);
            }

            if ($string =~ /walk\s(\d+)/) {
                walk($1);
            }

            if ($string =~ /rand\s(\d+)/) {
                randword($1);
            }

            unlink "/tmp/iv4lw";
        }

        sleep(1);
    }
}

