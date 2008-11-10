# pyyaml/lib/yaml/parser.py

package YAML::Perl::Parser;
use strict;
use warnings;

use YAML::Perl::Error;
use YAML::Perl::Events;

package YAML::Perl::Parser::Error;
use YAML::Perl::Error::Marked -base;

package YAML::Perl::Parser;
use YAML::Perl::Processor -base;

field 'next_layer' => 'scanner';

field 'scanner_class', -init => '"YAML::Perl::Scanner"';
field 'scanner', -init => '$self->create("scanner")';

field 'current_event';
field 'yaml_version';
field 'tag_handles';
field 'states' => [];
field 'marks' => [];
field 'state' => 'parse_stream_start';

sub check_event {
    my $self = shift;
    my @choices = @_;
    if (not defined $self->current_event) {
        if ($self->state) {
            my $state = $self->state;
            $self->{current_event} = $self->$state();
        }
    }
    if (defined $self->current_event) {
        return 1 unless @choices;
        for my $choice (@choices) {
            return 1
                if $self->current_event->isa($choice);
        }
    }
    return 0;
}

sub peek_event {
    my $self = shift;
    if (not defined $self->current_event) {
        if (my $state = $self->state) {
            XXX $state;
            $self->{current_event} = $self->$state;
        }
    }
    return $self->current_event;
}

sub get_event {
    my $self = shift;
    if (not defined $self->current_event) {
        if (my $state = $self->state) {
            $self->{current_event} = $self->$state;
        }
    }
    my $value = $self->current_event;
    $self->{current_event} = undef;
    return $value;
}

sub parse_stream_start {
    my $self = shift;
    my $token = $self->scanner->get_token();
    assert(ref($token) eq 'YAML::Perl::Token::StreamStart');
    my $event = YAML::Perl::Event::StreamStart->new(
        start_mark => $token->start_mark,
        end_mark => $token->end_mark,
        encoding => $token->encoding,
    );
    $self->{state} = 'parse_implicit_document_start';
    return $event;
}

sub parse_implicit_document_start {
    my $self = shift;
    if (not $self->scanner->check_token(qw(
        YAML::Perl::Token::Directive
        YAML::Perl::Token::DocumentStart
        YAML::Perl::Token::StreamEnd
    ))) {
        $self->{tag_handles} = $self->DEFAULT_TAGS;
        my $token = $self->scanner->peek_token();
        my $start_mark = $token->start_mark;
        my $end_mark = $start_mark;
        my $event = YAML::Perl::Event::DocumentStart->new(
            start_mark => $start_mark,
            end_mark => $end_mark,
            explicit => 0,
        );

        push @{$self->states}, 'parse_document_end';
        $self->{state} = 'parse_block_node';
        return $event;
    }
    return $self->parse_document_start();
}

sub parse_document_start {
    my $self = shift;
    my $event;
    if (not $self->scanner->check_token('YAML::Perl::Token::StreamEnd')) {
        my $token = $self->scanner->peek_token();
        my $start_mark = $token->start_mark;
        my ($version, $tags) = $self->process_directives();
        if (not $self->scanner->check_token('YAML::Perl::Token::DocumentStart')) {
            throw YAML::Perl::Parser::Error->new(
                undef, undef,
                "expected '<document start', but found " .
                    $self->scanner->peek_token->id,
                self->scanner->peek_token->start_mark
            );
        }
        $token = $self->scanner->get_token();
        my $end_mark = $token->end_mark;
        $event = YAML::Perl::Event::DocumentStart->new(
            start_mark => $start_mark,
            end_mark => $end_mark,
            explicit => 1,
            version => $version,
            tags => $tags,
        );
        push @{$self->states}, 'parse_document_end';
        $self->{state} = 'parse_document_content';
    }
    else {
        my $token = $self->scanner->get_token();
        $event = YAML::Perl::Event::StreamEnd->new(
            start_mark => $token->start_mark,
            end_mark => $token->end_mark,
        );
        assert not scalar @{$self->states};
        assert not scalar @{$self->marks};
        $self->{state} = undef;
    }
    return $event;
}

sub parse_document_end {
    my $self = shift;
    my $token = $self->scanner->peek_token();
    my $start_mark = $token->start_mark;
    my $end_mark = $start_mark;
    my $explicit = 0;
    while ($self->scanner->check_token('YAML::Perl::Token::DocumentEnd')) {
        $token = $self->scanner->get_token();
        $end_mark = $token->end_mark;
        $explicit = 1;
    }
    my $event = YAML::Perl::Event::DocumentEnd->new(
        start_mark => $start_mark,
        end_mark => $end_mark,
        explicit => $explicit,
    );
    $self->{state} = 'parse_document_start';
    return $event;
}

sub parse_document_content {
    my $self = shift;
    if ( $self->scanner->check_token( 
        map "YAML::Perl::Token::${_}", qw/ DocumentStart DocumentEnd StreamEnd / 
    ) ) {
        my $event = $self->process_empty_scalar( $self->scanner->peek_token()->start_mark() );
        $self->state( pop @{ $self->states() } );
        return $event;
    }
    else {
        return $self->parse_block_node();
    }
}

sub process_directives {
    my $self = shift;
    $self->{yaml_version} = undef;
    $self->{tag_handles} = {};
    while ($self->scanner->check_token('YAML::Perl::Token::Directive')) {
        XXX my $token = $self->get_token();
    }
}

sub process_empty_scalar {
    my ( $self, $mark ) = @_;
    return YAML::Perl::Event::Scalar->new(
        anchor     => undef,
        tag        => undef,
        implicit   => 1,     # what does (True, False) mean??
        value      => '',
        start_mark => $mark,
        end_mark   => $mark
    );
}

sub parse_block_node {
    my $self = shift;
    return $self->parse_node(1, 0);
}

sub parse_flow_node {
    my $self = shift;
    return $self->parse_node(0, 0);
}

sub parse_block_node_or_indentless_sequence {
    my $self = shift;
    return $self->parse_node(1, 1);
}

sub parse_node {
    my $self = shift;
    assert @_ == 2;
    my $block = shift;
    my $indentless_sequence = shift;
    
    my $event;
    if ($self->scanner->check_token('YAML::Perl::Token::Alias')) {
        my $token = $self->get_token();
        $event = YAML::Perl::Event::Alias->new(
            value      => $token->value,
            start_mark => $token->start_mark,
            end_mark   => $token->end_mark,
        );
    }

    else {
        my $anchor = undef;
        my $tag = undef;
        my $implicit = undef;
        my ($start_mark, $end_mark, $tag_mark) = (undef, undef, undef);

        if ($self->scanner->check_token('YAML::Perl::Token::Anchor')) {
            my $token = $self->scanner->get_token();
            $start_mark = $token->start_mark;
            $end_mark = $token->end_mark;
            $anchor = $token->value;

            if ($self->scanner->check_token('YAML::Perl::Token::Tag')) {
                my $token = $self->scanner->get_token();
                $tag_mark = $token->start_mark;
                $end_mark = $token->end_mark;
                $tag = $token->value;
            }
        }

        elsif ($self->scanner->check_token('YAML::Perl::Token::Tag')) {
            my $token = $self->scanner->get_token();
            $start_mark = $token->start_mark;
            $tag_mark = $start_mark;
            $end_mark = $token->end_mark;

            if ($self->scanner->check_token('YAML::Perl::Token::Anchor')) {
                my $token = $self->scanner->get_token();
                $end_mark = $token->end_mark;
                $anchor = $token->value;
            }
        }

        if (defined $tag) {
            my ($handle, $suffix) = @$tag;

            if (defined $handle) {

                if (not exists $self->tag_handles->{$handle}) {
                    throw "while parsing a node... XXX finish this error msg";
                }
                $tag = $self->tag_handles->{$handle};
            }

            else {
                $tag = $suffix;
            }
        }
                
        if (not defined $start_mark) {
            $start_mark = $self->scanner->peek_token()->start_mark;
            $end_mark = $start_mark;
        }

        $event = undef;
        $implicit = (not defined $tag) || ($tag eq '!');

        if ($indentless_sequence and
            $self->scanner->check_token('YAML::Perl::Token::BlockEntry')
        ) {
            $end_mark = $self->scanner->peek_token()->end_mark;
            $event = YAML::Perl::Event::SequenceStart->new(
                anchor => $anchor,
                tag => $tag,
                implicit => $implicit,
                start_mark => $start_mark,
                end_mark => $end_mark,
            );
        }
        
        else {

            if ($self->scanner->check_token('YAML::Perl::Token::Scalar')) {
                my $token = $self->scanner->get_token();
                $end_mark = $token->end_mark;

                if (($token->plain and not defined $tag) or $tag eq '!') {
                    $implicit = [1, 0];
                }

                elsif (not defined $tag) {
                    $implicit = [0, 1];
                }
                
                else {
                    $implicit = [0, 0];
                }

                $event = YAML::Perl::Event::Scalar->new(
                    anchor => $anchor,
                    tag => $tag,
                    implicit => $implicit,
                    value => $token->value,
                    start_mark => $start_mark,
                    end_mark => $end_mark,
                    style => $token->style,
                );
                $self->{state} = pop @{$self->states};
            }

            elsif ($self->scanner->check_token('YAML::Perl::Token::FlowSequenceStart')) {
                $end_mark = $self->scanner->peek_token()->end_mark;
                $event = YAML::Perl::Event::SequenceStart->new(
                    anchor => $anchor,
                    tag => $tag,
                    implicit => $implicit,
                    start_mark => $start_mark,
                    end_mark => $end_mark,
                    flow_style => 1,
                );
                $self->{state} = 'parse_flow_sequence_first_entry';
            }

            elsif ($self->scanner->check_token('YAML::Perl::Token::FlowMappingStart')) {
                $end_mark = $self->scanner->peek_token()->end_mark;
                $event = YAML::Perl::Event::MappingStart->new(
                    anchor => $anchor,
                    tag => $tag,
                    implicit => $implicit,
                    start_mark => $start_mark,
                    end_mark => $end_mark,
                    flow_style => 1,
                );
                $self->{state} = 'parse_flow_mapping_first_entry';
            }

            elsif ($self->scanner->check_token('YAML::Perl::Token::BlockSequenceStart')) {
                $end_mark = $self->scanner->peek_token()->end_mark;
                $event = YAML::Perl::Event::SequenceStart->new(
                    anchor => $anchor,
                    tag => $tag,
                    implicit => $implicit,
                    start_mark => $start_mark,
                    end_mark => $end_mark,
                    flow_style => 0,
                );
                $self->{state} = 'parse_block_sequence_first_entry';
            }

            elsif ($self->scanner->check_token('YAML::Perl::Token::BlockMappingStart')) {
                $end_mark = $self->scanner->peek_token()->end_mark;
                $event = YAML::Perl::Event::MappingStart->new(
                    anchor => $anchor,
                    tag => $tag,
                    implicit => $implicit,
                    start_mark => $start_mark,
                    end_mark => $end_mark,
                    flow_style => 0,
                );
                $self->{state} = 'parse_block_mapping_first_entry';
            }

            elsif (defined $anchor or defined $tag) {
                $event = YAML::Perl::Event::Scalar->new(
                    anchor => $anchor,
                    tag => $tag,
                    implicit => [$implicit, 0],
                    value => '',
                    start_mark => $start_mark,
                    end_mark => $end_mark,
                );
                $self->{state} = pop @{$self->states};
            }

            else {
                my $node = $block ? 'block' : 'flow';
                my $token = $self->scanner->peek_token();
                throw "while parsing a $node node, XXX - finish error msg";
            }
        }
    }
    return $event;
}

sub parse_block_sequence_entry {
    my $self = shift;
    my $token = $self->scanner->get_token();
    push @{$self->marks}, $token->start_mark;
    return $self->parse_block_sequence_entry();
}

1;
