#!/usr/bin/env perl
use warnings;
use strict;

use utf8;

use open ':utf8';
use open ':std';

use List::Util qw(sum);
use Data::Dumper;

my $file = $ARGV[0];

die "Gimme dict file!\n" unless $file && -r $file;

open(my $fh, $file);

# mappings for unicode characters of vowels with tone marks over them
my %to_unicode = (
	a => ["\x{0101}", "\x{00E1}", "\x{01CE}", "\x{00E0}"],
	e => ["\x{0113}", "\x{00E9}", "\x{011B}", "\x{00E8}"],
	i => ["\x{012B}", "\x{00ED}", "\x{01D0}", "\x{00EC}"],
	o => ["\x{014D}", "\x{00F3}", "\x{01D2}", "\x{00F2}"],
	u => ["\x{016B}", "\x{00FA}", "\x{01D4}", "\x{00F9}"],
	'u:' => ["\x{01D6}", "\x{01D8}", "\x{01DA}", "\x{01DC}"],
);

my (%entries, %py_count, @proper);

my $id = 1;
while (<$fh>) {
	next if /^#/;
	s/\s*$//;	
   
	# parse each line of dict file into separate parts
	my ($trad, $simp, $py, $defs) = m|^ (\S+) \s (\S+) \s \[(.*?)\] \s /(.*)/ $|x;
	my $id = $entries{$simp} ? (@{$entries{$simp}} + 1) : 1;
	my $entry = +{
		trad => [split //, $trad],
		simp => [split //, $simp],
		raw_simp => $simp,
		py => [split ' ', $py],
		raw_py => lc($py),
		defs => [split '/', $defs],
		id => "${simp}_${id}",
	};
	
	# keep counts of how each pronunciation for each character (so we can 
	# choose the "most common" pronunciation as the default)
	for (my $i = 0; $i < @{$entry->{trad}}; $i++) {
		$py_count{$entry->{simp}[$i]}{$entry->{py}[$i]}++;
		if ($entry->{simp}[$i] ne $entry->{trad}[$i]) {
			$py_count{$entry->{trad}[$i]}{$entry->{py}[$i]}++;			
		}
	}
	
	# track proper nouns separately so we can merge them in
	if ($py =~ /^[A-Z]\S*\d/) {
		push @proper, $entry;
	} else {
		push @{$entries{$simp}}, $entry;		
	}	
}

# merge in proper nouns so they aren't their own entries
foreach my $p (@proper) {
	my ($match) = grep { $_->{raw_py} eq $p->{raw_py} } @{$entries{$p->{raw_simp}}};
	if ($match) {
		push @{$match->{defs}}, @{$p->{defs}};
	} else {
		$p->{id} = "$p->{raw_simp}_" . (@{$entries{$p->{raw_simp}}} + 1);
		push @{$entries{$p->{raw_simp}}}, $p;
	}
}

open(my $out, '>MyDictionary.xml');

# write out dictionary XML header
print $out <<PREAMBLE;
<?xml version="1.0" encoding="UTF-8"?>
<d:dictionary xmlns="http://www.w3.org/1999/xhtml" xmlns:d="http://www.apple.com/DTDs/DictionaryService-1.0.rng">
<d:entry id="front_back_matter" d:title="Front/Back Matter">
</d:entry>
PREAMBLE

sub entry_commonness_score {
	my $entry = shift;
	
	my $score = 0;
	for (my $i = 0; $i < @{$entry->{simp}}; $i++) {
		$score += $py_count{$entry->{simp}[$i]}{$entry->{py}[$i]} || 0;
	}
	return $score;
}

sub common_first { entry_commonness_score($b) <=> entry_commonness_score($a) }

foreach my $entry (map { sort common_first @$_ } values %entries) {
	my @trad_chars = @{$entry->{trad}};
	my @simp_chars = @{$entry->{simp}};
	
	# decide if trad and simp differ (but show '~' for characters that don't differ)
	my $want_simp = 0;
	for (my $i = 0; $i < @trad_chars; $i++) {
		if ($trad_chars[$i] ne $simp_chars[$i]) {
			$want_simp = 1;
		} else {
			$simp_chars[$i] = '~';
		}
	}

	my $title = join('', @trad_chars) . ($want_simp ? ' [' . join('', @simp_chars) . ']' : '');

	print $out qq{<d:entry id="$entry->{id}" d:title="title">\n};
	my $trad = join '', @{$entry->{trad}};
	$trad =~ s/[[:punct:]]//g;
	my $simp = join '', @{$entry->{simp}};
	$simp =~ s/[[:punct:]]//g;
	print $out qq{\t<d:index d:value="$trad"/>\n};
	print $out qq{\t<d:index d:value="$simp"/>\n} if $want_simp;

	(my $py_no_tones = $entry->{raw_py}) =~ s/[\d\s]//g;
	$py_no_tones =~ s/u:/v/g;
	print $out qq{\t<d:index d:value="$py_no_tones"/>\n};
	
	print $out qq{\t<div d:priority="2"><h1>$title</h1></div>\n};
	print $out qq{\t<span class="syntax">\n};
	print $out qq{\t\t<span class="pinyin" d:pr="1">| } . pretty_pinyin($entry->{py}) . qq{ |</span>\n};
	print $out qq{\t</span>\n};
	print $out qq{\t<div>\n};
	print $out qq{\t\t<ol>\n};

	# print out a list element for each definition
	my $mw = '';
	foreach my $def (@{$entry->{defs}}) {
		$def =~ s/</&lt;/g;
		$def =~ s/>/&gt;/g;
		
		$def =~ s/\s?\[(.*?)\]\s?/' |' . pretty_pinyin($1) . '| '/ge;
		$def =~ s/(\S+)\|(\S+)s?/$1 [$2] /g;
		$def =~ s/\s+$//;
		$def =~ s/\s,/,/g;
		$def =~ s/,\]/\],/g;
		
		if ($def =~ s/^CL:/Measure Word(s): /) {
			$def =~ s/\s?,(\S)/, $1/g;
			$mw = $def;
		} else {
			print $out qq{\t\t\t<li>$def</li>\n};
		}
	}
	print $out qq{\t\t</ol>\n};
	print $out qq{\t\t<span>$mw</span>\n} if $mw;
	print $out qq{\t</div>\n};
	print $out qq{</d:entry>\n};
}

# close the dictionary
print $out qq{</d:dictionary>\n};

# turn a string (or arrary ref) of pinyin syllables into "pretty pinyin"
# e.g. "jia1 ming2" => "jiā míng"
sub pretty_pinyin {
	my ($py) = @_;

	$py = [split ' ', $py] if !ref($py);

	my @result;
	foreach my $s (@$py) {
		my $tone;
		if ($s =~ s/(\d)$//) {
			$tone = $1;
		}

		if (!$tone || $tone == 5) {
			push @result, $s;
		} else {
			if ($s =~ /([ae])|(?:(o)u)/) {
				my $v = $1 || $2;
				$s =~ s/$v/$to_unicode{$v}[$tone-1]/;
			} else {
				$s =~ s/(.*)((?:u:)|[aeiou])/$1$to_unicode{$2}[$tone-1]/;
			}
			push @result, $s;
		}
	}
	my $r = join ' ', @result;
	$r =~ s/ ([,.:;])/$1/g;
	$r =~ s/ r\b/\(r\)/g;
	return $r;
}

