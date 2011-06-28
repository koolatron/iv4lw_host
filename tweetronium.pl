#!/usr/bin/perl

use Net::Twitter;
use Data::Dumper;
use Scalar::Util 'blessed';

my $CONSUMER_KEY = "SZlttgFD7QH6ZYB158Caog";
my $CONSUMER_SECRET = "LHBEAtQ2i7fl35NEnzKF7Hik8LVbMsdVyqHsw2sOwYo";

my $nt = Net::Twitter->new (
    traits          => [qw/API::REST OAuth/],
    consumer_key    => $CONSUMER_KEY,
    consumer_secret => $CONSUMER_SECRET 
);

my ($access_t, $access_t_secret) = restore_tokens();
if ($access_t && $access_t_secret) {
    $nt->access_token($access_t);
    $nt->access_token_secret($access_t_secret);
}

unless ($nt->authorized) {
    print "Authorize this app at ", $nt->get_authorization_url, " and enter the PIN#\n";
    my $pin = <STDIN>;
    chomp $pin;

    my ($access_t, $access_t_secret, $user_id, $screen_name) = $nt->request_access_token(verifier => $pin);
    save_tokens($access_t, $access_t_secret);
}

eval {
#    my $statuses = $nt->user_timeline( { count => 1, screen_name => 'wilw' } );
    my $statuses = $nt->friends_timeline( { count => 1 } );
    for my $status (@{ $statuses }) {
        print "$status->{created_at} <$status->{user}{screen_name}> $status->{text}\n";
    }
};
if ( my $err = $@ ) {
    die $@ unless blessed $err && $err->isa('Net::Twitter::Error');
    warn "HTTP Response Code: ", $err->code, "\n",
         "HTTP Message......: ", $err->message, "\n",
         "Twitter error.....: ", $err->error, "\n";
}

0;

# Utility method restores tokens dumped into tweetronium.config
sub restore_tokens {
    my $config;

    eval {
        local $/ = '';
        open CONFIG, "< tweetronium.config" or die "Couldn't open tweetronium.config for reading";
        $config = <CONFIG>;
        close CONFIG;
    };
    return undef if $@;

    my ($VAR1, $VAR2);
    eval $config;
    warn $@ if $@;

    return ($VAR1, $VAR2);
}

# Utility method saves tokens to tweetronium.config
sub save_tokens {
    my $access_token = shift;
    my $access_token_secret = shift;

    my $config;

    eval {
        open CONFIG, "> tweetronium.config" or die "Couldn't open tweetronium.config for writing";
        print CONFIG Data::Dumper->Dump([$access_token, $access_token_secret], qw/access_token access_token_secret/);
        close CONFIG;
    };
    return undef if $@;

    return 0;
}

