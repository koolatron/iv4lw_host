#!/usr/bin/perl

use strict;
use Getopt::Long;
use Device::USB;
use Time::HiRes qw(gettimeofday);
use Time::HiRes qw(usleep);
use Sys::Syslog;
use Socket;
use Carp;
use IO::Select;
use POSIX qw(setsid);

my %opts;
if (!&GetOptions(\%opts,
    'daemonize',
    'run',
    'port=s',
    'proto=s',
   ) || (!$opts{run}) || (!$opts{port})) {
    exit(1);
}

$SIG{TERM} =\&sigterm;

my $EOL = "\015\012";

my $VENDOR = 0x16c0;
my $PRODUCT = 0x05dc;

my $CUSTOM_RQ_SET_STATE     = 1;
my $CUSTOM_RQ_GET_STATE     = 2;
my $CUSTOM_RQ_SET_BUFFER    = 3;
my $CUSTOM_RQ_GET_BUFFER    = 4;
my $CUSTOM_RQ_SET_TIME      = 11;
my $CUSTOM_RQ_GET_TIME      = 12;
my $CUSTOM_RQ_SET_RAW       = 13;
my $CUSTOM_RQ_GET_ADC       = 14;

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
    syslog("debug", "WARNING: setBuffer: returned $ret") if ($ret != 4);
}

sub getBuffer {
    my $ret = $dev->control_msg( 192, $CUSTOM_RQ_GET_BUFFER, 0, 0, my $buffer = "\0", 8, 5000 );
    syslog("debug", "getBuffer: returned $ret");

    return $buffer;
}

sub getADC {
    my $ret = $dev->control_msg( 192, $CUSTOM_RQ_GET_ADC, 0, 0, my $buffer = "\0", 1, 5000 );
    syslog("debug", "WARNING: getADC: returned $ret") if ($ret != 1);

    $buffer = unpack("C", $buffer);

    return $buffer;
}

sub setState {
    my $state = shift;

    my $ret = $dev->control_msg( 64, $CUSTOM_RQ_SET_STATE, ord($state), 0, my $buffer = "\0", 0, 5000 );
    syslog("debug", "WARNING: setState: returned $ret") if ($ret != 0);
}

sub getState {
    my $ret = $dev->control_msg( 192, $CUSTOM_RQ_GET_STATE, 0, 0, my $buffer = "\0", 1, 5000 );
    syslog("debug", "WARNING: getState: returned $ret") if ($ret != 1);

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
    syslog("debug", "WARNING: setTime: returned $ret") if ($ret != 4);
}

sub getTime {
    my $ret = $dev->control_msg( 192, $CUSTOM_RQ_GET_TIME, 0, 0, my $buffer = "\0", 4, 5000 );

    my @hms = unpack ("CCCC", $buffer);

    return sprintf ("%02d:%02d:%02d:%03d", $hms[3], $hms[2], $hms[1], $hms[0]);
}

sub setRaw {
    my $place = shift;
    my @charString = @{translateGlyph(shift)};

    my $buffer = pack ("CCC", hex($charString[0]), hex($charString[1]), hex($charString[2]));

    my $ret = $dev->control_msg( 64, $CUSTOM_RQ_SET_RAW, $place, 0, $buffer, 3, 5000 );
    syslog("debug", "WARNING: setRaw: returned $ret") if ($ret != 3);

    return $buffer;
}

sub translateGlyph {
    my $thisGlyphAsString = shift;
    my @thisGlyphAsList;
    my @bitChain = ("0", "0", "0", "0", "0", "0", "p", "o", "a", "h", "g", "m", "n", "f", "0", "0", "l", "e", "d", "c", "b", "i", "j", "k");

    for (@bitChain) {
        my $bit = $_;
        if ($bit eq "0") { push @thisGlyphAsList, "0"; next; }
        if ($thisGlyphAsString =~ /$bit/) { push @thisGlyphAsList, "1"; next; }
        push @thisGlyphAsList, "0";
    }

    reverse @thisGlyphAsList;
    my $thisGlyphAsBinaryString = join '', @thisGlyphAsList;
    my $thisGlyphAsHexString = sprintf("%06x", oct("0b$thisGlyphAsBinaryString"));

    my @thisGlyphAsDelimitedHex = split '', $thisGlyphAsHexString;
    @thisGlyphAsDelimitedHex = ("0x".$thisGlyphAsDelimitedHex[0].$thisGlyphAsDelimitedHex[1], "0x".$thisGlyphAsDelimitedHex[2].$thisGlyphAsDelimitedHex[3], "0x".$thisGlyphAsDelimitedHex[4].$thisGlyphAsDelimitedHex[5]);

    return \@thisGlyphAsDelimitedHex;
}


sub twirl {
    my $revolutions = int(shift);

    setState("U");
    
    while ($revolutions) {
        for ('a' .. 'p') {
            my $letter = $_;
            for (0 .. 3) {
                my $tube = $_;
                setRaw($tube, $letter);
                usleep(15000);
            }
        }
        $revolutions -= 1;
    }

    setState("T");
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

        usleep(250000);
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
	my @allwords = `cat /usr/share/dict/words | egrep '^[a-z]{4}\$'`;    
	my @matchlog;

	my $initialState = getState();

	# choose an intial random word in @allwords
    	my $thisword = $allwords[int(rand($#allwords))];
    	chomp $thisword;
 
    	for ($nwords; $nwords > 0; $nwords--) {
        	my @thiswordarray = split //, $thisword;

		# construct a set of search strings from our random word
		my @searchwords = ( ".".@thiswordarray[1].@thiswordarray[2].@thiswordarray[3],
				    @thiswordarray[0].".".@thiswordarray[2].@thiswordarray[3],
				    @thiswordarray[0].@thiswordarray[1].".".@thiswordarray[3],
				    @thiswordarray[0].@thiswordarray[1].@thiswordarray[2]."." );

		# generate a list of matches for this word
		my %allmatches;
		for (@searchwords) {
			my $searchword = $_;
			my @matchwords = grep /$searchword/i, @allwords;

			for (@matchwords) {
				my $matchword = $_;
				chomp $matchword;
				$allmatches{$matchword} = 1;
			}
		}

		# don't match the word we started from
		delete $allmatches{$thisword};

		for (@matchlog) {
			delete $allmatches{$_};
		}

		my @allmatches = keys %allmatches;

		# choose a new random word from the list, or generate a new one if we're at a leaf
		if ($#allmatches >= 0) {
			$thisword = $allmatches[int(rand($#allmatches+1))];
			push @matchlog, $thisword;
		} else {
			$thisword = $allwords[int(rand($#allwords+1))];
			chomp $thisword;
			push @matchlog, $thisword;
		}

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

    syslog("info", "Found it, YEEEAH");

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
    syslog("info", "Caught SIGTERM.  Goodbye, cruel world!");
    cleanup();
    exit(1);
}

sub main {
    my $port = $opts{port} ? $opts{port} : undef;
    my $proto = $opts{proto} ? getprotobyname($opts{proto}) : getprotobyname('tcp');

    if ($port && $proto) {
        socket(Server, PF_INET, SOCK_STREAM, $proto)                || die "socket: $!";
        setsockopt(Server, SOL_SOCKET, SO_REUSEADDR, pack("l", 1))  || die "setsockopt: $!";
        bind(Server, sockaddr_in($port, INADDR_ANY))                || die "bind: $!";
        listen(Server, SOMAXCONN)                                   || die "listen: $!";

        syslog("info", "server started on port $port");
    }

    START: while (1) {
        my $paddr;
        setTime('now');

        eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            alarm 30;
            $paddr = accept(Client,Server);
            alarm 0;
        };
 
        if ($@) {
            die unless $@ eq "alarm\n";
            next START;
        }

        my ($port, $iaddr) = sockaddr_in($paddr);
        my $name = gethostbyaddr($iaddr, AF_INET);

        syslog("info", "connection from $name (". inet_ntoa($iaddr). ") on port $port");

        my $command = <Client>;
        chomp $command;
        syslog("info", "recieved command: $command");
        close Client; 

        if ($command =~ /scroll\s(.*)/ ) {
            scrollString($1);
        }
        if ($command =~ /rand\s(\d+)/ ) {
            randword($1);
        }
        if ($command =~ /walk\s(\d+)/ ) {
            walk($1);
        }
        if ($command =~ /twirl\s(\d+)/ ) {
            twirl($1);
        }
        if ($command =~ /buffer?/ ) {
            my $buffer = getBuffer();
            syslog("info", "getBuffer: buffer contents: $buffer");
        }
        if ($command =~ /sb\s(.*)/ ) {
            setBuffer($1);
        }
        if ($command =~ /volts\?/ ) {
            my $buffer = getADC();
            syslog("info", "getADC: ADC register contents: $buffer");
            syslog("info", "output voltage: ".($buffer * 0.435)."V");
        }
        if ($command =~ /state\?/ ) {
            my $buffer = getState();
            syslog("info", "getState: state register contents: $buffer");
        }
        if ($command =~ /time\?/ ) {
            my $buffer = getTime();
            syslog("info", "getTime: time register contents: $buffer");
        }
    }
}

