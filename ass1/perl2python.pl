#!/usr/bin/perl -w
use strict;
use warnings;

my $input_file = "";
my $header_content = "";
my $main_content = "";
my %syntax_table = ();

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
			eval $syntax_table{"print"};
		} elsif ($line =~ /^\s*\#/ || $line =~ /^\s*$/) {
			$main_content .= $line;
		} else {
			$line = handle_variable($line);
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

sub handle_if_while {
	my $line = $_[0];
	$line = handle_variable($line);
	$line =~ s/\(\)//g;
	$line =~ s/ {/:/g;
	$main_content .= $line;
}

sub handle_print {
	my $line = $_[0];
	$line =~ s/\\[rn]//g;
	$line =~ s/\s*print\s*//g;
	$main_content .= "print ";
	print $line;
	my @parts = split(/, /, $line);
	my $count = 0;
	foreach my $p (@parts) {
		if (has_variable($p)) {
			$p = handle_variable($p);
			$p =~ s/\"//g;
		} elsif ($count > 0 && $p ne "\"\"") {
			$main_content .= ", ";
		}
		next if ($p eq "\"\"");
		$main_content .= $p;
		$count += 1;
	}
}

sub set_up_syntax_table {
	$syntax_table{"print"} = 'handle_print($line)';
	$syntax_table{"eq"} = "==";
	$syntax_table{"ne"} = "!=";
}
