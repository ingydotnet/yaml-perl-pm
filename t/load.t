use t::TestYAMLPerl; # tests => 4;

use YAML::Perl;

spec_file('t/data/parser_emitter');
filters {
    yaml => 'load_yaml',
    perl => 'eval',
};

run_is_deeply yaml => 'perl';

sub load_yaml {
    Load($_);
}
