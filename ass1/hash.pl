#!/usr/bin/perl -w




if (exists $d{"y"}) {
    print "yes\n";
    print "no\n";
}

%hash = ("A" => 1, "B" => 2, "C" => 3, "D" => 4);
@values = values %hash;
foreach $k (keys %hash) {
    print $k . "\n";

delete $hash{"B"};
foreach $k (keys %hash) {
    print $k . "\n";
}