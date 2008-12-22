use t::TestYAMLPerl tests => 2;

use YAML::Perl::Parser;
use YAML::Perl::Events;

spec_file('t/data/parser_emitter');
filters { yaml => [qw'parse_yaml event_string join'] };

run_is yaml => 'events';

sub make_events {
    map {
       my ($event, @args) = split;
       "YAML::Perl::Event::$event"->new(@args);
   } @_;
}

sub event_string {
    map {
        my $string = ref($_);
        $string =~ s/^YAML::Perl::Event:://;
        if ($string eq 'Scalar') {
            $string .= " value " . $_->value;
        }
        $string .= "\n";
    } @_;
}

sub parse_yaml {
    my $p = YAML::Perl::Parser->new();
    $p->open($_);
    $p->parse();
}
