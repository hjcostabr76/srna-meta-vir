use strict;
use warnings;

use Getopt::Long;
use Bio::SeqIO;

#
# TODO: 2023-05-15 - Use a decent logger
# 
use constant PATH_LOG_MAIN => "small_rna_metavir.main.log";

#######################################################################
### PARSE INPUTS ------------------------------------------------------
#######################################################################

my $usage = "

$0 -i <input sam file> -si <initial size> -se <end size> -o <output>
$0 -h

-i <input sam file>     : Input sam file
-si <initial size>      : Initial size of the sequence
-se <end size>          : End size of the sequence
-o <output>             : output file
-h                      : Help message

";

$| = 1;        # forces immediate prints into files rather than the buffer.

my $input;
my $sizeI;
my $sizeE;
my $out;
my $help;

GetOptions(
    "i=s"  => \$input,
    "si=s" => \$sizeI,
    "se=s" => \$sizeE,
    "o=s"  => \$out,
    "h!"   => \$help
);

if ($help) {
    die $usage;
}

if (not(defined($input))) {
    die "\nGive an input file name", $usage;
}

if ((not(defined($sizeE)) or not(defined($sizeI))) and ($sizeI > $sizeE) and ($sizeI != 0 and $sizeE != 0)) {
    die "\nGive initial size and end size valid", $usage;
}

#######################################################################
### Configure logging -------------------------------------------------
#######################################################################

# 
# TODO: 2023-02-27 - Find a better way to do this...
# TODO: 2023-02-27 - Restablish the custom log file(s) option
# 

# open(metrics, ">$step8/full_metrics.txt");
# open(interest, ">$step8/metrics_of_interest.txt");
# open(LOG, ">$log");

# 
# NOTE: From here on all printed stuff will be sent to the log file
# 

# open filehandle log.txt
my $LOG_FH;
open($LOG_FH, ">>", PATH_LOG_MAIN) or die "Couldn't open: $!"; # $! is a special variable holding the error
*STDERR = $LOG_FH;
# select $LOG_FH;

#######################################################################
### Main --------------------------------------------------------------
#######################################################################

open(S, "<$input") or die "Failure as trying to open '$input' INPUT file";
open(O, ">$out") or die "Failure as trying to open '$out' OUTPUT file";

while (<S>) {
    /\t(\d+)M.+\t/;
    if (/^@.+/) {
        print O $_;
    } elsif ($1 ge $sizeI and $1 le $sizeE) {
        print O $_;
    }
}

close(S);
close(O);
