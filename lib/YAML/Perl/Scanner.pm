# pyyaml/lib/yaml/scanner.py

package YAML::Perl::Scanner;
use strict;
use warnings;
use YAML::Perl::Processor -base;

field 'next_layer' => 'reader';

field 'reader_class', -init => '"YAML::Perl::Reader"';
field 'reader', -init => '$self->create("reader")';

use YAML::Perl::Error;
use YAML::Perl::Tokens;

package YAML::Perl::Scanner::Error;
use YAML::Perl::Error::Marked -base;

package YAML::Perl::Scanner::SimpleKey;
use YAML::Perl::Base -base;

field 'token_number';
field 'required';
field 'index';
field 'line';
field 'column';
field 'mark';

package YAML::Perl::Scanner;

field done => 0;

field flow_level => 0;

field tokens => [];

sub open {
    my $self = shift;
    $self->SUPER::open(@_);
    $self->fetch_stream_start();
}

field tokens_taken => 0;

field indent => -1;

field indents => [];

field allow_simple_key => 1;

field possible_simple_keys => {};

sub check_token {
    my $self = shift;
    my @choices = @_;
    $self->fetch_more_tokens()
        while $self->need_more_tokens();
    my $tokens = $self->tokens;
    if (@$tokens) {
        return 1
            unless @choices;
        for my $choice (@choices) {
            return 1
                if $tokens->[0]->isa($choice);
        }
    }
    return 0;
}

sub peek_token {
    my $self = shift;
    $self->fetch_more_tokens()
        while $self->need_more_tokens();
    my $tokens = $self->tokens;
    return $tokens->[0]
        if @$tokens;
    return;
}

sub get_token {
    my $self = shift;
    $self->fetch_more_tokens()
        while $self->need_more_tokens();
    my $tokens = $self->tokens;
    return shift @$tokens
        if @$tokens;
    return;
}

sub need_more_tokens {
    my $self = shift;
    return 0
        if $self->done;
    return 1
        if not @{$self->tokens};
    $self->stale_possible_simple_keys();
    my $next = $self->next_possible_simple_key();
    return (defined $next and $next == $self->tokens_taken) ? 1 : 0;
}

sub fetch_more_tokens {
    my $self = shift;

    $self->scan_to_next_token();

    $self->stale_possible_simple_keys();

    $self->unwind_indent($self->reader->column);

    my $char = $self->reader->peek();

    return $self->fetch_stream_end()
        if $char eq "\0";

    return $self->fetch_directive()
        if $char eq "%" and $self->check_directive();

    return $self->fetch_document_start
        if $char eq "-" and $self->check_document_start();

    return $self->fetch_document_end
        if $char eq "." and $self->check_document_end();

    return $self->fetch_flow_sequence_start()
        if $char eq "[";

    return $self->fetch_flow_mapping_start()
        if $char eq "{";

    return $self->fetch_flow_sequence_end()
        if $char eq "]";

    return $self->fetch_flow_mapping_end()
        if $char eq "}";

    return $self->fetch_flow_entry()
        if $char eq ',';

    return $self->fetch_block_entry()
        if $char eq '-' and $self->check_block_entry();

    return $self->fetch_key()
        if $char eq '?' and $self->check_key();

    return $self->fetch_value()
        if $char eq ':' and $self->check_value();

    return $self->fetch_alias()
        if $char eq '*';

    return $self->fetch_anchor()
        if $char eq '&';

    return $self->fetch_tag()
        if $char eq '!';

    return $self->fetch_literal()
        if $char eq '|' and not $self->flow_level;

    return $self->fetch_folded()
        if $char eq '|' and not $self->flow_level;

    return $self->fetch_single()
        if $char eq "'";

    return $self->fetch_double()
        if $char eq '"';

    return $self->fetch_plain()
        if $self->check_plain();

}

sub next_possible_simple_key {
    my $self = shift;
    my $min_token_number = undef;
    for my $level (keys %{$self->possible_simple_keys}) {
        my $key = $self->possible_simple_keys->{$level};
        $min_token_number = $key->token_number
            if not defined $min_token_number or
                $key->token_number < $min_token_number;
    }
    return $min_token_number;
}

sub stale_possible_simple_keys {
    my $self = shift;
    for my $level (keys %{$self->possible_simple_keys}) {
        my $key = $self->possible_simple_keys->{$level};
        if ($key->line != $self->line or
            $self->index - $key->index > 1024
        ) {
            throw YAML::Perl::Scanner::Error->new(
                "while scanning a simple key", $key->mark,
                "could not find expected ':'", $self->get_mark()
            ) if $key->required;
            delete $self->possible_simple_keys->{$level};
        }
    }
}

sub save_possible_simple_key {
    my $self = shift;
    my $required = (not $self->flow_level and $self->indent == $self->column);
    assert($self->allow_simple_key or not $required);
    if ($self->allow_simple_key) {
        $self->remove_possible_simple_key();
        my $token_number = $self->tokens_taken + @{$self->tokens};
        my $key = YAML::Perl::Scanner::SimpleKey->new(
            $token_number, $required,
            $self->index, $self->line, $self->column, $self->get_mark()
        );
        $self->possible_simple_keys->{$self->flow_level} = $key;
    }
}

sub remove_possible_simple_key {
    my $self = shift;
    my $key = $self->possible_simple_keys->{$self->flow_level};
    if (defined $key) {
        throw YAML::Perl::Scanner::Error->new(
            "while scanning a simple key", $key->mark,
            "could not find expected ':'", $self->get_mark()
        ) if $key->required;
        delete $self->possible_simple_keys->{$self->flow_level};
    }
}

sub unwind_indent {
    my $self = shift;
    my $column = shift;
    return if $self->flow_level;
    while ($self->indent > $column) {
        my $mark = $self->get_mark();
        $self->{indent} = pop @{$self->indents};
        push @{$self->tokens}, YAML::Perl::Token::BlockEnd->new(
            start_mark => $mark,
            end_mark => $mark,
        );
    }
}

sub add_indent {
    my $self = shift;
    my $column = shift;
    if ($self->indent < $column) {
        push @{$self->indents}, $self->indent;
        $self->{indent} = $column;
        return 1;
    }
    return 0;
}

sub fetch_stream_start {
    my $self = shift;
    my $mark = $self->reader->get_mark();
    push @{$self->tokens}, YAML::Perl::Token::StreamStart->new(
        start_mark => $mark,
        end_mark => $mark,
        encoding => $self->reader->encoding,
    );
}

sub fetch_stream_end {
    my $self = shift;
    $self->unwind_indent(-1);
    $self->{allow_simple_key} = 0;
    $self->{possible_simple_keys} = {};
    my $mark = $self->reader->get_mark();
    push @{$self->tokens}, YAML::Perl::Token::StreamEnd->new(
        start_mark => $mark,
        end_mark => $mark,
    );
    $self->done(1);
}

sub fetch_directive {
    my $self = shift;
    $self->unwind_indent(-1);
    $self->remove_possible_simple_key();
    $self->{allow_simple_key} = 0;
    push @{$self->tokens}, $self->scan_directive();
}

sub fetch_document_start {
    my $self = shift;
    $self->fetch_document_indicator('YAML::Perl::Token::DocumentStart');
}

sub fetch_document_end {
    my $self = shift;
    $self->fetch_document_indicator('YAML::Perl::Token::DocumentEnd');
}

sub fetch_document_indicator {
    my $self = shift;
    my $token_class = shift;
    $self->unwind_indent(-1);
    $self->remove_possible_simple_key();
    $self->{allow_simple_key} = 0;
    my $start_mark = $self->reader->get_mark();
    $self->reader->forward(3);
    my $end_mark = $self->reader->get_mark();
    push @{$self->tokens}, $token_class->new(
        start_mark => $start_mark,
        end_mark => $end_mark,
    );
}

sub fetch_flow_sequence_start {
    my $self = shift;
    $self->fetch_flow_collection_start('YAML::Perl::Token::FlowSequenceStart');
}

sub fetch_flow_mapping_start {
    my $self = shift;
    $self->fetch_flow_collection_start('YAML::Perl::Token::FlowMappingStart');
}

sub fetch_flow_collection_start {
    my $self = shift;
    my $token_class = shift;
    $self->save_possible_simple_key();
    $self->{flow_level} += 1;
    $self->{allow_simple_key} = 1;
    my $start_mark = $self->get_mark();
    $self->reader->forward();
    my $end_mark = $self->get_mark();
    push @{$self->tokens}, $token_class->new(
        $start_mark, $end_mark
    );
}

sub fetch_flow_sequence_end {
    my $self = shift;
    $self->fetch_flow_collection_end('YAML::Perl::Token::FlowSequenceEnd');
}

sub fetch_flow_mapping_end {
    my $self = shift;
    $self->fetch_flow_collection_end('YAML::Perl::Token::FlowMappingEnd');
}

sub fetch_flow_collection_end {
    my $self = shift;
    my $token_class = shift;
    $self->remove_possible_simple_key();
    $self->{flow_level} -= 1;
    $self->{allow_simple_key} = 0;
    my $start_mark = $self->get_mark();
    $self->reader->forward();
    my $end_mark = $self->get_mark();
    push @{$self->tokens}, $token_class->new(
        $start_mark, $end_mark
    );
}

sub fetch_flow_entry {
    my $self = shift;
    $self->{allow_simple_key} = 1;
    $self->remove_possible_simple_key();
    my $start_mark = $self->get_mark();
    $self->reader->forward();
    my $end_mark = $self->get_mark();
    push @{$self->tokens}, YAML::Perl::Token::FlowEntry->new(
        start_mark => $start_mark,
        end_mark => $end_mark,
    );
}

sub fetch_block_entry {
    my $self = shift;
    if (not $self->flow_level) {
        throw YAML::Perl::Scanner::Error->new(
            undef, undef,
            "sequence entries are not allowed here", $self->get_mark()
        ) unless $self->allow_simple_key;
        if ($self->add_indent($self->column)) {
            my $mark = $self->get_mark();
            push @{$self->tokens}, YAML::Perl::Token::BlockSequenceStart->new(
                start_mark => $mark,
                end_mark => $mark,
            );
        }
    }
    $self->{allow_simple_key} = 1;
    $self->remove_possible_simple_key();
    my $start_mark = $self->get_mark();
    $self->reader->forward();
    my $end_mark = $self->get_mark();
    push @{$self->tokens}, YAML::Perl::Token::BlockEntry->new(
        start_mark => $start_mark,
        end_mark => $end_mark,
    );
}

sub fetch_key {
    my $self = shift;
    if (not $self->flow_level) {
        throw YAML::Perl::Scanner::Error->new(
            undef, undef,
            "mapping keys are not allowed here", $self->get_mark()
        ) unless $self->allow_simple_key;
        if ($self->add_indent($self->column)) {
            my $mark = $self->get_mark();
            push @{$self->tokens}, YAML::Perl::Token::BlockMappingStart->new(
                start_mark=> $mark,
                end_mark => $mark,
            );
        }
    }
    $self->{allow_simple_key} = not($self->flow_level);
    $self->remove_possible_simple_key();
    my $start_mark = $self->get_mark();
    $self->reader->forward();
    my $end_mark = $self->get_mark();
    push @{$self->tokens}, YAML::Perl::Token::Key->new(
        start_mark => $start_mark,
        end_mark => $end_mark,
    );
}

sub fetch_plain {
    my $self = shift;
    $self->{allow_simple_key} = 0;
    push @{$self->tokens}, $self->scan_plain();
}

sub check_document_start {
    my $self = shift;
    if ($self->reader->column == 0) {
        if ($self->reader->prefix(3) eq '---' and
            $self->reader->peek(3) =~ /^[\0\ \t\r\n]$/
        ) {
            return 1;
        }
    }
    return 0;
}

sub check_block_entry {
    my $self = shift;
    return $self->reader->peek(1) =~ /^[\0\ \t\r\n]$/;
}

sub check_plain {
    my $self = shift;
    my $char = $self->reader->peek();
    return(
        $char !~ /^[\0\ \r\n\-\?\:\,\[\]\{\}\#\&\*\!\|\>\'\"\%\@\`]$/ or
        $self->reader->peek(1) !~ /^[\0\ \t\r\n]$/ and
        ($char eq '-' or (not $self->flow_level and $char =~ /^[\?\:]$/))
    );
}

sub scan_to_next_token {
    my $self = shift;
    if ($self->reader->index == 0 and $self->reader->peek eq "\uFEFF") {
        $self->reader->forward();
    }
    my $found = 0;
    while (not $found) {
        $self->reader->forward()
            while $self->reader->peek() eq ' ';
        if ($self->reader->peek() eq '#') {
            $self->reader->forward()
                while $self->reader->peek() !~ /^[\0\r\n\x85]$/;
        }
        if ($self->scan_line_break()) {
            $self->{allow_simple_key} = 1
                unless $self->flow_level;
        }
        else {
            $found = 1;
        }
    }
}

sub scan_plain {
    my $self = shift;

    my $chunks = '';
    my $start_mark = $self->reader->get_mark();
    my $end_mark = $start_mark;
    my $indent = $start_mark;

    my $spaces = '';

    while (1) {
        my $length = 0;
        last if $self->reader->peek() eq '#';
        my $char;
        while (1) {
            $char = $self->reader->peek($length);
#             print ">$char<\n"; die if $main::x++ > 3;

            last if 
                ($char =~ /^[\0\ \t\r\n]$/) or
                (not $self->flow_level and $char eq ':' and
                    $self->reader->peek($length+1) =~ /^[\0\ \t\r\n]$/) or
                ($self->flow_level and $char =~ /^[\,\:\?\[\]\{\}]$/);
            $length++;
        }
        if ($self->flow_level and $char eq ':' and
            $self->reader->peek($length + 1) !~ /^[\0\ \t\r\n\,\[\]\{\}]$/
        ) {
            $self->reader->forward($length);
            throw YAML::Perl::Scanner::Error->new(
                "while scanning a plain scalar", $start_mark,
                "found unexpected ':'", $self->reader->get_mark(),
                "Please check http://pyyaml.org/wiki/YAMLColonInFlowContext for details.",
            );
        }
        last if $length == 0;
        $self->{allow_simple_key} = 0;
        $chunks .= $spaces;
        $chunks .= $self->reader->prefix($length);
        $self->reader->forward($length);
        $end_mark = $self->reader->get_mark();
        $spaces = $self->scan_plain_spaces($indent, $start_mark);
        if (not length($spaces) or 
            $self->reader->peek() eq '#' or
            (not $self->flow_level and $self->reader->column < $indent)
        ) { last }
    }
    return YAML::Perl::Token::Scalar->new(
        value => $chunks,
        plain => 1,
        start_mark => $start_mark,
        end_mark => $end_mark,
    );
}

#   ... ch in u'\r\n\x85\u2028\u2029':
# XXX needs unicode linefeeds 
my $linefeed = qr/^[\r\n\x85]$/;

sub scan_plain_spaces {
    my $self = shift;
    my ( $indent, $start_mark ) = @_;

    my $chunks = [];
    my $length = 0;
    my $whitespaces;

# XXX owch!
    $length++ while ( $self->reader->peek( $length ) eq ' ' );

    $whitespaces = $self->reader->prefix( $length );
    $self->reader->forward( $length );

    my $ch = $self->reader->peek();

    if ( $ch =~ $linefeed ) {

        my $line_break = $self->scan_line_break();
        $self->allow_simple_key(1);
        my $prefix = $self->reader->prefix(3);

        if ( ( $prefix eq '---' or $prefix eq '...' )
            and $self->reader->peek(3) =~ $linefeed ) {
            return
        }

        my $breaks = [];

        while ( $self->reader->peek() =~ $linefeed ) {

            if ( $self->reader->peek() eq ' ' ) {
                $self->reader->forward();
            }
            else {
                push @$breaks, $self->scan_line_break();
                my $prefix = $self->reader->prefix(3);
                if ( ( $prefix eq '---' or $prefix eq '...' )
                    and $self->reader->peek(3) =~ $linefeed ) {
                    return
                }
            }
        }

        if ( $line_break != "\n" ) {
            push @$chunks, $line_break;
        }
        elsif ( not @$breaks ) {
            push @$chunks, ' ';
        }

        push @$chunks, @$breaks;

    }

    elsif ( $whitespaces ) {
        push @$chunks, $whitespaces;
    }

    return $chunks; 
}

sub scan_line_break {
    my $self = shift;
    my $char = $self->reader->peek();
    if ($char =~ /[\r\n]/) {
        if ($self->reader->prefix(2) eq "\r\n") {
            $self->reader->forward(2);
        }
        else {
            $self->reader->forward(1);
        }
        return "\n"
    }
    return '';
}

1;
