#!/usr/bin/perl

use strict;

use File::Basename;
use File::Find qw(find);
use File::Spec::Functions qw(rel2abs catfile);
use Test::More;

my $thisdir = dirname(rel2abs(__FILE__));
my $libpath = catfile($thisdir, '../lib');

my @tests;
map {
    find(sub {
        push @tests, $File::Find::name if(-f $_ && /(:(\.pl)|(\.pm)|(\.t))$/) ;
    }, catfile($thisdir, $_));
} qw(../bin ../lib);

for (@tests) {
    my $output = `perl -I "$libpath" -c $_ 2>&1`;
    my $ok = ($? >> 8 == 0);
    print $output unless $ok;
    ok($ok, "$_ syntax check");
}

done_testing();