#!/usr/bin/perl -w
use strict;
use warnings;
use feature 'switch';

# list of global variables
my $input_file = "";
my $output_content = "";
my $has_variable_flag = 0;

# check for arguments
if (@ARGV > 0) {
	$input_file = $ARGV[0];
}

open(F, "<$input_file") or die "Cannot open $input_file";
while (my $line = <F>) {
	$has_variable_flag = 0;
	given($line) {
		when (/#!\/usr\/bin\/perl/) {
			$output_content .= "#!/usr/bin/python2.7 -u\n"
		}
		when (/print/) {
			$output_content .= convert_print_statement($line);
		}
		if (has_variable($line)) {
			$output_content .= handle_variables($line);
		}
#		when (/\$\w+/) {
		#	print "found a variable";
#			handle_variables($line);
#		}
		when (/^$/s) {
			$output_content .= $line;
		}
	}
}

print $output_content;

sub convert_print_statement {
	my $line = $_[0];
	$line = remove_semicolon($line);
	my $output .= "print \"";
	while ($line =~ /"(.+?)"/g) {
		my $match = $1;
		if (has_variable($match)) {
			$match =handle_variables($match);
		}
		$match =~ s!\\[rn]?!!g;
		$output .= $match;
	}
	$output .= "\"";
	return $output;
}

sub handle_variables {
	my $line = $_[0];
	$line = remove_semicolon($line);
	$line =~ s/\$//g;
	return $line;
}

sub has_variable {
	my $line = $_[0];
	if ($line =~ /\$\w+/) {
		return 1;
	}
	return 0;
}

sub remove_semicolon {
	my $line = $_[0];
	$line =~ s/;//;
	return $line;
}
