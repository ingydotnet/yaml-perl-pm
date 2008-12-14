use t::TestYAMLPerl tests => 1;

use YAML::Perl::Emitter;
use YAML::Perl::Events;

spec_file('t/data/parser_emitter');
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
