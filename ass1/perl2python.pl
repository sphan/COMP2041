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
my $line_count = 0;
my $unsure_line = 0;

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
	$line_count++;
	if ($line =~ /\#!\/usr\/bin\/perl -w/) {
		$header_content .= "#!/usr/bin/python2.7 -u\n";
		$line_count--;
	# handle print statements
	} elsif ($line =~ /^\s*print/) {
		handle_print($line);
	# handle if else statements and while statements
	} elsif ($line =~ /^\s*if/ || $line =~ /\}\s*else/ || $line =~ /elsif/ || $line =~ /^\s*while/) {
		handle_if_while($line);
	# skip if line is '}'
	} elsif ($line =~ "}") {
		return;
	# handle lines with chomp
	} elsif ($line =~ /chomp/) {
		handle_chomp($line);
	# handle lines with splits in them
	} elsif ($line =~ /split/) {
		handle_split($line);
	# handle for loops
	} elsif ($line =~ /foreach/ || $line =~ /for/) {
		handle_for_loop($line);
	# handle basic array operations such as push, pop
	} elsif ($line =~ /push|pop|shift|unshift|reverse/) {
		$line = handle_array_op($line);
		$line .= "\n";
		push @main_content, $line;
	# handle arrays
	} elsif ($line =~ /\@/) {
		$line = handle_array($line);
		$line .= "\n";
		push @main_content, $line;
	# handle hashes
	} elsif ($line =~ /delete\s*\$\w+\{.*?\}/ || $line =~ /\%\w+/ || $line =~ /\$\w+\{.*?\}/) {
		$line = handle_hash($line);
		$line .= "\n";
		push @main_content, $line;
	# handle regex
	} elsif ($line =~ /\=\~/) {
		handle_regex($line);
	# handle lines with join
	} elsif ($line =~ /join/) {
		$line = handle_join($line);
		$line .= "\n";
		push @main_content, $line;
	# handle lines with incrementations and decrementations
	} elsif ($line =~ /\+\+/ || $line =~ /\-\-/) {
		$line = handle_crement($line);
		$line .= "\n";
		push @main_content, $line;
	# handle lines with no reserved words at all
	} else {
		my ($spaces) = $line =~ /(\s*)\w/;
		my @line_content = ();
		my @components = split(/\s/, $line);
		if ($line =~ /\%\w+/ || $line =~ /\$\w+\{.*?\}/) {
			$line = handle_hash($line);
			push @main_content, $line;
			return;
		}
		foreach my $c (@components) {
			if (exists $syntax_table{$c}) {
				push @line_content, $syntax_table{$c};
				handle_imports("sys") if ($syntax_table{$c} =~ /sys/);
			} else {
				$c = handle_variable($c);
				push @line_content, "$c";
			}
		}
		@line_content = join(" ", @line_content);
		push @line_content, "\n";
		push @main_content, @line_content;
		$unsure_line = $line_count;
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
		$sys_imported = 1;
	} elsif ($lib eq "re") {
		$header_content .= "import re\n" if (!$re_imported);
		$re_imported = 1;
	} elsif ($lib eq "fileinput") {
		$header_content .= "import fileinput\n" if (!$fileinput_imported);
		$fileinput_imported = 1;
	}
}

sub handle_crement {
	my $line = $_[0];
	my $str = "";
	my ($space) = $line =~ /(\s*)/;
	my ($var) = $line =~ /[\$\%\@](\w+)/;
	if ($line =~ /\+\+/) {
		$str .= $space . $var . " += 1";
	} elsif ($line =~ /\-\-/) {
		$str .= $space . $var . " -= 1";
	}
	return $str;
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
	push @main_content, @line_content;
}

# need to come back
# TODO:
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
	if ($delimiter && $delimiter !~ /\\s+/) {
		push @line_content, "re.split(\'$delimiter\', $components[1])";
	} else {
		push @line_content, $components[1];
		push @line_content, ".split()";
	}
	push @line_content, "\n";
	push @main_content, @line_content;
}

sub handle_regex {
	my $line = $_[0];
	handle_imports("re");
	my @line_content = ();
	my ($space) = $line =~ /(\s*)/;
	my ($var) = $line =~ /(\w+)\s+=~/;
	my ($command) = $line =~ /(\w+)\/.*?\//;
	my ($pattern, $replace_str, $flags);
	push @line_content, $space;
	if ($var) {
		push @line_content, "$var = ";
	}
	push @line_content, "re.";
	# print $command;
	if ($command && $command =~ /s/) {
		($pattern, $replace_str, $flags) = $line =~ /\/(.*?)\/(.*?)\/(.*?)/;
		($flags) = $line =~ /\/\/(.*)/;
		push @line_content, "sub";
	} elsif ($command && $command eq "") {
		($pattern, $flags) = $line =~ /\/(.*?)\/(.*?)/;
		push @line_content, "search";
	}
	push @line_content, "(";
	push @line_content, "r\'$pattern\'";
	if ($command =~ /s/) {
		push @line_content, ", \'$replace_str\'";
	}
	push @line_content, ", $var";
	push @line_content, ")";
	push @line_content, "\n";
	push @main_content, @line_content;
}

sub handle_array_op {
	my $line = $_[0];
	$line = handle_variable($line);
	my $string = "";
	my ($op, $varFrom, $value);
	my ($space) = $line =~ /(\s*)\w/;
	my ($varTo) = $line =~ /(\w+)\s*\=\s*/;
	if ($varTo) {
		($op, $varFrom) = $line =~ /\w+\s*\=\s*(\w+)\s*(\w+)/;
		($value) = $line =~ /, (.*)/;
	} else {
		($op, $varFrom) = $line =~ /(\w+)\s*(\w+)/;
		($value) = $line =~ /, (.*)/;
	}
	
	if ($varTo) {
		$string .= $space . $varTo . " = ";
	}
	$string .= $varFrom;
	if ($value && $value =~ /\(.*?\)/) {
		$value =~ tr/\(\)/\[\]/;
		$string .= ".extend";
	} elsif (exists $syntax_table{$op}) {
		$string .= ".$syntax_table{$op}";
	}
	
	$value = '0, ' . "$value" if ($op =~ /unshift/);
	$value = "0" if ($op =~ /\s+shift\s+/);
	if ($value) {
		$string .= "($value)";
	} else {
		if ($op =~ /\s+shift\s+/) {
			$string .= "(0)";
		} else {
			$string .= "()";
		}
	}
	return $string;
}

sub handle_array {
	my $line = $_[0];
	$line = handle_variable($line);
	$line =~ tr/\(\)/\[\]/;
	if ($line =~ /\.\./) {
		my ($from, $to) = $line =~ /(\w+)\.\.(\w+)/;
		$to++;
		$line =~ s/(\w+)\.\.(\w+)/range\($from, $to\)/;
	}
	return $line;
}

sub handle_hash {
	my $line = $_[0];
	if ($line =~ /\$\w+\{.*?\}/) {
		$line =~ tr/\{\}/\[\]/;
	}
	$line =~ tr/\(\)/\{\}/;
	$line =~ tr/\"/\'/;
	$line =~ s/=>/:/g;
	$line = handle_variable($line);
	my ($space) = $line =~ /(\s*)\w+/;
	
	if ($line =~ /exists/) {
		my ($ele) = $line =~ /[\"\'](.*?)[\"\']/;
		my ($var) = $line =~ /(\w+)\[.*?\]/;
		$line = $space . "\'$ele\'" . " in $var";
	} elsif ($line =~ /delete/) {
		$line =~ s/delete/del/g;
		print $line;
	} elsif ($line =~ /keys/) {
		my ($var) = $line =~ /keys\s*(\w+)/;
		$line = $space . "$var.keys()";
	} elsif ($line =~ /values/) {
		print $line;
		my ($var) = /values\s*(\w+)/;
		$line = $space . "$var.values()";
	}
	return $line;
}

sub handle_if_while {
	my $line = $_[0];
	my @line_content = ();
	$line =~ s/\}\s//;
	$line =~ s/elsif/elif/;
	my ($space) = $line =~ /(\s*)\w+/;
	$line =~ s/$space\s*//;
	push @line_content, $space if ($space ne "");
	if ($line =~ /\<\>/) {
		my $var = $line =~ /\$(\w+)/;
		push @line_content, "for ";
		push @line_content, "$var in fileinput.input()";
		push @line_content, ":\n";
		handle_imports("fileinput");
	} elsif ($line =~ /<STDIN>/) {
		my $var = $line =~ /\$(\w+)/;
		push @line_content, "for ";
		push @line_content, "$var in sys.stdin";
		push @line_content, ":\n";
		handle_imports("sys");
	} else {
		my ($condition) = $line =~ /\((.*?)\)/;
		push @line_content, $line =~ /\s*(\w+)/;
		$line =~ s/$condition//;
		# print $condition;
		if ($condition =~ /exists/) {
			$condition = handle_hash($condition);
			push @line_content, $condition;
		} else {
			my @components = split(/\s/, $condition);
			foreach my $c (@components) {
				if (exists $syntax_table{$c}) {
					push @line_content, $syntax_table{$c};
					handle_imports("sys") if ($syntax_table{$c} =~ /sys/);
				} else {
					push @line_content, handle_variable($c);
				}
			}
		}
		@line_content = join(" ", @line_content);
		push @line_content, ":" if ($line =~ /\s*{/);
		push @line_content, "\n";
	}
	push @main_content, @line_content;
}

sub handle_for_loop {
	my $line = $_[0];
	my @line_content = ();
	my ($thing_to_loop) = $line =~ /\((.*?)\)/;
	my ($space) = $line =~ /(\s*)\w/;
	push @line_content, $space if ($space ne "");
	push @line_content, "for";
	if ($thing_to_loop =~ /.*;.*;.*/) { # handle for loops in form of 'for ($i = 0; $i < 5; $i++)'
		
	} else { # handle for loops in form of 'foreach $i (@arr)'
		my @vars = $line =~ /[foreach|for]\s(.*?)\s\(/;
		foreach (@vars) {
			$_ = handle_variable($_);
			push @line_content, $_;
		}
		push @line_content, "in";
		if ($thing_to_loop =~ /\.\./) {
			my ($start, $end) = $thing_to_loop =~ /(\w+)\.\.(\w+)/;
			my $var = "";
			if ($end =~ /\d+/) {
				$end += 1;
			} elsif ($end =~ /\$\#/) {
				$var = $end =~ /\$\#(\w+)/;
				if (exists $syntax_table{$var}) {
					$var = $syntax_table{$var};
				}
				$var = "xrange(len($var) - 1)";
			}
			if ($var) {
				push @line_content, $var;
			} else {
				push @line_content, "xrange($start, $end)";
			}
		} elsif ($thing_to_loop =~ /\w+\,\w+\,/) {
			push @line_content, '[' . $thing_to_loop . ']';
		} elsif ($thing_to_loop =~ /keys\s*\%\w+/) {
			push @line_content, handle_hash($thing_to_loop);
		} else {
			if (exists $syntax_table{$thing_to_loop}) {
				push @line_content, $syntax_table{$thing_to_loop};
			} else {
				push @line_content, handle_variable($thing_to_loop);
			}
		}
	}
	@line_content = join(" ", @line_content);
	push @line_content, ":";
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
	my ($space) = $line =~ /(\s*print)/;
	# print $spaces;
	push @line_content, $space if ($space ne "");
	$line =~ s/$space//;
	if ($line =~ /join\(.*?\)/) {
		my $string = handle_join($line);
		$line =~ s/join\(.*?\)//;
		push @line_content, $string;
	}
	my @components = split(/,\s|\.\s/, $line);
	# print @components;
	foreach my $c (@components) {
		if ($c =~ /\$\w+\{.*?\}/) {
			$c = handle_hash($c);
			push @line_content, $c;
			next;
		}
		my ($inside_quotes) = $c =~ /"(.*?)"/;
		if ($inside_quotes) {
			my @words = split(/\s/, $inside_quotes);
			my @string = ();
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
					push @line_content, "," if ($was_variable);
					push @string, "$w";
					$was_string = 1;
					$was_variable = 0;
				}
			}
			@string = join(" ", @string);
			push @line_content, "\"@string\"" if (@string);
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
	$syntax_table{'ARGV'} = "sys.argv[1:]";
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
	
	# string concatination
	$syntax_table{"."} = "+";
	
	$syntax_table{"undef"} = "None";
	$syntax_table{"foreach"} = "for";
	
	$syntax_table{"push"} = "append";
	$syntax_table{"pop"} = "pop";
	$syntax_table{"shift"} = "shift";
	$syntax_table{"unshift"} = "unshift";
	$syntax_table{"reverse"} = "reverse";
}