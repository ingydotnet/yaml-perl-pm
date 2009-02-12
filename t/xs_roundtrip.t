use warnings;
use strict;

use Data::Dumper;
use Test::More;
use YAML::Perl ();
use YAML::XS ();
use Math::BigFloat;     # supposedly a core module

plan tests => 4;

my $f = Math::BigFloat->new (3.14159265);

my %loaders = (
    pp => sub { YAML::Perl::Load (@_) },
    xs => sub { YAML::XS::Load (@_) },
);
my %dumpers = (
    pp => sub { YAML::Perl::Dump (@_) },
    xs => sub { YAML::XS::Dump (@_) },
);

for my $dumper (keys %dumpers) {

    my $f_dump;
    eval { $f_dump = $dumpers{$dumper}->($f) };
#    diag "Exception during dumping an object with a $dumper dumper:\n\n$@" if $@;

    for my $loader (keys %loaders)  {
        my $f_load;
        eval { $f_load  = $loaders{$loader}->($f_dump) };
#           diag "Exception during processing of a $dumper dump with the $loader loader:\n\n$@" if $@;

        is_deeply ($f, $f_load, "Round trip with a $dumper dump and a $loader loader");
    }
}
