use t::TestYAMLPerl; # tests => 3;

use YAML::Perl::Dumper;

spec_file('t/data/parser_emitter');
filters {
    perl => ['eval', 'dump_yaml'],
};

run_is perl => 'dump';

sub dump_yaml {
    YAML::Perl::Dumper->new()
        ->open()
        ->dump(@_);
}
