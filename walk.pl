#!/usr/bin/perl

walk($ARGV[0]);
0;

sub walk {
	my $nwords = shift;

	my @allwords = `cat /usr/share/dict/words | egrep '^[a-z]{4}\$'`;
	
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

		print $thisword."\n";

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

		delete $allmatches{$thisword};
		my @allmatches = keys %allmatches;
		#for (sort @allmatches) {
		#	print "-- $_\n";
		#}

		# choose a new random word from the list, or generate a new one if we're at a leaf
		if ($#allmatches > 0) {
			$thisword = $allmatches[int(rand($#allmatches))];
		} else {
			$thisword = $allwords[int(rand($#allwords))];
		}
	}
}
