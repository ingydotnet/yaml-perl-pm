# pyyaml/lib/yaml/reader.py

package YAML::Perl::Reader;
use strict;
use warnings;

use YAML::Perl::Error;

package YAML::Perl::Reader;
use YAML::Perl::Processor -base;

field next_layer => '';

sub open {
    my $self = shift;
    $self->SUPER::open(@_);
    my $stream = shift;
    $self->stream($stream);
    # XXX see comment near line 176
    # $self->buffer($stream . "\0");
    $self->buffer($stream);
}

field 'name';
field 'stream';
field 'stream_pointer' => 0;
field 'eof' => 1;
field 'buffer' => '';
field 'pointer' => 0;
field 'raw_buffer';
field 'raw_decode';
field 'encoding';
field 'index' => 0;
field 'line' => 0;
field 'column' => 0;

sub init {
    my $self = shift;
    $self->{buffer} = '';
    $self->{index} = 0;
}

sub peek {
    my $self = shift;
    my $index = shift || 0;
    my $buff = $self->{buffer};
    $buff =~ s/\n/\\n/g;
#     WWW "peek -- buffer: [$buff] self.index: [" . $self->{index} . "] index: [$index]\n";
    
    # XXX or maybe the buffer should be initialized with a null char at the end 
    # see comment near line 110
    return "\0" if $self->{index} + $index > length( $self->{buffer} );
    return substr($self->{buffer}, $self->{index} + $index, 1);
}

sub prefix {
    my $self = shift;
    my $length = shift || 1;
    return substr($self->{buffer}, 0, $length);
}

sub forward {
    my $self = shift;
    my $length = shift || 1;

    while ( $length-- ) {
        my $ch = $self->peek();
        if ( 
            $ch =~ /[\n\x85]/
            or ( $ch eq "\r" and $self->peek(2) != "\n" )
        ) {
            $self->{line}++;
            $self->{column} = 0;
        }
        elsif ( $ch ne "\x{FEFF}" ) {
            $self->{column}++
        }
        $self->{index}++;
    }
}
    
sub get_mark {
    my $self = shift;
    if (not defined $self->stream) {
        return YAML::Perl::Mark->new(
            name => $self->name,
            index => $self->index,
            line => $self->line,
            column => $self->column,
            buffer => $self->buffer,
            pointer => $self->pointer,
        );
    }
    return YAML::Perl::Mark->new(
        name => $self->name,
        index => $self->index,
        line => $self->line,
        column => $self->column,
    );
}

1;
