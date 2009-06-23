package t::Bridge;
use strict;
use warnings;

use base 'TestML::Bridge';
use YAML::Perl;

sub eval {
    my $self = shift;
    eval($self->value);
}

sub dump_yaml {
    my $self = shift;
    return YAML::Perl::Dump($self->value);
}

1;
