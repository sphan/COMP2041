#!/usr/bin/perl -w
use strict;
use warnings;

my $input_file = "";
my $header_content = "";
my $main_content = "";
my %syntax_table = ();
# flag to see if sys or re (libraries) is imported or not
my $sys_imported = 0;
my $re_imported = 0;
my $fileinput_imported = 0;

if (@ARGV > 0) {
	$input_file = $ARGV[0];
	read_from_file();
} else {
	main(<STDIN>);
	read_from_stdin();
}

sub read_from_file {
	open(F, "<$input_file") or die "Cannot open $input_file";
	while (my $line = <F>) {
		main($line);
	}
	print $header_content . $main_content;
}

sub read_from_stdin {
	while (my $line = <STDIN>) {
		main($line);
	}
	print $header_content . $main_content;
}

sub main {
	set_up_syntax_table();
	my $line = $_[0];
	$line =~ s/;$//;
	if ($line =~ /#!\/usr\/bin\/perl/) {
		$header_content .= "#!/usr/bin/python2.7 -u\n";
	} elsif ($line =~ /^\s*print/) {
		handle_print($line);
	} elsif ($line =~ /^\s*\#/ || $line =~ /^\s*$/) {
		$main_content .= $line;
	} elsif ($line =~ /^\s*if/ || $line =~ /^\s*while/) {
		handle_if_while($line);
	} elsif ($line =~ /}/) {
#		next;
	} elsif ($line =~ /.*?\+\+/ || $line =~ /.*?\-\-/) {
		handle_crementation($line);
	} elsif ($line =~ /.*\=\~/) {
		handle_regex($line);
	} elsif ($line =~ /push|pop|shift|unshift|reverse/) {
		handle_array_op($line);
	} elsif ($line =~ /STDIN/) {
		handle_stdin($line);
	} elsif ($line =~ /chomp/) {
		handle_chomp($line);
	} elsif ($line =~ /join\(.*?\)/) {
		handle_join($line);
	} elsif ($line =~ /^\s*foreach/ || $line =~ /^\s*for/) {
		handle_for_loops($line);
	} elsif ($line =~ /^@\w+/ || $line =~ /\$\#\w+/ || $line =~ /scalar\(\@\w+\)/) {
		handle_array($line);
	} else {
		$line = handle_variable($line);
		$line =~ s/last/break/g;
		$line =~ s/next/continue/g;
		$main_content .= $line;
	}
}

sub handle_variable {
	my $line = $_[0];
	if ($line =~ /[\$\@\%]+/) {
		$line =~ s/[\$\@\%]+//g;
	}
	return $line;
}

sub has_variable {
	my $line = $_[0];
	if ($line =~ /[\$\@\%]+/) {
		return 1;
	}
	return 0;
}

sub handle_imports {
	my $lib = $_[0];
	if ($lib =~ /sys/) {
		if ($sys_imported == 0) {
			$header_content .= "import sys\n";
			$sys_imported = 1;
		}
	} elsif ($lib =~ /re/) {
		next if ($re_imported != 0);
		$header_content .= "import re\n";
		$re_imported = 1;
	} elsif ($lib =~ /fileinput/) {
		next if ($fileinput_imported != 0);
		$header_content .= "import fileinput\n";
		$fileinput_imported = 1;
	}
}

sub handle_chomp {
	my $line = $_[0];
	$line = handle_variable($line);
	my @contents = split(/\s+/, $line);
	my $var = $contents[2];
	my ($spaces) = $line =~ /(\s*)chomp/;
	$main_content .= "$spaces$var = $var.rstrip()\n";
}

sub handle_stdin {
	my $line = $_[0];
	$line = handle_variable($line);
	$line =~ s/<STDIN>/sys.stdin.readline()/;
	handle_imports("sys");
	$main_content .= $line;
}

sub handle_array_op {
	my $line = $_[0];
	$line = handle_variable($line);
	my @components = split(/[\s]+/, $line);
	$main_content .= $components[1] . ".";
	if ($components[2] && $components[2] =~ /\(.*?\)/) {
		$main_content .= "extend";
	} else {
		if (exists $syntax_table{$components[0]}) {
			$main_content .= $syntax_table{$components[0]};
		}
	}
	if ($components[2] && $components[2] =~ /\(.*?\)/) {
		$components[2] =~ tr/\(\)/\[\]/;
	} elsif ($components[0] =~ /unshift/) {
		$components[2] = "0, $components[2]";
	} elsif ($components[0] =~ /shift/) {
		$components[2] = 0;
	}
	$main_content .= "($components[2])\n";
}

sub handle_array {
	my $line = $_[0];
	if ($line =~ /\$\#\w+/ || $line =~ /scalar\(\@\w+\)/) {
		my ($var) = $line =~ /\$\#(\w+)|.*\@(\w+)/;
		$line = "len($var)";
	}
	$line = handle_variable($line);
	$line =~ tr/\(\)/\[\]/;
	$main_content .= $line . "\n";
}

sub handle_crementation {
	my $line = $_[0];
	my ($spaces) = $line=~ /(\s*).*/;
	my ($var) = $line =~ /\$(\w+)/;
	if ($line =~ /\+\+/) {
		$main_content .= $spaces . $var . " += 1\n";
	} elsif ($line =~ /\-\-/) {
		$main_content .= $spaces . $var . " -= 1\n";
	}
}

sub handle_if_while {
	my $line = $_[0];
	$line = handle_variable($line);
	$line =~ s/(\)|\()//g;
	my @subContents = split(/ /, $line);
	if ($line =~ /<>/) {
		$main_content .= "for $subContents[1] in fileinput.input():\n";
		handle_imports("fileinput");
		return;
	} elsif ($line =~ /<STDIN>/) {
		$main_content .= "for $subContents[1] in sys.stdin:\n";
		handle_imports("sys");
		return;
	}
	$line =~ s/ {/:/g;
	my $count = 1;
	foreach my $s (@subContents) {
		if (exists $syntax_table{$s}) {
			$s = $syntax_table{$s};
		}
		$main_content .= $s;
		if ($count != @subContents) {
			$main_content .= " ";
		}
		$count += 1;
	}
}

sub handle_for_loops {
	my $line = $_[0];
	my ($var_to_loop) = $line =~ /for.*\((.*)\)\s*{/;
	my $spaces = "";
	my $temp;
	if (($spaces) = $line =~ /(\s*)foreach/) {
		$temp = $spaces;
	}
	$temp .= "for ";
	if ($var_to_loop =~ /.*;.*;.*/) {
		my ($var) = $var_to_loop =~ /\$(\w+).*/;
		my ($from, $to) = $var_to_loop =~ /(\d+);.*?(\d+);.*?/;
		$main_content .= $temp . "$var in xrange($from, $to):\n";
		return;
	} else {
		my ($args) = $line =~ /foreach\s*(.*)\s*\(.*\)\s*\{/;
		my @vars = split(/\s+/, $args);
		for (my $i = 0; $i < @vars; $i += 1) {
			$temp .= handle_variable($vars[$i]);
			$temp .= ", " if (@vars > 1 && $i + 1 != @vars);
			$temp .= " ";
		}
	}
	if ($var_to_loop =~ /(\d+)..(\d+)/) {
		my $to = $2 + 1;
		$temp .= "in xrange ($1, $to):";
	} elsif (exists $syntax_table{$var_to_loop}) {
		$temp .= "in $syntax_table{$var_to_loop}:";
		handle_imports("sys") if ($syntax_table{$var_to_loop} =~ /sys/);
	} elsif ($var_to_loop =~ /\$\w+/) {
		$temp .= handle_variable($var_to_loop) . ":";
	}
	$main_content .= $temp . "\n";
}

sub handle_regex {
	my $line = $_[0];
	my ($pattern, $replaceStr, $flag);
	my ($spaces) = $line =~ /(\s*).*/;
	my ($var) = $line =~ /\$(\w+)/;
	$main_content .= $spaces . $var . " = ";
	my ($command) = $line =~ /(\w*)\/.*?\//;
	handle_imports("re");
	if ($command eq "qw") {
		($pattern) = $line =~ /qw\{(.*?)\}/;
	} elsif ($command ne "") {
		($pattern, $replaceStr, $flag) = $line =~ /\w*\/(.*?)\/(.*?)\/(\w*)/;
	} else {
		my ($pattern, $flag) = $line =~ /\w*\/(.*?)\/(\w*)/;
	}
	if ($command =~ /s/) {
		$main_content .= "re.sub(r\'$pattern\', \'$replaceStr\', $var)\n";
	} elsif ($command =~ /qw/) {
		$main_content .= "re.compile(\'$pattern\')\n";
	} elsif ($command eq "") {
		if (length($flag) > 1) {
#			my @flags = split(//, $flag);
		} else {
	
		}
	}
}

sub handle_join {
	my $line = $_[0];
	my ($content) = $line =~ /\((.*?)\)/;
	my @subContents = split(/,\s*/, $content);
	my $delimiter = $subContents[0];
	$main_content .= "$delimiter.join(";
	my $temp = "";
	for (my $i = 1; $i < @subContents; $i += 1) {
		if (exists $syntax_table{$subContents[$i]}) {
			$temp .= $syntax_table{$subContents[$i]};
			handle_imports("sys") if ($syntax_table{$subContents[$i]} =~ /sys/);
		} else {
			$temp .= $subContents[$i];
		}
		next if (@subContents == 2 || $i + 1 == @subContents);
		$temp .= ", ";
	}
	if (@subContents > 2) {
		$main_content .= "[$temp])\n";
	} else {
		$main_content .= $temp . ")\n";
	}
}

sub handle_print {
	my $line = $_[0];
	$line =~ s/\\[rn]//g;
	my ($spaces) = $line =~ /(\s*print\s*)/;
	$line =~ s/\s*print\s*//g;
	$main_content .= $spaces;
	if ($line =~ /join\(.*?\)/) {
		handle_join($line);
		return;
	}
	my @parts = split(/(, )|(\. )/, $line);
	my $count = 0;
	foreach my $p (@parts) {
		if (has_variable($p)) {
			$p = handle_variable($p);
			$p =~ s/\"//g;
		} elsif ($count > 0 && $p !~ "\"\"") {
			$main_content .= ", ";
		}
		next if ($p =~ "\"\"");
		$main_content .= $p;
		$count += 1;
	}
}

sub set_up_syntax_table {
	$syntax_table{'@ARGV'} = "sys.argv[1:]";
	$syntax_table{"last"} = "break";
	$syntax_table{"next"} = "continue";
	$syntax_table{"foreach"} = "for";
	$syntax_table{"{"} = ":";

	# compound assignment
	$syntax_table{"/="} = "//=";
	$syntax_table{".="} = "+=";
	$syntax_table{"x="} = "*=";
	$syntax_table{"&&="} = "&=";
	$syntax_table{"||="} = "|=";
	$syntax_table{"^="} = "^+=";

	# comparison operators
	$syntax_table{"eq"} = "==";
	$syntax_table{"ne"} = "!=";
	$syntax_table{"lt"} = "<";
	$syntax_table{"le"} = "<=";
	$syntax_table{"gt"} = ">";
	$syntax_table{"ge"} = ">=";

	#logical operators
	$syntax_table{"&&"} = "and";
	$syntax_table{"||"} = "or";
	$syntax_table{"!"} = "not";

	# array operatation
	$syntax_table{"push"} = "append";
	$syntax_table{"pop"} = "pop";
	$syntax_table{"unshift"} = "insert";
	$syntax_table{"shift"} = "pop";
	$syntax_table{"reverse"} = "reverse";
}
