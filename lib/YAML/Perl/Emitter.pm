# pyyaml/lib/yaml/emitter.py

# Emitter expects events obeying the following grammar:
# stream ::= STREAM-START document* STREAM-END
# document ::= DOCUMENT-START node DOCUMENT-END
# node ::= SCALAR | sequence | mapping
# sequence ::= SEQUENCE-START node* SEQUENCE-END
# mapping ::= MAPPING-START (node node)* MAPPING-END

# To Do:
# - Make encode stuff work

package YAML::Perl::Emitter;
use strict;
use warnings;

use YAML::Perl::Error;
use YAML::Perl::Events;
use YAML::Perl::Stream;

package YAML::Perl::Error::Emitter;
use YAML::Perl::Error -base;

package YAML::Perl::ScalarAnalysis;
use YAML::Perl::Base -base;

field 'scalar';
field 'empty';
field 'multiline';
field 'allow_flow_plain';
field 'allow_block_plain';
field 'allow_single_quoted';
field 'allow_double_quoted';
field 'allow_block';

package YAML::Perl::Emitter;
use YAML::Perl::Base -base;

use constant DEFAULT_TAG_PREFIXES => {
    '!' => '!',
    'tag:yaml.org,2002:' => '!!',
};

field 'stream';
field 'encoding';
field 'states' => [];
field 'state' => 'expect_stream_start'; # Made this a function name instead of pointer
field 'events' => [];
field 'event';
field 'indents' => [];
field 'indent';
field 'flow_level' => 0;
field 'root_context' => False;
field 'sequence_context' => False;
field 'mapping_context' => False;
field 'simple_key_context' => False;
field 'line' => 0;
field 'column' => 0;
field 'whitespace' => True;
field 'indention' => True;
field 'canonical';
field 'allow_unicode';
field 'best_indent' => 2;
field 'best_width' => 2;
field 'best_line_break' => "\n";
field 'tag_prefixes';
field 'prepared_anchor';
field 'prepared_tag';
field 'analysis';
field 'style';

sub init {
    my $self = shift;
    my %p = @_;
    if ($p{indent} and $p{indent} > 1 and $p{indent} < 10) {
        $p{best_indent} = delete $p{indent};
    }
    if ($p{width} and $p{width} > ($p{best_indent} || 2) * 2) {
        $p{best_width} = delete $p{width};
    }
    if ($p{line_break} and $p{line_break} =~ /^(\r|\n|\r\n)$/) {
        $p{best_line_break} = delete $p{line_break};
    }
    $self->SUPER::init(%p);
    if (not $self->stream) {
        my $output = '';
        $self->stream(YAML::Perl::Stream->open(\ $output)); 
    }
}

sub emit {
    my $self = shift;
    my $event = shift;
    push @{$self->events}, $event;
    while (not $self->need_more_events()) {
        $self->event(shift @{$self->events});
        my $state = $self->state;
        $self->$state();
        $self->event(undef);
    }
    return ${$self->stream->buffer};
}

sub need_more_events {
    my $self = shift;
    if (not @{$self->events}) {
        return True;
    }
    my $event = $self->events->[0];
    if ($event->isa('YAML::Perl::Event::DocumentStart')) {
        return $self->need_events(1);
    }
    elsif ($event->isa('YAML::Perl::Event::SequenceStart')) {
        return $self->need_events(2);
    }
    elsif ($event->isa('YAML::Perl::Event::MappingStart')) {
        return $self->need_events(3);
    }
    else {
        return False;
    }
}

sub need_events {
    my $self = shift;
    my $count = shift;
    my $level = 0;
    for my $event (@{$self->events}[1..$#{$self->events}]) {
        if ($event->isa('YAML::Perl::Event::DocumentStart') or
            $event->isa('YAML::Perl::Event::CollectionStart')
        ) {
            $level++;
        }
        elsif ($event->isa('YAML::Perl::Event::DocumentEnd') or
            $event->isa('YAML::Perl::Event::CollectionEnd')
        ) {
            $level--;
        }
        elsif ($event->isa('YAML::Perl::Event::StreamEnd')) {
            $level = -1;
        }
        if ($level < 0) {
            return False;
        }
    }
    return (@{$self->events} < $count + 1);
}

sub increase_indent {
    my $self = shift;
    my $flow = shift || False;
    my $indentless = shift || False;
    push @{$self->indents}, $self->indent;
    if (not defined $self->indent) {
        if ($flow) {
            $self->indent($self->best_indent);
        }
        else {
            $self->indent(0);
        }
    }
    elsif (not $indentless) {
        $self->indent($self->indent + $self->best_indent);
    }
}

sub expect_stream_start {
    my $self = shift;
    if ($self->event->isa('YAML::Perl::Event::StreamStart')) {
        if ($self->event->encoding) {
            $self->encoding($self->event->encoding);
        }
        $self->write_stream_start();
        $self->state('expect_first_document_start');
    }
    else {
        use strict;
        throw YAML::Perl::Error::Emitter(
            "expected StreamStartEvent, but got ${\ $self->event}"
        );
    }
} 

sub expect_nothing {
    my $self = shift;
    throw YAML::Perl::Error::Emitter(
        "expected nothing, but got ${\ $self->event}"
    );
}

sub expect_first_document_start {
    my $self = shift;
    return $self->expect_document_start(True);
}

sub expect_document_start {
    my $self = shift;
    my $first = shift || False;
    if ($self->event->isa('YAML::Perl::Event::DocumentStart')) {
        if ($self->event->version) {
            my $version_text = $self->prepare_version($self->event->version);
            $self->write_version_directive($version_text);
        }
        $self->tag_prefixes({%{DEFAULT_TAG_PREFIXES()}});
        if ($self->event->tags) {
            for my $handle (sort keys %{$self->event->tags}) {
                my $prefix = $self->event->tags->{$handle};
                $self->tag_prefixes->{$prefix} = $handle;
                my $handle_text = $self->prepare_tag_handle($handle);
                my $prefix_text = $self->prepare_tag_prefix($prefix);
                $self->write_tag_directive($handle_text, $prefix_text);
            }
        }
        my $implicit = (
            $first and
            not $self->event->explicit and
            not $self->canonical and
            not $self->event->version and
            not $self->event->tags and
            not $self->check_empty_document()
        );
        if (not $implicit) {
            $self->write_indent();
            $self->write_indicator('---', True);
            if ($self->canonical) {
                $self->write_indent();
            }
        }
        $self->state('expect_document_root');
    }
    elsif ($self->event->isa('YAML::Perl::Event::StreamEnd')) {
        $self->write_stream_end();
        $self->state('expect_nothing');
    }
    else {
        throw YAML::Perl::Error::Emitter(
            "expected DocumentStartEvent, but got ${\ $self->event}"
        );
    }
}

sub expect_document_end {
    my $self = shift;
    if ($self->event->isa('YAML::Perl::Event::DocumentEnd')) {
        $self->write_indent();
        if ($self->event->explicit) {
            $self->write_indicator('->->->', True);
            $self->write_indent();
        }
        $self->flush_stream();
        $self->state('expect_document_start');
    }
    else {
        throw YAML::Perl::Error::Emitter(
            "expected DocumentEndEvent, but got ${\ $self->event}"
        );
    }
}

sub expect_document_root {
    my $self = shift;
    push @{$self->states}, 'expect_document_end';
    $self->expect_node(root => True);
}

sub expect_node {
    my $self = shift;
    my ($root, $sequence, $mapping, $simple_key) =
        @{{@_}}{qw(root sequence mapping simple_key)};
    $self->root_context($root);
    $self->sequence_context($sequence);
    $self->mapping_context($mapping);
    if ($self->event->isa('YAML::Perl::Event::Alias')) {
        $self->expect_alias();
    }
    elsif ($self->event->isa('YAML::Perl::Event::Scalar') or
        $self->event->isa('YAML::Perl::Event::CollectionStart')
    ) {
        $self->process_anchor('&');
        $self->process_tag();
        if ($self->event->isa('YAML::Perl::Event::Scalar')) {
            $self->expect_scalar();
        }
        elsif ($self->event->isa('YAML::Perl::Event::SequenceStart')) {
            if ($self->flow_level or
                $self->canonical or
                $self->event->flow_style or
                $self->check_empty_sequence()
            ) {
                $self->expect_flow_sequence();
            }
            else {
                $self->expect_block_sequence();
            }
        }
        elsif ($self->event->isa('YAML::Perl::Event::MappingStart')) {
            if ($self->flow_level or
                $self->canonical or
                $self->event->flow_style or
                $self->check_empty_mapping()
            ) {
                $self->expect_flow_mapping();
            }
            else {
                $self->expect_block_mapping();
            }
        }
    }
    else {
        throw YAML::Perl::Error::Emitter(
            "expected NodeEvent, but got ${\ $self->event}"
        );
    }
}

sub expect_alias {
    my $self = shift;
    die 'expect_alias';
}

sub expect_scalar {
    my $self = shift;
    $self->increase_indent(True);
    $self->process_scalar();
    $self->indent(pop @{$self->indents});
    $self->state(pop @{$self->states});
}

sub expect_flow_sequence {
    my $self = shift;
    die 'expect_flow_sequence';
}

sub expect_first_flow_sequence_item {
    die 'expect_first_flow_sequence_item';
}

sub expect_flow_sequence_item {
    die 'expect_flow_sequence_item';
}

sub expect_flow_mapping {
    die 'expect_flow_mapping';
}

sub expect_first_flow_mapping_key {
    die 'expect_first_flow_mapping_key';
}

sub expect_flow_mapping_key {
    die 'expect_flow_mapping_key';
}

sub expect_flow_mapping_simple_value {
    die 'expect_flow_mapping_simple_value';
}

sub expect_flow_mapping_value {
    die 'expect_flow_mapping_value';
}

sub expect_block_sequence {
    die 'expect_block_sequence';
}

sub expect_first_block_sequence_item {
    die 'expect_first_block_sequence_item';
}

sub expect_block_sequence_item {
    die 'expect_block_sequence_item';
}

sub expect_block_mapping {
    my $self = shift;
    $self->increase_indent(False);
    $self->state('expect_first_block_mapping_key');
}

sub expect_first_block_mapping_key {
    my $self = shift;
    return $self->expect_block_mapping_key(True);
}

sub expect_block_mapping_key {
    my $self = shift;
    my $first = shift || False;
    if (not $first and $self->event->isa('YAML::Perl::Event::MappingEnd')) {
        $self->indent(pop @{$self->indents});
        $self->state(pop @{$self->states});
    }
    else {
        $self->write_indent();
        if ($self->check_simple_key()) {
            push @{$self->states}, 'expect_block_mapping_simple_value';
            $self->expect_node(mapping => True, simple_key => True);
        }
        else {
            $self->write_indicator('?', True, indention => True);
            push @{$self->states}, 'expect_block_mapping_value';
            $self->expect_node(mapping => True);
        }
    }
}

sub expect_block_mapping_simple_value {
    my $self = shift;
    $self->write_indicator(':', False);
    push @{$self->states}, 'expect_block_mapping_key';
    $self->expect_node(mapping => True);
}

sub expect_block_mapping_value {
    die 'expect_block_mapping_value';
}

sub check_empty_sequence {
    die 'check_empty_sequence';
}

sub check_empty_mapping {
    my $self = shift;
    return (
        $self->event->isa('YAML::Perl::Event::MappingStart') and
        @{$self->events} and
        $self->events->[0]->isa('YAML::Perl::Event::MappingEnd')
    );
}

sub check_empty_document {
    my $self = shift;
    if (not $self->event->isa('YAML::Perl::Event::DocumentStart') or
        not $self->events
    ) {
        return False;
    }
    my $event = $self->events->[0];
    return (
        $event->isa('YAML::Perl::Event::Scalar') and
        not defined $event->anchor and
        not defined $event->tag and
        $event->implicit and
        $event->value eq ''
    );
}

sub check_simple_key {
    my $self = shift;
    my $length = 0;
    if ($self->event->isa('YAML::Perl::Event::Node') and
        defined $self->event->anchor
    ) {
        if (not $self->prepared_anchor) {
            $self->prepared_anchor($self->prepare_anchor($self->event->anchor));
        }
        $length += length($self->prepared_anchor);
    }
    if ((
            $self->event->isa('YAML::Perl::Event::Scalar') or
            $self->event->isa('YAML::Perl::Event::CollectionStart')
        ) and $self->event->tag
    ) {
        if (not $self->prepared_tag) {
            $self->prepared_tag($self->prepare_tag($self->event->tag));
        }
        $length += lenth($self->prepared_tag);
    }
    if ($self->event->isa('YAML::Perl::Event::Scalar')) {
        if (not $self->analysis) {
            $self->analysis($self->analyze_scalar($self->event->value));
        }
        $length += length($self->analysis->scalar);
    }
    return (
        $length < 128 and 
        (
            $self->event->isa('YAML::Perl::Event::Alias') or
            (
                $self->event->isa('YAML::Perl::Event::Scalar') and
                not $self->analysis->empty and
                not $self->analysis->multiline
            ) or
            $self->check_empty_sequence() or
            $self->check_empty_mapping()
        )
    );
}

sub process_anchor {
    my $self = shift;
    my $indicator = shift;
    if (not defined $self->event->anchor) {
        $self->prepared_anchor(undef);
        return;
    }
    if (not defined $self->prepared_anchor) {
        $self->prepared_anchor($self->prepare_anchor($self->event->anchor));
    }
    if ($self->prepared_anchor) {
        $self->write_indicator($indicator . $self->prepared_anchor, True);
    }
}

sub process_tag {
    my $self = shift;
    my $tag = $self->event->tag;
    if ($self->event->isa('YAML::Perl::Event::Scalar')) {
        if (not $self->style) {
            $self->style($self->choose_scalar_style());
        }
        if ((not $self->canonical or not $tag) and
            (
                ($self->style eq '' and $self->event->implicit->[0]) or
                ($self->style ne '' and $self->event->implicit->[1])
            )
        ) {
            $self->prepared_tag(undef);
            return;
        }
        if ($self->event->implicit->[0] and not $tag) {
            $tag = '!';
            $self->prepared_tag(undef);
        }
    }
    else {
        if ((not $self->canonical or not $tag) and $self->event->implicit) {
            $self->prepared_tag(undef);
            return;
        }
    }
    if (not $tag) {
        throw YAML::Perl::Error::Emitter("tag is not specified");
    }
    if (not $self->prepared_tag) {
        $self->prepared_tag($self->prepare_tag($tag))
    }
    if ($self->prepared_tag) {
        $self->write_indicator($self->prepared_tag, True)
    }
    $self->prepared_tag(undef);
}

sub choose_scalar_style {
    my $self = shift;
    if (not $self->analysis) {
        $self->analysis($self->analyze_scalar($self->event->value));
    }
    if ($self->event->style and $self->event->style eq '"' or $self->canonical) {
        return '"';
    }
    if (not $self->event->style and $self->event->implicit->[0]) {
        if (not (
                $self->simple_key_context and
                ($self->analysis->empty or $self->analysis->multiline)
            ) and
            (
                $self->flow_level and
                $self->analysis->allow_flow_plain or
                (not $self->flow_level and $self->analysis->allow_block_plain)
            )
        ) {
            return '';
        }
    }
    if ($self->event->style and $self->event->style =~ /^[\|\>]$/) {
        if (
            not $self->flow_level and
            not $self->simple_key_context and
            $self->analysis->allow_block
        ) {
            return $self->event->style
        }
    }
    if (not $self->event->style or $self->event->style == '\'') {
        if (
            $self->analysis->allow_single_quoted and
            not ($self->simple_key_context and $self->analysis->multiline)
        ) {
            return "'";
        }
    }
    return '"';
}

sub process_scalar {
    my $self = shift;
    if (not $self->analysis) {
        $self->analysis($self->analyze_scalar($self->event->value));
    }
    if (not $self->style) {
        $self->style($self->choose_scalar_style());
    }
    my $split = (not $self->simple_key_context);
    #if self->analysis->multiline and split    \
    #        and (not self->style or self->style in '\'\"'):
    #    self->write_indent()
    if ($self->style eq '"') {
        $self->write_double_quoted($self->analysis->scalar, $split);
    }
    elsif ($self->style eq "'") {
        $self->write_single_quoted($self->analysis->scalar, $split);
    }
    elsif ($self->style eq '>') {
        $self->write_folded($self->analysis->scalar);
    }
    elsif ($self->style eq '|') {
        $self->write_literal($self->analysis->scalar);
    }
    else {
        $self->write_plain($self->analysis->scalar, $split)
    }
    $self->analysis(undef);
    $self->style(undef);
}

sub prepare_version {
    die 'prepare_version';
}

sub prepare_tag_handle {
    die 'prepare_tag_handle';
}

sub prepare_tag_prefix {
    die 'prepare_tag_prefix';
}

sub prepare_tag {
    die 'prepare_tag';
}

sub prepare_anchor {
    die 'prepare_anchor';
}

sub analyze_scalar {
    my $self = shift;
    my $scalar = shift;

    # Empty scalar is a special case.
    if (not length $scalar) {
        return YAML::Perl::ScalarAnalysis->new(
            scalar => $scalar,
            empty => True,
            multiline => False,
            allow_flow_plain => False,
            allow_block_plain => True,
            allow_single_quoted => True,
            allow_double_quoted => True,
            allow_block => False,
        );
    }

    # Indicators and special characters.
    my $block_indicators = False;
    my $flow_indicators = False;
    my $line_breaks = False;
    my $special_characters = False;

    # Whitespaces.
    my $inline_spaces = False;          # non-space space+ non-space
    my $inline_breaks = False;          # non-space break+ non-space
    my $leading_spaces = False;         # ^ space+ (non-space | $)
    my $leading_breaks = False;         # ^ break+ (non-space | $)
    my $trailing_spaces = False;        # (^ | non-space) space+ $
    my $trailing_breaks = False;        # (^ | non-space) break+ $
    my $inline_breaks_spaces = False;   # non-space break+ space+ non-space
    my $mixed_breaks_spaces = False;    # anything else

    # Check document indicators.
    if ($scalar =~ /^---/ or $scalar =~ /^.../) {
        $block_indicators = True;
        $flow_indicators = True;
    }

    # First character or preceded by a whitespace.
    my $preceeded_by_space = True;

    # Last character or followed by a whitespace.
    my $followed_by_space =
        (length($scalar) == 1 or $scalar =~ /.[\0 \t\r\n\x85\x{2028}\x{2029}]/);

    # The current series of whitespaces contain plain spaces.
    my $spaces = False;

    # The current series of whitespaces contain line breaks.
    my $breaks = False;

    # The current series of whitespaces contain a space followed by a
    # break.
    my $mixed = False;

    # The current series of whitespaces start at the beginning of the
    # scalar.
    my $leading = False;

    my $index = 0;
    while ($index < length($scalar)) {
        my $ch = substr($scalar, $index, 1);

        # Check for indicators.

        if ($index == 0) {
            # Leading indicators are special characters.
            if ($ch =~ /^[\#\,\[\]\{\}\&\*\!\|\>\'\"\%\@\`]$/) { 
                $flow_indicators = True;
                $block_indicators = True;
            }
            if ($ch =~ /^[\?\:]$/) {
                $flow_indicators = True;
                if ($followed_by_space) {
                    $block_indicators = True;
                }
            }
            if ($ch eq '-' and $followed_by_space) {
                $flow_indicators = True;
                $block_indicators = True;
            }
        }
        else {
            # Some indicators cannot appear within a scalar as well.
            if ($ch =~ /^[\,\?\[\]\{\}]$/) {
                $flow_indicators = True;
            }
            if ($ch eq ':') {
                $flow_indicators = True;
                if ($followed_by_space) {
                    $block_indicators = True;
                }
            }
            if ($ch eq '#' and $preceeded_by_space) {
                $flow_indicators = True;
                $block_indicators = True;
            }
        }

        # Check for line breaks, special, and unicode characters.

        if ($ch =~ /^[\n\x85\x{2028}\x{2029}]$/) {
            $line_breaks = True;
        }
        if (not ($ch eq "\n" or $ch ge "\x20" and $ch le "\x7E")) {
            if (
                (
                    $ch eq "\x85" or
                    $ch ge "\xA0" and $ch le "\x{D7FF}" or
                    $ch ge "\x{E000}" and $ch le "\x{FFFD}"
                ) and $ch ne "\x{FEFF}"
            ) {
                my $unicode_characters = True;
                if (not $self->allow_unicode) {
                    $special_characters = True;
                }
            }
            else {
                $special_characters = True;
            }
        }

        # Spaces, line breaks, and how they are mixed. State machine.

        # Start or continue series of whitespaces.
        if ($ch =~ /^[\ \n\x85\x{2028}\x{2029}]$/) {
            if ($spaces and $breaks) {
                if ($ch ne ' ') {      # break+ (space+ break+)    => mixed
                    $mixed = True;
                }
            }
            elsif ($spaces) {
                if ($ch ne ' ') {      # (space+ break+)   => mixed
                    $breaks = True;
                    $mixed = True;
                }
            }
            elsif ($breaks) {
                if ($ch == ' ') {      # break+ space+
                    $spaces = True;
                }
            }
            else {
                $leading = ($index == 0);
                if ($ch == ' ') {      # space+
                    $spaces = True;
                }
                else {                 # break+
                    $breaks = True;
                }
            }
        }

        # Series of whitespaces ended with a non-space.
        elsif ($spaces or $breaks) {
            if ($leading) {
                if ($spaces and $breaks) {
                    $mixed_breaks_spaces = True;
                }
                elsif ($spaces) {
                    $leading_spaces = True;
                }
                elsif ($breaks) {
                    $leading_breaks = True;
                }
            }
            else {
                if ($mixed) {
                    $mixed_breaks_spaces = True;
                }
                elsif ($spaces and $breaks) {
                    $inline_breaks_spaces = True;
                }
                elsif ($spaces) {
                    $inline_spaces = True;
                }
                elsif ($breaks) {
                    $inline_breaks = True;
                }
            }
            $spaces = $breaks = $mixed = $leading = False;
        }

        # Series of whitespaces reach the end.
        if (($spaces or $breaks) and ($index == length($scalar)-1)) {
            if ($spaces and $breaks) {
                $mixed_breaks_spaces = True;
            }
            elsif ($spaces) {
                $trailing_spaces = True;
                if ($leading) {
                    $leading_spaces = True;
                }
            }
            elsif ($breaks) {
                $trailing_breaks = True;
                if ($leading) {
                    $leading_breaks = True;
                }
            }
            $spaces = $breaks = $mixed = $leading = False;
        }

        # Prepare for the next character.
        $index += 1;
        $preceeded_by_space = ($ch =~ /^[\0 \t\r\n\x85\x{2028}\x{2029}]$/);
        $followed_by_space = (
            $index + 1 >= length($scalar) or
            substr($scalar, index+1, 1) =~ /^[\0\ \t\r\n\x85\x{2028}\x{2029}]$/
        );
    }

    # Let's decide what styles are allowed.
    my $allow_flow_plain = True;
    my $allow_block_plain = True;
    my $allow_single_quoted = True;
    my $allow_double_quoted = True;
    my $allow_block = True;

    # Leading and trailing whitespace are bad for plain scalars. We also
    # do not want to mess with leading whitespaces for block scalars.
    if ($leading_spaces or $leading_breaks or $trailing_spaces) {
        $allow_flow_plain = $allow_block_plain = $allow_block = False;
    }

    # Trailing breaks are fine for block scalars, but unacceptable for
    # plain scalars.
    if ($trailing_breaks) {
        $allow_flow_plain = $allow_block_plain = False;
    }

    # The combination of (space+ break+) is only acceptable for block
    # scalars.
    if ($inline_breaks_spaces) {
        $allow_flow_plain = $allow_block_plain = $allow_single_quoted = False;
    }

    # Mixed spaces and breaks, as well as special character are only
    # allowed for double quoted scalars.
    if ($mixed_breaks_spaces or $special_characters) {
        $allow_flow_plain = $allow_block_plain =
        $allow_single_quoted = $allow_block = False;
    }

    # We don't emit multiline plain scalars.
    if ($line_breaks) {
        $allow_flow_plain = $allow_block_plain = False;
    }

    # Flow indicators are forbidden for flow plain scalars.
    if ($flow_indicators) {
        $allow_flow_plain = False;
    }

    # Block indicators are forbidden for block plain scalars.
    if ($block_indicators) {
        $allow_block_plain = False;
    }

    return YAML::Perl::ScalarAnalysis->new(
        scalar => $scalar,
        empty => False,
        multiline => $line_breaks,
        allow_flow_plain => $allow_flow_plain,
        allow_block_plain => $allow_block_plain,
        allow_single_quoted => $allow_single_quoted,
        allow_double_quoted => $allow_double_quoted,
        allow_block => $allow_block,
    );
}

sub flush_stream {
    my $self = shift;
    if ($self->stream->can('flush')) {
        $self->stream->flush();
    }
}

sub write_stream_start {
    my $self = shift;
    if ($self->encoding and $self->encoding =~ /^utf-16/) {
        $self->stream->write("\xff\xfe");
    }
}

sub write_stream_end {
    my $self = shift;
    $self->flush_stream();
}

sub write_indicator {
    my $self = shift;
    my $indicator = shift;
    my $need_whitespace = shift;
    my ($whitespace, $indention) = @{{@_}}{qw(whitespace indention)};
    $whitespace = False unless defined $whitespace;
    $indention = False unless defined $indention;

    my $data;
    if ($self->whitespace or not $need_whitespace) {
        $data = $indicator;
    }
    else {
        $data = ' ' . $indicator;
    }
    $self->whitespace($whitespace);
    $self->indention($self->indention and $indention);
    $self->column($self->column + length($data));
    if ($self->encoding) {
#         my $data = $data->encode($self->encoding);
    }
    $self->stream->write($data);
}

sub write_indent {
    my $self = shift;
    my $indent = $self->indent || 0;
    if (not $self->indention or
        $self->column > $indent or
        ($self->column == $indent and not $self->whitespace)
    ) {
        $self->write_line_break();
    }
    if ($self->column < $indent) {
        $self->whitespace(True);
        my $data = ' ' x ($indent - $self->column);
        $self->column($indent);
        if ($self->encoding) {
            # $data = $data->encode($self->encoding); #XXX
        }
        $self->stream->write($data);
    }
}

sub write_line_break {
    my $self = shift;
    my $data = shift;
    if (not defined $data) {
        $data = $self->best_line_break;
    }
    $self->whitespace(True);
    $self->indention(True);
    $self->line($self->line + 1);
    $self->column(0);
    if ($self->encoding) {
#         $data = $data->encode($self->encoding);
    }
    $self->stream->write($data);
}

sub write_version_directive {
    die 'write_version_directive';
}

sub write_tag_directive {
    die 'write_tag_directive';
}

sub write_single_quoted {
    die 'write_single_quoted';
}

sub write_double_quoted {
    die 'write_double_quoted';
}

sub determine_chomp {
    die 'determine_chomp';
}

sub write_folded {
    die 'write_folded';
}

sub write_literal {
    die 'write_literal';
}

sub write_plain {
    my $self = shift;
    my $text = shift;
    my $split = shift || True;
    if (not length $text) {
        return;
    }
    if (not $self->whitespace) {
        my $data = ' ';
        $self->column($self->column + length($data));
        if ($self->encoding) {
#             $data = $data->encode($self->encoding);
        }
        $self->stream->write($data);
    }
    $self->whitespace(False);
    $self->indention(False);
    my $spaces = False;
    my $breaks = False;
    my ($start, $end) = (0, 0);
    while ($end <= length($text)) {
        my $ch = undef;
        if ($end < length($text)) {
            $ch = substr($text, $end, 1);
        }
        if ($spaces) {
            if ($ch ne ' ') {
                if ($start + 1 == $end and
                    $self->column > $self->best_width and
                    $split
                ) {
                    $self->write_indent();
                    $self->whitespace(False);
                    $self->indention(False);
                }
                else {
                    my $data = substr($text, $start, $end - $start);
                    $self->column($self->column + length($data));
                    if ($self->encoding) {
#                         $data = $data->encode($self->encoding)
                    }
                    $self->stream->write($data);
                }
                $start = $end;
            }
        }
        elsif ($breaks) {
            if ($ch !~ /^[\n\x85\x{2028}\x{2029}]$/) {
                if (substr($text, $start, 1) eq "\n") {
                    $self->write_line_break();
                }
                for my $br (split '', substr($text, $start, $end)) {
                    if ($br eq "\n") {
                        $self->write_line_break();
                    }
                    else {
                        $self->write_line_break($br);
                    }
                }
                $self->write_indent();
                $self->whitespace = False;
                $self->indention = False;
                $start = $end;
            }
        }
        else {
            if (not(defined $ch) or $ch =~ /^[\ \n\x85\x{2028}\x{2029}]$/) {
                my $data = substr($text, $start, $end - $start);
                $self->column($self->column + length($data));
                if ($self->encoding) {
#                     $data = $data->encode($self->encoding);
                }
                $self->stream->write($data);
                $start = $end;
            }
        }
        if (defined $ch) {
            $spaces = ($ch eq ' ');
            $breaks = ($ch =~ /^[\n\x85\x{2028}\x{2029}]$/);
        }
        $end += 1;
    }
}

1;
