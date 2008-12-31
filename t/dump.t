use t::TestYAMLPerl; # tests => 4;

use YAML::Perl;

spec_file('t/data/parser_emitter');
filters {
    perl => ['eval', 'dump_yaml'],
};

run_is perl => 'dump';

sub dump_yaml {
    Dump(@_);
}

