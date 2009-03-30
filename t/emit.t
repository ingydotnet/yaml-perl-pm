use Test::More tests => 7;
use YAML::Perl 'emit';
use YAML::Perl::Events;

# goto TEST7;

my $yaml1 = emit(
    [
        YAML::Perl::Event::StreamStart->new(),
        YAML::Perl::Event::DocumentStart->new(explicit => 0),
        YAML::Perl::Event::Scalar->new(value => "foo\nbar\n", style => '|'),
        YAML::Perl::Event::DocumentEnd->new(),
        YAML::Perl::Event::StreamEnd->new(),
    ]
);

is $yaml1, <<'...', 'Headerless literal scalar';
|
  foo
  bar
...

my $yaml2 = emit(
    [
        YAML::Perl::Event::StreamStart->new(),
        YAML::Perl::Event::DocumentStart->new(explicit => 1),
        YAML::Perl::Event::Scalar->new(value => "foo\nbar\n", style => '|'),
        YAML::Perl::Event::DocumentEnd->new(),
        YAML::Perl::Event::StreamEnd->new(),
    ]
);

is $yaml2, <<'...', 'Headered literal scalar';
--- |
  foo
  bar
...

my $yaml3 = emit(
    [
        YAML::Perl::Event::StreamStart->new(),
        YAML::Perl::Event::DocumentStart->new(),
        YAML::Perl::Event::Scalar->new(value => "foo\nbar\n", style => '|'),
        YAML::Perl::Event::DocumentEnd->new(),
        YAML::Perl::Event::StreamEnd->new(),
    ]
);

is $yaml3, <<'...', 'Default-Headered literal scalar';
--- |
  foo
  bar
...

my $yaml4 = emit(
    [
        YAML::Perl::Event::StreamStart->new(),
        YAML::Perl::Event::DocumentStart->new(),
        YAML::Perl::Event::Scalar->new(value => "foo\nbar\n", style => '"'),
        YAML::Perl::Event::DocumentEnd->new(),
        YAML::Perl::Event::StreamEnd->new(),
    ]
);

is $yaml4, <<'...', 'Double quoted scalar';
--- "foo\nbar\n"
...

my $yaml5 = emit(
    [
        YAML::Perl::Event::StreamStart->new(),
        YAML::Perl::Event::DocumentStart->new(),
        YAML::Perl::Event::MappingStart->new(),
        YAML::Perl::Event::SequenceStart->new(),
        YAML::Perl::Event::Scalar->new(value => '1'),
        YAML::Perl::Event::Scalar->new(value => '2'),
        YAML::Perl::Event::SequenceEnd->new(),
        YAML::Perl::Event::Scalar->new(value => '3'),
        YAML::Perl::Event::MappingEnd->new(),
        YAML::Perl::Event::DocumentEnd->new(),
        YAML::Perl::Event::StreamEnd->new(),
    ]
);

is $yaml5, <<'...', 'Mapping with collection key';
---
? - 1
  - 2
: 3
...

my $yaml6 = emit(
    [
        YAML::Perl::Event::StreamStart->new(),
        YAML::Perl::Event::DocumentStart->new(),
        YAML::Perl::Event::Scalar->new(value => "The fat lazy dog lay under the awesome fox that kept jumping over his dumb lazy ass all day.", style => '>'),
        YAML::Perl::Event::DocumentEnd->new(),
        YAML::Perl::Event::StreamEnd->new(),
    ]
);

is $yaml6, <<'...', 'Folded scalar';
--- >-
  The fat lazy dog lay under the awesome fox that kept jumping over his dumb lazy
  ass all day.
...

TEST7:
my $yaml7 = emit(
    [
        YAML::Perl::Event::StreamStart->new(),
        YAML::Perl::Event::DocumentStart->new(),
        YAML::Perl::Event::Scalar->new(
            value => 123,
        ),
        YAML::Perl::Event::DocumentEnd->new(),
        YAML::Perl::Event::DocumentStart->new(
            tags => {
                '!foo!' => 'tag:clarkevans.com,2002:',
            },
        ),
        YAML::Perl::Event::Scalar->new(
            value => 123,
        ),
        YAML::Perl::Event::DocumentEnd->new(),
        YAML::Perl::Event::StreamEnd->new(),
    ]
);

is $yaml7, <<'.', 'Emit TAG directive';
--- 123
...
%TAG !foo! tag:clarkevans.com,2002:
--- 123
.

