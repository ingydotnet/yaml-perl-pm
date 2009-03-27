use t::TestYAMLPerl;

skip_all_unless_require('Test::Deep');

use YAML::Perl;

spec_file('t/data/parser_emitter');
filters {
    yaml => 'load_yaml',
    perl => 'eval',
};

run_is_deep yaml => 'perl';

sub load_yaml {
    my $rc = Load($_);
    undef($_);
    return $rc;
}
