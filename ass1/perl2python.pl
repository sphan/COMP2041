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
	} elsif ($line =~ /^\s*if/ || $line =~ /else/ || $line =~ /elsif/ || $line =~ /^\s*while/) {
		handle_if_while($line);
	# skip if line is '}'
	} elsif ($line =~ "}") {
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
	# handle regex
	} elsif ($line =~ /\@/) {
		$line = handle_array($line);
		$line .= "\n";
		push @main_content, $line;
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
		# my %index;
		# @index{@main_content} = (0..$#main_content);
		# my $index = $index{\@line_content};
		# print $index, "\n";
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
	if ($delimiter !~ /\\s+/) {
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
	my ($space) = $line =~ /(\s*)\w/;
	my ($op, $var2) =~ /\s*=\s*(\w+)\s*(\w+)/;
	# print $var1 if ($var1);
	print $op, $var2;
	# my @components = split(/[\s]+/, $line);
	# $components[1] =~ s/,//g;
	# $string .= $space;
	# if ($line =~ /reverse/ && @components == 2) {
		# $string .= $components[1] . ".[::-1]";
	# } elsif ($line =~ /reverse/ && @components > 2) {
		# $string .= "$components[0] = " . $components[3] . ".reverse()";
	# } elsif ($components[2] && $components[2] =~ /\(.*?\)/) {
		# $components[2] =~ tr/\(\)/\[\]/;
		# $string .= "$components[1].extend";
	# } else {
		# if (exists $syntax_table{$components[0]}) {
			# $string .= "$components[1].$syntax_table{$components[0]}";
		# }
	# }
	# $components[2] = "0, $components[2]" if ($components[0] =~ /unshift/);
	# $components[2] = 0 if ($components[0] =~ /shift/);
	# $string .= "($components[2])" if ($components[2] && $line !~ /reverse/);
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

sub handle_if_while {
	my $line = $_[0];
	my @line_content = ();
	$line =~ s/\}\s//;
	$line =~ s/elsif/elif/;
	my ($space) = $line =~ /(\s*)\w+/;
	$line =~ s/$space\s*//;
	push @line_content, $space;
	# print $line;
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
		my @components = split(/\s/, $condition);
		foreach my $c (@components) {
			if (exists $syntax_table{$c}) {
				push @line_content, $syntax_table{$c};
				handle_imports("sys") if ($syntax_table{$c} =~ /sys/);
			} else {
				push @line_content, handle_variable($c);
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
	push @line_content, $space;
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
}