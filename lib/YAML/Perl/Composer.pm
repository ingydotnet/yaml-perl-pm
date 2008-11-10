# pyyaml/lib/yaml/composer.py
package YAML::Perl::Composer;
use strict;
use warnings;

package YAML::Perl::Composer;
use YAML::Perl::Processor -base;
use YAML::Perl::Nodes;

field 'next_layer' => 'parser';

field 'parser_class', 'YAML::Perl::Parser';
field 'parser', -init => '$self->create("parser")';

field 'resolver_class', 'YAML::Perl::Resolver';
field 'resolver', -init => '$self->create("resolver")';

field 'anchors' => {};

sub check_node {
    my $self = shift;
    $self->parser->get_event()
        if $self->parser->check_event('YAML::Perl::Event::StreamStart');
    return not($self->parser->check_event('YAML::Perl::Event::StreamEnd'));
}

sub get_node {
    my $self = shift;
    return $self->parser->check_event('YAML::Perl::Event::StreamEnd')
    ? ()
    : $self->compose_document();
}

sub compose_document {
    my $self = shift;
    $self->parser->get_event;
    my $node = $self->compose_node(undef, undef);
    $self->anchors({});
    return $node;
}

sub compose_node {
    my $self = shift;
    my ($parent, $index) = @_;
    my $node;
    if ($self->parser->check_event('YAML::Perl::Event::Alias')) {
        my $event = $self->parser->get_event();
        my $anchor = $event->anchor();
        throw( "found undefined alias $anchor " . $event->start_mark )
            if ( $self->anchors()->{ $anchor } );
        return $self->anchors()->{ $anchor };
    }
    my $event = $self->parser->peek_event();
    # XXX - Why is compose_node receiving a DocumentStart event?
#     XXX($self->parser);
    my $anchor = $event->anchor();
    if ( defined $anchor && $self->anchors()->{ $anchor } ) {
        throw "found duplicate anchor $anchor" 
            . " first occurance " . $self->anchors()->{ $anchor }
            . " second occurance " . $event->start_mark();
    }
#     $self->resolver->descend_resolver( $parent, $node );
    $node = $self->parser->check_event( 'YAML::Perl::Event::Scalar' ) ? 
            $self->compose_scalar_node( $anchor ) :
        $self->parser->check_event( 'YAML::Perl::Event::SequenceStart' ) ?
            $self->compose_sequence_node( $anchor ) :
        $self->parser->check_event( 'YAML::Perl::Event::MappingStart' ) ?
            $self->compose_mapping_node( $anchor ) : undef;
#     $self->resolver->ascend_resolver();
    return $node;
}

sub compose_scalar_node {
    my $self = shift;
    my $anchor = shift;
    my $event = $self->parser->get_event();
    my $tag = $event->tag;
#     $tag = $self->resolver->resolve(
#         'YAML::Perl::Node::Scalar',
#         $event->value,
#         $event->implicit,
#     ) if not defined $tag or $tag == '!';
    my $node = YAML::Perl::Node::Scalar->new(
        tag => $tag,
        value => $event->value,
        start_mark => $event->start_mark,
        end_mark => $event->end_mark,
        style => $event->style,
    );
    $self->anchors->{$anchor} = $node
      if defined $anchor;
    return $node;
}

1;
