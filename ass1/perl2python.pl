#!/usr/bin/perl -w
use strict;
use warnings;

my $input_file = "";
my $header_content = "";
my @main_content = ();
my %syntax_table = ();
my $sys_imported = 0;
my $fileinput_imported = 0;
my $re_imported = 0;

if (@ARGV > 0) {
	$input_file = $ARGV[0];
	read_from_file();
} else {
	read_from_stdin();	
}

sub read_from_file {
	set_up_syntax_table();
	open(F, "<$input_file") or die "Cannot open $input_file";
	while (my $line = <F>) {
		main($line);	
	}
	print_output();
}

sub read_from_stdin {
	set_up_syntax_table();
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
	} elsif ($line =~ /chomp/) {
		handle_chomp($line);
	} elsif ($line =~ /split/) {
		handle_split($line);
	} elsif ($line =~ /foreach/ || $line =~ /for/) {
		handle_for_loop($line);
	} elsif ($line =~ /join/) {
		$line = handle_join($line);
		$line .= "\n";
		push @main_content, $line;
	} else {
		my ($spaces) = $line =~ /(\s*)\w/;
		my @line_content = ();
		my @components = split(/\s/, $line);
		foreach my $c (@components) {
			if (exists $syntax_table{$c}) {
				push @line_content, $syntax_table{$c};
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

sub handle_imports {
	my $lib = $_[0];
	if ($lib eq "sys") {
		$header_content .= "import sys\n" if (!$sys_imported);
	} elsif ($lib eq "re") {
		$header_content .= "import re\n" if (!$re_imported);
	} elsif ($lib eq "fileinput") {
		$header_content .= "import fileinput\n" if (!$fileinput_imported);
	}
}

sub handle_chomp {
	my $line = $_[0];
	my @line_content = ();
	my ($space) = $line =~ /(\s*)\w/;
	my ($var) = $line =~ /[\$\@\%](\w+)/;
	push @line_content, $space;
	push @line_content, $var;
	push @line_content, " = ";
	push @line_content, "$var.rstrip()\n";
	@line_content = join(" ", @line_content);
	push @main_content, @line_content;
}

sub handle_split {
	my $line = $_[0];
	my @line_content = ();
	my ($var) = $line =~ /\s*[\$\@\%](\w+)\s*=/;
	my ($space) = $line =~ /(\s*)\w/;
	my ($condition) = $line =~ /\((.*?)\)/;
	my @components = split(/,\s/, $condition);
	my ($delimiter) = $components[0] =~ /\/(.*?)\//;
	push @line_content, $space;
	push @line_content, "$var = " if ($var);
	push @line_content, $components[1];
	if ($delimiter =~ /\s+/) {
		push @line_content, ".split()";
	} else {
		push @line_content, ".split($delimiter)";
	}
	push @line_content, "\n";
	push @main_content, @line_content;
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
	my $string = "";
	my ($space) = $line =~ /(\s*)\w+/;
	my ($var) = $line =~ /[\$\@\%](\w+)\s*=\s*join/;
	my ($content) = $line =~ /\((.*?)\)/;
	my @subContents = split(/,\s*/, $content);
	my $delimiter = $subContents[0];
	if ($var) {
		$string .= $space . "$var = ";
	}
	$string .= $delimiter . ".join(";
	my $temp = "";
	for (my $i = 1; $i < @subContents; $i += 1) {
		if (exists $syntax_table{$subContents[$i]}) {
			$temp .= $syntax_table{$subContents[$i]};
			handle_imports("sys") if ($syntax_table{$subContents[$i]} =~ /sys/);
		} else {
			$temp .= handle_variable($subContents[$i]);
		}
		next if (@subContents == 2 || $i + 1 == @subContents);
		$temp .= ", ";
	}
	if (@subContents > 2) {
		$string .= "[$temp])";
	} else {
		$string .= "$temp)";
	}
	return $string;
}

sub handle_print {
	my $line = $_[0];
	$line =~ s/\\[rn]//g;
	my @line_content = ();
	my ($spaces) = $line =~ /(\s*print)/;
	# print $spaces;
	push @line_content, $spaces;
	$line =~ s/$spaces//;
	if ($line =~ /join\(.*?\)/) {
		my $string = handle_join($line);
		$line =~ s/join\(.*?\)//;
		push @line_content, $string;
	}
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
					$was_string = 0;
				} else {
					$string .= "," if ($was_variable);
					$string .= " $w";
					$was_string = 1;
					$was_variable = 0;
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