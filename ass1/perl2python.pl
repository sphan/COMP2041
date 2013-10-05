#!/usr/bin/perl -w
use strict;
use warnings;

# variables
my $input_file = "";
my %syntax_table = ();
my $output_content = "";

if (@ARGV > 0) {
	$input_file = $ARGV[0];
}

set_up_syntax_table();

# open the file
open(F, "<$input_file") or die "Cannot open $input_file";
# read the file
while (my $line = <F>) {
	if ($line =~ /#!\/usr\/bin\/perl/) {
		$output_content .= "#!/usr/bin/python2.7 -u\n";
	} else {
		# remove any semicolon at end of line
		$line = remove_semicolon($line);
		# split line up by "" into tokens
		my @tokens = split(/("[^"]*")/, $line);
		foreach my $token (@tokens) {
			# remove any \n character
			$token = remove_newline($token);
			$token =~ s/(\)|\()//g;
			$token =~ s/\s\{/\:/g;
			$token =~ s/\}//g;
#			print $token;
			if ($token !~ /(".*?")/) { 
				# look for the corresponding Python syntax
				# for the token
				my @subtokens = split(/\s/, $token);
				foreach my $t (@subtokens) {
					if (exists $syntax_table{$token}) {
						$output_content .= $syntax_table{$token};
					} elsif (has_variables($token)) {
						$token = handle_variables($token);
						$output_content .= $token;
					} else {
						$output_content .= $token;
					}
				}
			} else {
				if (has_variables($token)) {
					$token =~ s/\"//g;
					$token = handle_variables($token);
				} elsif ($token =~ /\"\"/) {
					next;
				}
				$output_content .= "$token";
			}
		}
	}
}
print $output_content;

sub set_up_syntax_table {
	$syntax_table{"print"} = "print";
	$syntax_table{"while"} = "while";
	$syntax_table{"<STDIN>"} = "sys.stdin.readline()";
	$syntax_table{"eq"} = "==";
	$syntax_table{"lt"} = "<";
	$syntax_table{"gt"} = ">";
	$syntax_table{"ge"} = ">=";
	$syntax_table{"le"} = "<=";
	$syntax_table{"ne"} = "!=";
	$syntax_table{"=="} = "==";
	$syntax_table{"<"} = "<";
	$syntax_table{">"} = ">";
	$syntax_table{">="} = ">=";
	$syntax_table{"<="} = "<=";
	$syntax_table{"!="} = "!=";
	$syntax_table{"{"} = ":";
	$syntax_table{".="} = "+=";
	$syntax_table{"&&"} = "and";
	$syntax_table{"||"} = "or";
	$syntax_table{"!"} = "not";
	$syntax_table{"}"} = "";
	$syntax_table{"last"} = "break";
	$syntax_table{"next"} = "continue";
	$syntax_table{"if"} = "if";
	$syntax_table{"elsif"} = "elif";
	$syntax_table{"foreach"} = "for";
}

sub handle_variables {
	my $var = $_[0];
	if ($var =~ /[\$\@\%]\w+/) {
		$var =~ s/[\$\@\%]//g;
	}
	return $var;
}

# return true if the given string
# contains a variable, false otherwise.
sub has_variables {
	my $var = $_[0];
	if ($var =~ /[\$\@\%]\w+/) {
		return 1;
	}
	return 0;
}

sub remove_newline {
	my $t = $_[0];
	$t =~ s!\\[rn]?!!g;
	return $t;
}

sub remove_semicolon {
	my $line = $_[0];
	$line =~ s/;//;
	return $line;
}
