#!/usr/bin/perl -w
use strict;
use warnings;

my $input_file = "";
my $header_content = "";
my @main_content = ();
my %syntax_table = ();

if (@ARGV > 0) {
	$input_file = $ARGV[0];
	read_from_file();
} else {
	read_from_stdin();	
}

sub read_from_file {
	open(F, "<$input_file") or die "Cannot open $input_file";
	while (my $line = <F>) {
		main($line);	
	}
}

sub read_from_stdin {
	while (my $line = <STDIN>) {
		main($line);	
	}
}

sub main {
	my $line = $_[0];
	$line =~ s/;$//g;
	if ($line =~ /\#!\/usr\/bin\/perl -w/) {
		$header_content .= "#!/usr/bin/python2.7 -u\n";
	} elsif ($line =~ /^\s*print/) {
		handle_print($line);
	} else {
		my ($spaces) = $line =~ /(\s*)\w/;
		my @components = split(/\s/, $line);
		
	}
	print_output();
}

sub print_output {
	print $header_content;
	
	foreach (@main_content) {
		print;
	}
}

sub handle_variable {
	my $line = $_[0];
	if ($line =~ /[\$|@\%]+/) {
		$line =~ s/[\$\@\%]+//g;	
	}
	return $line;
}

sub has_variable {
	my $line = $_[0];
	if ($line =~ /[\$|@\%]+/) {
		return 1;
	}
	return 0;
}

sub handle_print {
	my $line = $_[0];
	$line =~ s/\\[rn]//g;
	my @line_content = ();
	my ($spaces) = $line =~ /(\s*print)/;
	# print $spaces;
	push @line_content, $spaces;
	$line =~ s/$spaces//;
	my @components = split(/,\s|\.\s/, $line);
	# print @components;
	foreach my $c (@components) {
		my ($inside_quotes) = $c =~ /"(.*?)"/;
		my @words = split(/\s/, $inside_quotes);
		my $string = "";
		my $var = "";
		my $was_variable = 0;
		my $was_string = 0;
		foreach my $w (@words) {
			if (has_variable($w)) {
				$w = handle_variable($w);
				$var .= "," if ($was_string);
				$var .= " $w";
				push @line_content, $var;
				$was_variable = 1;
			} else {
				$string .= "," if ($was_variable);
				$string .= " $w";
			}
		}
		push @line_content, $string;
	}
	print @line_content;
}

sub set_up_syntax_table {
	$syntax_table{"<STDIN>"} = "sys.stdin.readline()";
	
	# logical operators
	$syntax_table{"eq"} = "==";
	$syntax_table{"ne"} = "!=";
	$syntax_table{"lt"} = "<";
	$syntax_table{"le"} = "<=";
	$syntax_table{"gt"} = ">";
	$syntax_table{"ge"} = ">=";
}