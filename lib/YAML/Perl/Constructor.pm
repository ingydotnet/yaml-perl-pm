# pyyaml/lib/yaml/constructor.py

package YAML::Perl::Constructor;
use strict;
use warnings;
use YAML::Perl::Processor -base;

field 'next_layer' => 'composer';

field 'composer_class', -init => '"YAML::Perl::Composer"';
field 'composer', -init => '$self->create("composer")';

sub check_data {
    my $self = shift;
    return $self->composer->check_node();
}

sub get_data {
    my $self = shift;
    return $self->composer->check_node()
    ? ($self->construct_document($self->composer->get_node()))
    : ();
}

sub construct_document {
    my $self = shift;
    my $node = shift;
    # TODO ...
    return $node;
}

1;
