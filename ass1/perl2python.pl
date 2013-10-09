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
	print_output();
}

sub read_from_stdin {
	while (my $line = <STDIN>) {
		main($line);	
	}
	print_output();
}

sub main {
	my $line = $_[0];
	$line =~ s/;$//g;
	if ($line =~ /\#!\/usr\/bin\/perl -w/) {
		$header_content .= "#!/usr/bin/python2.7 -u\n";
	} elsif ($line =~ /^\s*print/) {
		handle_print($line);
	} elsif ($line =~ /^\s*if/ || $line =~ /else/ || $line =~ /elsif/ || $line =~ /^\s*while/) {
		handle_if_while($line);
	} elsif ($line =~ "}") {
	} else {
		my ($spaces) = $line =~ /(\s*)\w/;
		my @line_content = ();
		my @components = split(/\s/, $line);
		foreach my $c (@components) {
			if (exists $syntax_table{$c}) {
				push @line_content, "$c";
			} else {
				$c = handle_variable($c);
				push @line_content, "$c";
			}
		}
		@line_content = join(" ", @line_content);
		push @line_content, "\n";
		push @main_content, @line_content;
	}
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

sub handle_if_while {
	my $line = $_[0];
	my @line_content = ();
	$line =~ s/elsif/elif/;
	my ($space) = $line =~ /(\s*\w+)/;
	$line =~ s/$space\s*//;
	push @line_content, $space;
	my ($condition) = $line =~ /\((.*?)\)/;
	$line =~ s/$condition//;
	# print $condition;
	my @components = split(/\s/, $condition);
	foreach my $c (@components) {
		if (exists $syntax_table{$c}) {
			push @line_content, $syntax_table{$c};
		} else {
			push @line_content, handle_variable($c);
		}
	}
	@line_content = join(" ", @line_content);
	push @line_content, ":" if ($line =~ /\s*{/);
	push @line_content, "\n";
	push @main_content, @line_content;
}

sub handle_join {
	my $line = $_[0];
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
		if ($inside_quotes) {
			my @words = split(/\s/, $inside_quotes);
			my $string = "";
			my $var = "";
			my $was_variable = 0;
			my $was_string = 0;
			foreach my $w (@words) {
				if (has_variable($w)) {
					$w = handle_variable($w);
					$var .= "," if ($was_string);
					$var .= "$w";
					push @line_content, $var;
					$was_variable = 1;
				} else {
					$string .= "," if ($was_variable);
					$string .= " $w";
				}
			}
			push @line_content, "\"$string\"" if ($string);
		} else {
			push @line_content, handle_variable($c) if ($c !~ "\"\"");
		}	
	}
	@line_content = join(" ", @line_content);
	push @line_content, "\n";
	push @main_content, @line_content;
}

sub set_up_syntax_table {
	$syntax_table{"<STDIN>"} = "sys.stdin.readline()";
	$syntax_table{'@ARGV'} = "sys.argv[1:]";
	$syntax_table{"last"} = "break";
	$syntax_table{"next"} = "continue";
	
	# logical operators
	$syntax_table{"&&"} = "and";
	$syntax_table{"||"} = "or";
	$syntax_table{"!"} = "not";
	
	# comparison operators
	$syntax_table{"eq"} = "==";
	$syntax_table{"ne"} = "!=";
	$syntax_table{"lt"} = "<";
	$syntax_table{"le"} = "<=";
	$syntax_table{"gt"} = ">";
	$syntax_table{"ge"} = ">=";
	
	# compound operators
	$syntax_table{".="} = "+=";
	$syntax_table{"x="} = "*=";
	$syntax_table{"&&="} = "&=";
	$syntax_table{"||="} = "|=";
	
	$syntax_table{"undef"} = "None";
}