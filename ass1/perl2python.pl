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

main();

sub main {
	if (@ARGV > 0) {
		$input_file = $ARGV[0];
	}
	set_up_syntax_table();
	open(F, "<$input_file") or die "Cannot open $input_file";
	while (my $line = <F>) {
		$line =~ s/;$//;
		if ($line =~ /#!\/usr\/bin\/perl/) {
			$header_content .= "#!/usr/bin/python2.7 -u\n";
		} elsif ($line =~ /print/) {
			handle_print($line);
		} elsif ($line =~ /^\s*\#/ || $line =~ /^\s*$/) {
			$main_content .= $line;
		} elsif ($line =~ /if/ || $line =~ /while/) {
			handle_if_while($line);
		} elsif ($line =~ /}/) {
			next;
		} elsif ($line =~ /STDIN/) {
			handle_stdin($line);
		} elsif ($line =~ /chomp/) {
			handle_chomp($line);
		} else {
			$line = handle_variable($line);
			$line =~ s/last/break/g;
			$line =~ s/next/continue/g;
			$main_content .= $line;
		}
	}
	print $header_content . $main_content;
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
	if ($sys_imported == 0) {
		$header_content .= "import sys\n";
		$sys_imported = 1;
	}
	$main_content .= $line;
}

sub handle_if_while {
	my $line = $_[0];
	$line = handle_variable($line);
	$line =~ s/(\)|\()//g;
	$line =~ s/ {/:/g;
	my @subContents = split(/ /, $line);
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

sub handle_join {
	
}

sub handle_print {
	my $line = $_[0];
	$line =~ s/\\[rn]//g;
	my ($spaces) = $line =~ /(\s*print\s*)/;
	$line =~ s/\s*print\s*//g;
	$main_content .= $spaces;
	print $line;
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


	# compound assignment
#	$syntax_table{"+="} = "+=";
#	$syntax_table{"-="} = "-=";
#	$syntax_table{"*="} = "*=";
	$syntax_table{"/="} = "//=";
#	$syntax_table{"**="} = "**=";
	$syntax_table{".="} = "+=";
	$syntax_table{"x="} = "*=";
	$syntax_table{"&&="} = "&=";
	$syntax_table{"||="} = "|=";
	$syntax_table{"^="} = "^+=";
#	$syntax_table{"<<="} = "<<=";
#	$syntax_table{">>="} = ">>=";
#	$syntax_table{"&="} = "&=";
#	$syntax_table{"|="} = "|=";
#	$syntax_table{"^="} = "^=";

	# comparison operators
#	$syntax_table{"=="} = "==";
#	$syntax_table{"!="} = "!=";
#	$syntax_table{"<"} = "<";
#	$syntax_table{"<="} = "<=";
#	$syntax_table{">"} = ">";
#	$syntax_table{">="} = ">=";
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
}
