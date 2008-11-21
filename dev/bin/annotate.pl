#!perl

use strict;
use IO::All;
use XXX;

my @perl_paths = map $_->name, io('lib')->All_Files;

my %perl_python_paths = map {
    my $perl = $_;
    my $python = $perl;
    $python =~ s/\.pm$//;
    $python =~ s!lib/YAML/Perl/?!!;
    $python ||= '__init__';
    $python = lc($python);
    $python = "pyyaml/lib/yaml/$python.py";
    -f $python ? ($perl, $python) : ();
} @perl_paths;

XXX \%perl_python_paths;
