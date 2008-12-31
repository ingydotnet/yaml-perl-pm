use t::TestYAMLPerl; # tests => 2;

use YAML::Perl::Representer;

spec_file('t/data/parser_emitter');
filters { perl => [qw'eval represent'] };

run_is perl => 'dump';

sub make_events {
    map {
       my ($event, @args) = split;
       "YAML::Perl::Event::$event"->new(@args);
   } @_;
}

sub represent {
    $_ = YAML::Perl::Representer->new()
        ->open()
        ->represent(@_);
}
