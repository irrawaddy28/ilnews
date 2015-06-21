#!/usr/bin/perl
use Getopt::Long;

my $usage = "\nUsage: $0 [-s start time in secs] [ -e end time in secs ] <input mp3 file> <output wav file>\n 
e.g.: $0 -s 1.023 -e 9.056 x.mp3 x.wav
extracts an audio segment from x.mp3 lying within the duration [1.023 s, 9.056 s], converts
the segment to 16k, PCM 16-bit signed (little endian), wav and saves it in x.wav file. If no
start and end times are provided, then the entire mp3 file is converted to wav.\n\n";
    
(@ARGV >= 2 ) || die "$usage";

my $start_time = 0.0;
my $end_time = 10000000.0;
GetOptions ("s:f" => \$start_time, "e:f" => \$end_time);
($in_file, $out_file) = @ARGV;
#print "infile = $in_file, outfile = $out_file\n";
#print "s=$start_time, e=$end_time\n";

($start_time < 0 || $end_time < 0 || $end_time <= $start_time) && 
die "start = $start_time, end = $end_time; start/end times cannot be negative; end time cannot be smaller than start time\n";

my $avconv="/usr/bin/avconv";
(-e $avconv) || die "Could not find the avconv program at $avconv!";

my @avconv_opts = ();
$avconv_opts[0] = "pcm_s16le"; # audio codec type: pcm, 16 bit, signed, little endian
$avconv_opts[1] = "16000";	   # sampling rate
$avconv_opts[2] = "1";		   # num channels, 1 for mono
$avconv_opts[3] = $start_time;  # skip segment (in seconds) at the beginnig of input file
$avconv_opts[4] = $end_time - $start_time;

# avconv mp3 to wav command
my $avconvcli = join('  ', $avconv, '-i ', $in_file, 
						 '-acodec ', $avconv_opts[0], 
						 '-ar ', $avconv_opts[1], 
						 '-ac ', $avconv_opts[2],
						 '-ss ', $avconv_opts[3],
						 '-t ',  $avconv_opts[4],
						 '-y ',						# -y force overwriting an existing o/p file, will not ask for prompt
						  $out_file,
						  ' 2>/dev/null ');
	
# send avconv cmd to system(). It should look sth like:
# /usr/bin/avconv  -i  input.wav  -acodec   pcm_s16le  -ar   16000  -ac   1  -ss   0 -t 2.5 output.wav	2>/dev/null	
print "$avconvcli\n";
system("$avconvcli"); 
($? == -1) && exit 1;	
#print "Converted $in_file -> $out_file\n";	
exit 0;	

