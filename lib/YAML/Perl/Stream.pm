package YAML::Perl::Stream;
use strict;
use warnings;

use YAML::Perl::Base -base;

# field 'value', -init => 'do { my $x = ""; \$x }';
field 'buffer';

sub open {
    my $class = shift;
    my $self = $class->new();
    my $ref = shift;
    $self->buffer($ref);
    return $self;
}

sub write {
    ${$_[0]->buffer} .= $_[1];
}

sub string {
    my $self = shift;
    return ${$self->buffer};
}

1;
