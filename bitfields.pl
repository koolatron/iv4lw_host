#!/usr/bin/perl

my @bitChain = ("0", "0", "0", "0", "0", "0", "p", "o", "a", "h", "g", "m", "n", "f", "0", "0", "l", "e", "d", "c", "b", "i", "j", "k");

my $a = "abcdokhg";
my $b = "abcdefikm";
my $c = "abefhg";
my $d = "abcdefim";
my $e = "abefhgo";
my $f = "abfhgo";
my $g = "abdefhgok";
my $h = "cdhgok";
my $i = "abefim";
my $j = "cdefgok";
my $k = "hgojl";
my $l = "hgef";
my $m = "hgcdpj";
my $n = "cdghpl";
my $o = "abcdefgh";
my $p = "abcghok";
my $q = "abcdefghl";
my $r = "abcghokl";
my $s = "abdefhok";
my $t = "abim";
my $u = "cdefgh";
my $v = "ghjn";
my $w = "cdlngh";
my $x = "pjnl";
my $y = "pjm";
my $z = "abjnfe";
my $zero = "abcdefghjn";
my $one = "abefim";
my $two = "abckogfe";
my $three = "abcdkef";
my $four = "hokcd";
my $five = "bahokdef";
my $six = "bahgfedko";
my $seven = "abcd";
my $eight = "abcdefghok";
my $nine = "abcdhok";

my %glyphs = ('a' => $a, 'b' => $b, 'c' => $c, 'd' => $d, 'e' => $e, 'f' => $f, 'g' => $g, 'h' => $h, 'i' => $i, 'j' => $j, 'k' => $k, 'l' => $l, 'm' => $m, 'n' => $n, 'o' => $o, 'p' => $p, 'q' => $q, 'r' => $r, 's' => $s, 't' => $t, 'u' => $u, 'v' => $v, 'w' => $w, 'x' => $x, 'y' => $y, 'z' => $z, '1' => $one, '2' => $two, '3' => $three, '4' => $four, '5' => $five, '6' => $six, '7' => $seven, '8' => $eight, '9' => $nine, '0' => $zero);

for (sort(keys %glyphs)) {
	my @thisGlyphAsList;
	my $thisGlyphAsString = $glyphs{$_};
	for (@bitChain) {
		my $bit = $_;
		if ($bit eq "0") { push @thisGlyphAsList, "0"; next; }
		if ($thisGlyphAsString =~ /$bit/) { push @thisGlyphAsList, "1"; next; }
		push @thisGlyphAsList, "0";
	}

	reverse @thisGlyphAsList;
	$thisGlyphAsBinaryString = join '', @thisGlyphAsList;
	$thisGlyphAsHexString = sprintf("%06x", oct("0b$thisGlyphAsBinaryString"));	

	my @thisGlyphAsDelimitedHex = split '', $thisGlyphAsHexString;
	@thisGlyphAsDelimitedHex = ("0x".$thisGlyphAsDelimitedHex[0].$thisGlyphAsDelimitedHex[1], ", 0x".$thisGlyphAsDelimitedHex[2].$thisGlyphAsDelimitedHex[3], ", 0x".$thisGlyphAsDelimitedHex[4].$thisGlyphAsDelimitedHex[5]);

	print STDOUT "\#define char_".uc($_)." ";
	for (@thisGlyphAsDelimitedHex) {
		print STDOUT $_;
	}

	print STDOUT "\n";
}
