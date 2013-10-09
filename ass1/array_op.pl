#!/usr/bin/perl -w

@a = (6, 7, 8);
push @a, 9;
pop @a;
unshift @a, 5;
shift @a;

@c = (1, 2, 3);
@c2 = (@c, (4, 5, 6));
push @c, (4,5,6);
@c2 = reverse @c;

@a = 1..10;

$b = pop @a;
print $b;