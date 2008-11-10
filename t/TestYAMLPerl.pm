package t::TestYAMLPerl;
use Test::Base -Base;

# XXX - Preload needed external modules... then shut the door to keep things safe.
BEGIN {
    use diagnostics -trace;
    use Scalar::Util;
#     use Data::Dumper;
    use YAML();
    use YAML::Dumper();
    use YAML::XS();
    use Carp::Heavy;
    delete $ENV{PERL5LIB};
    @INC = qw(lib);
}

# use Test::YAML 0.51 -Base;
# 
# $Test::YAML::YAML = 'YAML';
# 
# $^W = 1;
