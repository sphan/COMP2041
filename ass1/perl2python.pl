#!/usr/bin/perl -w
use strict;
use warnings;
use feature 'switch';

# list of global variables
my $input_file = "";
my $output_content = "";

# check for arguments
if (@ARGV > 0) {
	$input_file = $ARGV[0];
}

open(F, "<$input_file") or die "Cannot open $input_file";
while (my $line = <F>) {
	given($line) {
		when (/#!\/usr\/bin\/perl/) {
			$output_content .= "#!/usr/bin/python2.7 -u\n"
		}
		when (/print/) {
			convert_print_statement($line);
		}
		$output_content .= $line;
	}
}

print $output_content;

sub convert_print_statement {
	my $line = $_[0];
	$line = remove_semicolon($line);
	$output_content .= "print \"";
	while ($line =~ /"(.+?)"/g) {
		my $match = $1;
		$match =~ s!\\[rn]?!!g;
		$output_content .= $match;
	}
	$output_content .= "\"";
}

sub remove_semicolon {
	my $line = $_[0];
	$line =~ s/;//;
	return $line;
}
