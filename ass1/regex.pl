#!/usr/bin/perl -w

$string = "hello world";
print $string . "\n";

$string =~ /hello/g;
print $string . "\n";

$string =~ s/world/Sandy/g;
print $string . "\n";