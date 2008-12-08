use t::TestYAMLPerl tests => 1;

use YAML::Perl::Emitter;
use YAML::Perl::Events;

filters { events => [qw(lines chomp make_events emit_yaml)] };

run_is events => 'yaml';

sub make_events {
    map {
       my ($event, @args) = split;
       "YAML::Perl::Event::$event"->new(@args);
   } @_;
}

sub emit_yaml {
    my $e = YAML::Perl::Emitter->new();
    $e->emit($_) for @_;
    ${$e->stream->buffer};
}


__END__
=== Emit Works
--- events
StreamStart
DocumentStart
MappingStart
Scalar value 42
MappingStart
Scalar value 43
Scalar value 44
MappingEnd
MappingEnd
DocumentEnd
StreamEnd
--- yaml
42:
  43: 44

