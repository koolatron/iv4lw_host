#!/usr/bin/perl

my @bitChain = ("0", "0", "0", "0", "0", "0", "p", "o", "a", "h", "g", "m", "n", "f", "0", "0", "l", "e", "d", "c", "b", "i", "j", "k");

my $A = "abcdokhg";
my $B = "abcdefikm";
my $C = "abefhg";
my $D = "abcdefim";
my $E = "abefhgo";
my $F = "abfhgo";
my $G = "abdefhgok";
my $H = "cdhgok";
my $I = "abefim";
my $J = "cdefgok";
my $K = "hgojl";
my $L = "hgef";
my $M = "hgcdpj";
my $N = "cdghpl";
my $O = "abcdefgh";
my $P = "abcghok";
my $Q = "abcdefghl";
my $R = "abcghokl";
my $S = "abdefhok";
my $T = "abim";
my $U = "cdefgh";
my $V = "ghjn";
my $W = "cdlngh";
my $X = "pjnl";
my $Y = "pjm";
my $Z = "abjnfe";
my $a = "ogmfe";
my $b = "homgf";
my $c = "ogf";
my $d = "omgfi";
my $e = "ognf";
my $f = "imokb";
my $g = "haoimf";
my $h = "homg";
my $i = "m";
my $j = "mf";
my $k = "imkl";
my $l = "aime";
my $m = "okgmd";
my $n = "omg";
my $o = "omgf";
my $p = "hoaig";
my $q = "ahoime";
my $r = "og";
my $s = "fmk";
my $t = "imoke";
my $u = "gfm";
my $v = "gn";
my $w = "gmdfe";
my $x = "imjn";
my $y = "lde";
my $z = "onf";
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
my $at = "kmedcbahg";
my $star = "impljnok";
my $qmrk = "abckm";
my $eq = "okfe";
my $lt = "jl";
my $gt = "pn";
my $col = "of";
my $scol = "ke";

my %glyphs = ('A' => $A,
              'B' => $B,
              'C' => $C,
              'D' => $D,
              'E' => $E,
              'F' => $F,
              'G' => $G,
              'H' => $H,
              'I' => $I,
              'J' => $J,
              'K' => $K,
              'L' => $L,
              'M' => $M,
              'N' => $N,
              'O' => $O,
              'P' => $P,
              'Q' => $Q,
              'R' => $R,
              'S' => $S,
              'T' => $T,
              'U' => $U,
              'V' => $V,
              'W' => $W,
              'X' => $X,
              'Y' => $Y,
              'Z' => $Z,
              'a' => $a,
              'b' => $b,
              'c' => $c,
              'd' => $d,
              'e' => $e,
              'f' => $f,
              'g' => $g,
              'h' => $h,
              'i' => $i,
              'j' => $j,
              'k' => $k,
              'l' => $l,
              'm' => $m,
              'n' => $n,
              'o' => $o,
              'p' => $p,
              'q' => $q,
              'r' => $r,
              's' => $s,
              't' => $t,
              'u' => $u,
              'v' => $v,
              'w' => $w,
              'x' => $x,
              'y' => $y,
              'z' => $z,
              '1' => $one,
              '2' => $two,
              '3' => $three,
              '4' => $four,
              '5' => $five,
              '6' => $six,
              '7' => $seven,
              '8' => $eight,
              '9' => $nine,
              '0' => $zero,
              'qmrk' => $qmrk,
              'star' => $star,
              'at' => $at,
              'col' => $col,
              'scol' => $scol,
              'eq' => $eq,
              'lt' => $lt,
              'gt' => $gt,

);

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

	print STDOUT "\#define char_".$_." ";
	for (@thisGlyphAsDelimitedHex) {
		print STDOUT $_;
	}

	print STDOUT "\n";
}
