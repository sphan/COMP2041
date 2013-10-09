#!/usr/bin/perl -w

$string = "do re mi fa";
split(/\s+/, $string);

@strs = split(/\s+/, $string);

@strs = split(/(\s+)/, $string);