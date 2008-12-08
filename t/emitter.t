use t::TestYAMLPerl tests => 1;

use YAML::Perl::Emitter;

my @events = (
    YAML::Perl::Event::StreamStart->new(),
    YAML::Perl::Event::DocumentStart->new(),
    YAML::Perl::Event::MappingStart->new(),
    YAML::Perl::Event::Scalar->new(value => 42),
#     YAML::Perl::Event::MappingStart->new(),
    YAML::Perl::Event::Scalar->new(value => 43),
#     YAML::Perl::Event::Scalar->new(value => 44),
#     YAML::Perl::Event::MappingEnd->new(),
    YAML::Perl::Event::MappingEnd->new(),
    YAML::Perl::Event::DocumentEnd->new(),
    YAML::Perl::Event::StreamEnd->new(),
);

my $e = YAML::Perl::Emitter->new();

for (@events) {
    $e->emit($_);
}

# is ${$e->stream->buffer}, "42:\n  43: 44\n", 'Emit works';
is ${$e->stream->buffer}, "42: 43\n", 'Emit works';
