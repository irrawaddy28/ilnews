#!/usr/bin/perl
use File::Basename;
use File::Spec::Functions qw(catfile);
use Encode qw(encode decode);
#use diagnostics;

my @LineArray = ();
my $line = "";
my $linenum = 1;
my %WordList = ();
my $infile = ""; 
my $outdir= "";
my $include_punctuations_in_text = 0; # 0 = no punc in text, 1 = punc in text
my $ErrType = 0; # 0 = print and continue, 1 = die

sub PrintErr {
	my ($msg, $errtype) = @_;		
	if ($errtype == 0) {		
		print  "file: $infile, line $linenum \n"; print $msg;
	} elsif ($errtype == 1) {		
		print  "file: $infile, line $linenum: \n"; die($msg);
	}	
}

sub CheckFileName {
	my $infile = $_[0];
	
	@names = split(/ /, $infile);	
	if ($#names > 0) {
		PrintErr("Error!!  File name of the transcription file cannot contain blank spaces.\nCurrent file name: \"$infile\"\n\n", 1);					    
	}
	
	@names = split(/\./, $infile);	
	if ($names[$#names] !~ /txt/) {
		PrintErr("Error!!  File extension of the transcription file can only be \"txt\"\nCurrent file extn: $names[$#names]\n\n", 1);
	}	
}

sub IsNumber {
	$x = $_[0];	
	$ret = 1;
	unless ($x =~ /^[\d+.]+$/ ) {
		$ret = 0;						
	}
	return ($ret);
}

# Convert input time in <int>m<float>s format to time in <float>s format
sub GetTimes {
	my (@intimes) = @_;	
	my @outtimes;
	my @times;		
	
	foreach $k (0..1) {
		# split timestamps of type 1m23.045s or 23.045s into minutes and seconds
		@times = split(/m/, $intimes[$k]);		
		
		if ($#times == 0) {			
			# When the timestamp does not have minutes, but only seconds. eg.  23.045s
			# then @times has only 1 element which is ("23.045s"). Change this array to ("0", "23.045s")
			PrintErr("$line\nError!!  $times[0] should be in this format:\nIf the time is 1 minute 23.045 seconds, then: 1m23.045s\nIf the time is 54.341 seconds, then: 0m54.341s \n\n", $ErrType); 		  
			$times[1] = $times[0];
			$times[0] = 0;			
		}
		
		my @chars = split("", $times[1]);
		if ( $chars[$#chars] !~ /s/) {
			PrintErr("$line\nError!!  Cannot read this time stamp \"$times[1]\"\n\n", $ErrType);					    
		}
				
		# remove trailing 's' from the seconds portion		
		$times[1] =~ s/s//g;
		chomp $times[0]; chomp $times[1];
		#print "times = @times[0..1]\n";
		if ( ! IsNumber($times[0]) || ! IsNumber($times[0]) ) {
			PrintErr("$line\nError!!  $times[0] and/or $times[1] not a number\n\n", $ErrType);					    
		}
		
		IsNumber($times[1]);	    
		
		$outtimes[$k] = $times[0]*60 + $times[1];	
	}
	return (@outtimes);	
}

sub GetProcessedText {	
	# Convert the input array @_ to a scalar string using "@_". split() works only on scalar strings.
	my $string = "@_";
	
	# First, replace special characters by ASCII: Convert $string in utf-8 to Perl's internal representation
	$string = decode("utf-8", $string);	
	binmode(STDOUT, ":utf8");
	#print "ord (utf-8): ", join( "| ", map { ord } split //, $string),"\n"; # print the unicode numbers of each char in the string
	
	# Before using split, replace any expected or unexpected non-ASCII Win characters
	# a) Replace all expected non-ASCII Win chars by their ASCII equivalents 
	#$string =~ s/“/"/g; # Replace opening double (unicode \x{201C}) quote by " 
	#$string =~ s/”/"/g; # Replace closing double quote ((unicode \x{201D})) by " 
	$string =~ s/\x{201C}/"/g; # Replace opening double quote by " 
	$string =~ s/\x{201D}/"/g; # Replace closing double quote by " 
	
	#$string =~ s/—/ - /g; # Replace — (unicode \x{2014}) by -
	$string =~ s/\x{2014}/ - /g;	
	
	#$string =~ s/’/'/g; # Replace the possessive apostrophe (unicode \x{2019}) using single quote
	$string =~ s/\x{2019}/'/g; # Replace the possessive apostrophe using single quote	
	
	# separate the commas from the word
	$string =~ s/,/ , /g;
		
	# b) Remove any unexpected non-ASCII Win chars 
	$string =~ s/[^[:ascii:]]//g;
	
	# Now use split
    my @words = split(/[\s]+/, $string); 
    my @procwords;
        
    # print "words: ", join("| ", @words), "\n";
    # print "num words = ", $#words+1, "\n"; 
	
	if ($words[0] !~ /^"SIL$/) {				
		PrintErr("$line\nError!! Leading word of the sentence should start with a blank space followed by \"SIL \n\n", $ErrType);		
	} elsif ($words[$#words] !~ /^SIL"$/) {				
		PrintErr ("$line\nError!! Trailing word of the sentence should end with a blank space followed by SIL\" \n\n", $ErrType);
	} 
	
	foreach $k (0..$#words) {
		my $ThisWord = $words[$k];		
		
		chomp $ThisWord;			
		
		# Replace special symbols with whitespace, irrespective of their context
		#$ThisWord =~ s/[-!—,()?;:%+ÒÓÕÔ"]/ /g;
		$ThisWord =~ s/[\]\[;:+ÒÓÕÔÕÊ]+/ /g;
		$ThisWord =~ s/[()]+//g;
		$ThisWord =~ s/^"SIL/!SIL/g;
		$ThisWord =~ s/SIL"$/!SIL/g;
		$ThisWord =~ s/^SIL$/!SIL/g;
					
		# Replace leading and trailing single quotes from words like there', 'my  but not from
		# words like let's. E.g. 'let's go birds' -> let's go birds		
		$ThisWord =~ s/^\'//g; # replace leading singe quote: 'my -> my | 'let's -> let's 		
		#$ThisWord =~ s/(\w+\W*\s*)\'$/$1/g; # replace trailing singe quote: there' -> there | said ' -> said | said.' -> said
		
		#my $PrevWord  = "";
		#if ( $ThisWord =~ m/^layer\.'/ ) { $PrevWord = $ThisWord;}
		$ThisWord =~ s/(\w+\W*\s*)\'(\W*)$/$1 /g; # replace trailing singe quote: there' -> there | 
													#  said ' -> said | said.' -> said. | 'fraud'. -> 'fraud' 
		#if ( $PrevWord =~ m/^layer\.'/ ) { print "1: $PrevWord -> $ThisWord\n";}
		
		# Expand frequently used short-hand notations to their verbal representations. 
		# Transcribers may have forgotten to convert the short-hands, so this acts as a safenty net.
		$ThisWord =~ s/^St\.$/ Saint /g; # St. -> Saint
		$ThisWord =~ s/^U\.S$/ U. S. /g; # St. -> Saint
		$ThisWord =~ s/^w-w-w$/ w. w. w. /g; # w-w-w -> w. w. w.
		$ThisWord =~ s/\// slash /g;   # a/b -> a slash b
		$ThisWord =~ s/&/ and /g;      # a&b -> a and b
		$ThisWord =~ s/\%/ percent /g;  # a%b -> a percent b
		
		# MBA, -> M. B. A. , MBA. -> M. B. A. .  (end of sentence)
		if ($ThisWord =~  m/^[[:upper:]]{2,}$/)    # check if word contains all uppercase letters 
		    #$ThisWord !~ m/\.$/       &&   # word is not the abbreviated name of a person. E.g. "B." in  "B. Obama"
		    #$ThisWord !~ m/-/         &&   # word is not a hyphen
		    #$ThisWord !~ m/^SIL$/)           # word in not SIL		   
		{   			
			$ThisWord = join('. ', split(//, $ThisWord)); 
			$ThisWord = $ThisWord . '.';			
		}
		
		# a.m. -> a. m.
		if ($ThisWord =~ m/^(\w\.)+/) {			
			$ThisWord = join('. ', split(/\./, $ThisWord));
			$ThisWord = $ThisWord . '.';			
		}
		
		# Deal with punctuations.
		if ($include_punctuations_in_text) {
		# - -> -hyphen. E.g. pepper-spray -> pepper -hyphen spray
		# (Note: First, start with | - -> -hyphen | conversion and then convert
		# to | " -> double-quote |, | ? -> question-mark | etc. This is because 
		# if we convert | " -> double-quote | first and then do 
		# | - -> -hyphen |, double-quote will become double -hyphen quote 
		# which is not what we want ).
		$ThisWord =~ s/-/ -hyphen /g;
		
		# , -> ,comma
		$ThisWord =~ s/,/ ,comma /g;
		
		# " -> "double-quote
		$ThisWord =~ s/^"/"double-quote /g;
		$ThisWord =~ s/"$/ "double-quote/g;		
		
		# . -> .period ( "... concluded J. F. Kennedy." -> "... concluded J. F. Kennedy .period")
		# If $ThisWord is "pepper -hyphen spray.", then split string to array of words and replace on each
		# individual word in the array. It's easier to work on individual words rather than a big string.
		#$ThisWord =~ s/^(\w{2,})\.\s*/$1 \.period /g;
		$ThisWord = join(" ", map {$_ =~ s/^(\w{2,})\.\s*/$1 \.period /; $_} split (/ /, $ThisWord));
		
		# Sometimes . may be a stand-alone word		
		$ThisWord =~ s/ \. $/ \.period /g;
		
		# Some words can be like this: I can't. | Okay ,comma I'll. | -> I can't .period | Okay ,comma I'll .period
		$ThisWord =~ s/^(\w+)'(\w+)\.\s*/$1'$2 \.period /g;
		
		# ? -> ?question-mark
		$ThisWord =~ s/\?/ \?question-mark /g;
		
		# ! -> !exclamation-point
		$ThisWord !~ m/^!SIL$/ && $ThisWord =~ s/!/ !exclamation-point /g;
		} else {
			$ThisWord =~ s/-/ /g;
			$ThisWord =~ s/,/ /g;
			$ThisWord =~ s/^"/ /g;
			$ThisWord =~ s/"$/ /g;
			$ThisWord = join(" ", map {$_ =~ s/^(\w{2,})\.\s*/$1 /; $_} split (/ /, $ThisWord));
			$ThisWord =~ s/ \. $/ /g;
			$ThisWord =~ s/^(\w+)'(\w+)\.\s*/$1'$2 /g;
			$ThisWord =~ s/\?/ /g;
			$ThisWord !~ m/^!SIL$/ && $ThisWord =~ s/!/ /g;
		}
				
		# Uppercase all words 		
		$ThisWord = uc $ThisWord;
				
		# Check if the word has digits
		if ( $ThisWord =~ /\d+/) {									
			PrintErr ("$line\nError!!  Cannot have numbers like \"$ThisWord\" in the sentence part of the transcription\n\n", $ErrType);			
		}
				
		# Now remove any newline or trailing or leading whitespaces, just in case they still exist
		# Helps avoiding multiple keys for the same word such as $WordList{"your"}, $WordList{"your "} 
		chomp $ThisWord;		
		$ThisWord =~ s/^\s+|\s+$//g;
		
		# Add this word to dictionary
		if (! exists $WordList{$ThisWord}) {
			$WordList{$ThisWord} = $ThisWord;
	    }
		$procwords[$k] = $ThisWord;
				
		#print "$words[$k] -> $procwords[$k]\n";			
	}
	$procwords[$#words+1] = "\n";
	
	return (@procwords);		
    
}

#begin comment
if (@ARGV != 2) {
    die "usage: $0  raw_transcription.txt \n";
}

($infile, $outdir) = @ARGV;
open(IN_FILE,  $infile) or  die "Could not open file $infile for reading: $!\n";
# Make sure there are no blank spaces in the filename and the extension is "txt"
CheckFileName($infile);

my ($inname, $indir, $inextn) = fileparse($infile, qr/\.[^.]*/);
my $inextnqr = quotemeta $inextn; # if $inextn = ".txt", 
# then $inextnqr = "\.txt" since quotemeta escapes the dot (a metachar)
# thereby making dot a literal dot.
system("mkdir -p $outdir");

while ($line = <IN_FILE>)
{
	chomp($line);
	@LineArray = split(/\s+/,$line);
	my @TimesRaw = @LineArray[0..1];
	my @TextRaw =  @LineArray[2..$#LineArray];				
    #print "Raw:\n@TimesRaw @TextRaw\n"; #raw line	
	
	# Convert raw transcription from current line to WSJ format
	my (@TimesProc) = GetTimes(@TimesRaw);
	my (@TextProc)  = GetProcessedText(@TextRaw);
	# print "@TimesProc @TextProc\n"; # processed line
	
	# Save the processed transcription in a new file
	my $outtrans = catfile($outdir, $inname . "_" . $linenum . $inextn);	
	open(OUT_FILE, '>:encoding(UTF-8)', $outtrans) || die "Could not open file $outtrans for writing: $!\n";
	print OUT_FILE "@TextProc"; 
	my $string = "@TextProc";	
	close(OUT_FILE);
	# Note: If some utf-8 chars are still present in @TextProc, we may end up getting the
	# usual warning: "Wide character in print at ...". This means we are 
	# printing utf-8 characters to the output file which was opened for 
	# writing ASCII chars not utf-8 characters. Opening the
	# file in utf-8 mode (open(OUT_FILE, '>:encoding(UTF-8)', $outtrans))
	# will fix the warnings but our intention is to save ASCII chars in the output file.
	# So, the best thing is to remove the utf-8 chars in the first place.
	# Let's find the utf-8 chars which generate these warnings. 
	# This can be done by searching for chars whose ASCII numbers are 
	# greater than 255. To do this, use the following statements.
	# a) print STDERR join( " ", map { ord } split //, $string), "\n"; 
	# (prints the ascii numbers for every char in $string)
	#
	# b) print STDERR join( " ", map { ord } split //, $string), "( string = ", $infile, ": " , $string, " )", "\n";
	# (prints the ascii numbers for every char in $string along with the filename that $string came from)
	# 
	# First uncomment a) to print and search for the invalid ASCII numbers (perl $0 ... > errlog.txt 2>&1 |cat errlog.txt | tr ' ' '\n'|sort -nu)
	# Then comment a) and uncomment b) to trace out the exact instances of those invalid ascii numbers.	
	
	
	# Extract the corresponding chunk from the big audio file (assumed mp3),
	# convert chunk in mp3 to wav, and save the wav chunk in a file
	my $outwav   = catfile($outdir, $inname . "_" . $linenum . ".wav");	
	(my $inwav = $infile) =~ s/$inextnqr$/\.mp3/;	
	system("perl local/mp3towav.pl -s $TimesProc[0] -e $TimesProc[1] $inwav  $outwav");	
	($? == -1) && exit 1;
	$linenum++;	
}
close(IN_FILE);
