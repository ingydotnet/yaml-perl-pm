# pyyaml/lib/yaml/events.py

package YAML::Perl::Events;
use strict;
use warnings;

package YAML::Perl::Event;
use YAML::Perl::Base -base;

use overload '""' => 'stringify';

field 'anchor';
field 'tag';
field 'implicit';
# field 'implicit'; implicit is a python tuple that may be broken into two attributes
field 'value';
field 'start_mark';
field 'end_mark';

sub stringify {
    my $self = shift;
    my $class = ref($self) || $self;

    my @attributes = grep exists($self->{$_}),
       qw(anchor tag implicit value);
    my $arguments = join ', ', map
        sprintf("%s=%s", $_, $self->{$_}), @attributes;
    return "$class ($arguments)";
}

package YAML::Perl::Event::Node;
use YAML::Perl::Event -base;

field 'anchor';

package YAML::Perl::Event::CollectionStart;
use YAML::Perl::Event::Node -base;

field 'tag';
field 'flow_style';

package YAML::Perl::Event::CollectionEnd;
use YAML::Perl::Event -base;

# Implementations.

package YAML::Perl::Event::StreamStart;
use YAML::Perl::Event -base;

field 'encoding';

package YAML::Perl::Event::StreamEnd;
use YAML::Perl::Event -base;

package YAML::Perl::Event::DocumentStart;
use YAML::Perl::Event -base;

field 'explicit';
field 'version';
field 'tags';
field 'start_mark';
field 'end_mark';
field 'explicit';
field 'version';
field 'tags' => [];

package YAML::Perl::Event::DocumentEnd;
use YAML::Perl::Event -base;

field 'explicit';

package YAML::Perl::Event::Alias;
use YAML::Perl::Event::Node -base;

package YAML::Perl::Event::Scalar;
use YAML::Perl::Event::Node -base;

field 'style';

package YAML::Perl::Event::SequenceStart;
use YAML::Perl::Event::CollectionStart -base;

package YAML::Perl::Event::SequenceEnd;
use YAML::Perl::Event::CollectionEnd -base;

package YAML::Perl::Event::MappingStart;
use YAML::Perl::Event::CollectionStart -base;

package YAML::Perl::Event::MappingEnd;
use YAML::Perl::Event::CollectionEnd -base;

1;
