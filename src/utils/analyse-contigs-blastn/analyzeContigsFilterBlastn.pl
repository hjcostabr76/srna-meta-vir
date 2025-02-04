######################################################################
#######################################################################
# Copyright 2010 Fundação Oswaldo Cruz
# Author: Eric Aguiar
# template.pl is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the Free Software Foundation, version 3 of the License.
#
# template.pl is distributed in the hope that it will be useful,but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with template.pl (file: COPYING).
# If not, see <http://www.gnu.org/licenses/>.
#
#######################################################################
#######################################################################

# 
# TODO: 2023-05-26 - Use strict mode
# 

# use strict;
# use warnings;

use Getopt::Long;
use Bio::SeqIO;

#######################################################################
### PARSE INPUTS ------------------------------------------------------
#######################################################################

my $usage = "

$0 -i <input file> -f <fasta file> -q <text to search>  -p prefix --image  --debug
$0 -h

-i <input file>		: filterblast input file
-f <fasta file>     :Input fasta file used on blast
-p <prefix>         :prefix
-q <query>		    : query (organism name) case sensitive
--fasta				:Create fasta file with contigs with hit (query)
-h			: Help message

";

$| = 1;     # forces immediate prints into files rather than the buffer.

# 
# TODO: 2023-06-08 - Reenable this option
# 
# my $image;

# 
# REVIEW: 2023-06-08 - This parameter isn't being used
# 
# my $create;

my $inputFile;
my $query;
my $fasta;
my $prefix;
my $debug;
my $help;

GetOptions (
    "i=s" => \$inputFile, 
    "q=s" => \$query,
    "f=s" => \$fasta,
    "p=s" => \$prefix,
    # "image!" => \$image,
    "debug!" => \$debug,
    "h!" => \$help,
    # "fasta!" => \$create
);

if ($help) {
	die $usage;
}

if (not(defined($inputFile))) {
	die "\nGive an input file name",$usage;
}
if (not(defined($fasta))) {
	die "\nGive an fasta file name",$usage;
}
if (not(defined($prefix))) {
	die "\nGive an prefix  name",$usage;
}


#######################################################################
### Main... -----------------------------------------------------------
#######################################################################

my $path_utils = "/small-rna-metavir/src/utils";
my $path_analyse_contigs_blastn_r = "$path_utils/analyse-contigs-blastn/analyzeContigsFilterBlastn.R";

open(F, "<$fasta");

my %f;
my $seq = "";
my $id = "";

while (<F>) {
	if (/^>(\S+)/) {
	    if (length($seq) > 2) {
	        $seq =~ s/\n//g;
		    $f{$id} = $seq;
	        $f{$id}{"size"} = length($seq);
	    }

	    $id = $1;
	    $seq = "";

	} else {
	    $seq .= $_;
	}
}

$f{$id} = $seq;
$f{$id}{"size"} = length($seq);

# Query=NODE_337_length_52_cov_10.442307	Hit=gb|AFX65881.1|	Desc=polyprotein [Dengue virus 4]	Start=2687	End=2707	E-value=2e-07	Query Length=95.45%	Identical=100.00%
# Query=NODE_338_length_35_cov_13.285714	Hit=gb|AEZ01768.1|	Desc=polyprotein, partial [Dengue virus 4]	Start=24	End=39	E-value=7e-04	Query Length=97.96%	Identical=100.00%
# Query=NODE_341_length_63_cov_12.634921	Hit=gb|AFP27208.1|	Desc=polyprotein [Dengue virus 4]	Start=336	End=360	E-value=3e-09	Query Length=97.40%	Identical=100.00%

open(I, "<$inputFile");
my %hit;
my %orgs;
my %orgname;

open(FA, ">$prefix.$query.contigs.fasta");
while(<I>) {
	if (/.+$query.+/i) {
		chomp;
		
        my @f = split(/\t/,$_);
		
		my $contig= $f[0];
        my $h = $f[1];
		my $org = $f[2];
		
		$h =~ /\|(\S+)\|/;
        my $id_ncbi = $1;
		
		$org =~ /.+\[(.+)\]$/;
		my $org_name = $1;
		
		$contig =~ s/Query=//g;
		$org =~ s/Desc=//g;
		
		if (not exists $hit{$contig}) {
			print FA ">$contig ".$f{$contig}{"size"}." ".$org."\n".$f{$contig}."\n";
		}
		
		$hit{$contig} = $org;	
		$hit{$contig}{"line"} = $_;
		
		my $evalue= $f[5];
		$evalue=~ s/E-value=//g;
		
		if (not exists $f{$contig}{"org"}) {
			$f{$contig}{"org"} = $org_name;
			$f{$contig}{"desc"} = $org;
			$f{$contig}{"e"} = $evalue;
		}
		
		# if (defined($org_name) && not exists $orgname{$org_name}) {
		if (not exists $orgname{$org_name}) {
		    $orgname{$org_name}=1;

		# } elsif (defined($org_name)) {
		} else {
		    $orgname{$org_name} += 1;
		}
		
		# if (defined($id_ncbi) && not exists $orgs{$id_ncbi}) {
		if (not exists $orgs{$id_ncbi}) {
		    $orgs{$id_ncbi}{"count"} = 1;
		    $orgs{$id_ncbi}{"desc"} = $org;
		    $orgs{$id_ncbi}{"org"} = $org_name;
		    $orgs{$id_ncbi}{"evalue"} = $evalue;
		   
		# } elsif (defined($id_ncbi)) {
		} else {
		    
			$orgs{$id_ncbi}{"count"} += 1;
		    
			if ($evalue < $orgs{$id_ncbi}{"evalue"}) {
		        $orgs{$id_ncbi}{"evalue"} = $evalue;
		    }
		}
	}
}
close(FA);

print "\n\n########### Hits by protein segment...\n";
foreach my $c (keys %orgs) {
    print "Organism: $c\t"."Hits:".$orgs{$c}{"count"} ."\tDescription: ".$orgs{$c}{"desc"}."\tBest hit: ".$orgs{$c}{"evalue"}."\n";
}

print "\n\n########### Hits by Organism...\n";
foreach my $n (keys %orgname) {
    print "Organism: $n\t"."Hits:".$orgname{$n}."\n";
}

my $count = 0;
my $sum = 0;
my %sizes ; 
my $big = 0;

foreach my $c (keys %hit) {
	$count++;

	my $size = $f{$c}{"size"};
	$sum += $size;
	#print "$c \t $size \n";

	if ($size > $big) {
        $big = $size;
    } 

	if (not exists $sizes{$size}) {
		$sizes{$size} = 1;
	} else {
		$sizes{$size} = 1+ $sizes{$size};
	}

}

sub hashValueAscendingNum {
    $hash{$a} <=> $hash{$b};
}

sub hashValueDescendingNum {
   $hash{$b} <=> $hash{$a};
}

my $avg;

if ($sum == 0 or $count==0) {
	$avg = 0;
} else {
	$avg = $sum / $count;
}

print "\n\n############################################\nNumber of ($query) contigs:\t$count\n";
print "Size average:\t $avg \n";
print "Greater contig:\t$big\n";
print "Bases in contigs:\t$sum\n";

print "Size Distribution:\n";

print "\n[CONTIGS]\n";

foreach my $c (keys %f) {
	if (defined($f{$c}{"e"}) && ($f{$c}{"e"} ne "")) {
		print "$c\t" . ($f{$c}{"size"} // "") ." \t" . ($f{$c}{"org"} // "") ." \t" . ($f{$c}{"e"} // "") ."\t" . ($f{$c}{"desc"} // "")." \n";
	}			
}

# 
# REVIEW: 2023-05-26 - Check this
# 

# if (defined($image)) {
#     my @db;
   
#     if (defined($debug)) {
#         print "\n\n Downloading genomes...";
#     }
   
#     foreach my $org (keys %orgs) {
        
#         # Getting protein sequence
#         if (defined($debug)) {
#             print "Downloading $org [".$orgs{$c}{"desc"}."] ";
#         }
        
#         # 
#         # REVIEW: 2023-05-23 - Handle this one
#         # 
#         $c= "~/source_programs/edirect/esearch -db nucleotide -query \"$org\" | efetch -format fasta";

#         if (defined($debug)) {
#             print "\tRuning ($c)\n";
#         }
        
#         while (length(`$c > $org.nucleotide`) > 10) {
#             if (defined($debug)) {
#                 print "\n\t\t\t\t\t\t\t\t\tTrying download again...\n";
#             }
#         };
    
#         ### formatting protein sequence
#         my $formatting = "formatdb -p F -i $org.nucleotide";
        
#         if (defined($debug)) {
#             print "\tRuning ($formatting)... ";
#         }
        
#         if (length(`$formatting`) < 2) {
#             if (defined($debug)) {
#                 print "\tDone! \n";
#             }
#             push(@db,"$org.nucleotide");
#         } elsif (defined($debug)) {
#             print "\tError!  IGNORING DATABASE $org.nucleotide\n";
#         }
    
#         # print "Organism: $c\t"."Hits:".$orgs{$c}{"count"} ."\tDescription: ".$orgs{$c}{"desc"}."\n";
#     }

#     open(CON,">$prefix.contigs");

#     foreach $id (keys %hit) {
#         print CON ">$id\n".$f{$id}."\n";    
#     }
#     close(CON);

#     my %blast;
#     for (my $i=0;  $i < scalar @db; $i++) { 
        
#         my $d = $db[$i];
    
#         my $c1 = "blastall -p blastn -i $prefix.contigs  -d $d -e 1e-3 -o $prefix.$d.1e3.blastn -a 10";
#         if (defined($debug)) {
#             print "running ($c1)...\n";
#         }
#         `$c1`;
        
#         my $c2 = "/home/ubuntu/bin/filterblast.pl -b $prefix.$d.1e3.blastn --best --desc > $prefix.$d.1e3.blastn.filterblast";
#         if (defined($debug)) {
#             print "running ($c2)...\n";
#         }
#         `$c2`;
        
#         $blast{$d} = "$prefix.$d.1e3.blastn.filterblast";

#     }

#     my %hitOrg;

#     foreach my $s (keys %blast) {
    
#         if (defined($debug)) {
#             print "openning $s...\n";
#         }
        
#         open(O2,"<".$blast{$s});
        
#         my $out = $blast{$s}.".tab";
#         open(OUT,">$out");
        
#         while(<O2>) {
#             chomp;
            
#             my @f = split(/\t/,$_);
#             my $contig = $f[0];
#             my $org = $f[2];
#             my $h = $f[1];
#             my $start = $f[3];
#             my $end = $f[4];
#             my $evalue = $f[5];
        
#             $start =~ s/Start=//g;
#             $end =~ s/End=//g;
#             $evalue =~ s/E-value=//g;
        
#             $h =~ /\|(\S+)\|/;
#             my $id_ncbi = $1;
#             $org =~ /.+\[(.+)\]$/;
#             my $org_name = $1;
        
#             $contig =~ s/Query=//g;
#             $org =~ s/Desc=//g;
    
#             # 
#             # TODO: 2023-05-23 - Check what to do with these 'parallel' logging files
#             # 
#             print OUT "$org_name\t$contig\t$start\t$end\t$evalue\t".$f{$contig}{"size"}."\n";
    
#         }
#         close(OUT);
        
#         my $size = `grep -v ">" $s |tr -d [:cntrl:] | wc -m`;
#         chomp($size);
#         my $org_name =~ s/ /_/g;
#         $org_name =~ s/[^[:alpha:]]//g;
    
#         my $c3 = "R --no-save $out $s $size $prefix $org_name < $path_analyse_contigs_blastn_r";
#         if (defined($debug)) {
#             print "Runinng $c3 ...\n\n";
#         }
#         `$c3`;
#     }
# }
