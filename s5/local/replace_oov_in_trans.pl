#!/usr/bin/perl

$lexfile = shift @ARGV;
$unk = shift @ARGV;
$oovfile = shift @ARGV;

open(S, "<$lexfile") || die "Failed opening lexicon file $lexfile\n";
while(<S>){ 
    @A = split(" ", $_);
    @A == 1 && die "Bad line in lexicon file: $_";
    $seen{$A[0]} = 1;
}
close (S);

%oov = ();
while(<>) {
	@A = split /\s+/, $_;
	my $uttid = shift @A;
	my @B = ();
	push @B, $uttid;
	foreach my $word (@A) {
		#print "seen $word ? $seen{$word}\n";
		if(!defined $seen{$word}) {
			$oov{$word}++ ;
			$word = $unk;
		}
		push @B, $word;
	}
	print "@B\n";	
}


open(OOVF, ">$oovfile") || die "Failed writing to oov file $oovfile\n";	
print OOVF "$_ $oov{$_}\n" for sort keys %oov;
close (OOVF);

exit 0;
