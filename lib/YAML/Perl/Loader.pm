# pyyaml/lib/yaml/loader.py

package YAML::Perl::Loader;
use strict;
use warnings;
use YAML::Perl::Processor -base;

field 'next_layer' => 'constructor';

# These fields are chained together such that you can access any lower
# level from any higher level.
field 'constructor', -init => '$self->create("constructor")';
field 'composer',    -init => '$self->constructor->composer';
field 'parser',      -init => '$self->composer->parser';
field 'scanner',     -init => '$self->parser->scanner';
field 'reader',      -init => '$self->scanner->reader';

# Setting a class name from the loader will set it in the appropriate
# class. When setting class names it is important to set the higher
# level ones first since accessing a lower level one will instantiate
# any higher level objects with their default class names.
field 'constructor_class', -init  => '"YAML::Perl::Constructor"';
field 'composer_class',    -onset => '$self->constructor->composer_class($_)';
field 'parser_class',      -onset => '$self->composer->parser_class($_)';
field 'scanner_class',     -onset => '$self->parser->scanner_class($_)';
field 'reader_class',      -onset => '$self->scanner->reader_class($_)';

sub load {
    my $self = shift;
    my $stream = shift;
    $self->open($stream);
    my @all_objects = ();
    while (my @objects = $self->load_next) {
        push @all_objects, @objects;
    }
    return @all_objects;
}

sub load_next {
    my $self = shift;
    return $self->constructor->check_data()
    ? ($self->constructor->get_data())
    : ();
}

1;
