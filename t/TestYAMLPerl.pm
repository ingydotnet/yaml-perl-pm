package t::TestYAMLPerl;
use Test::Base -Base;
use Devel::Trace;
BEGIN {
    $Devel::Trace::TRACE = 1;
}

delimiters('===', '+++');

# XXX - Preload needed external modules... then shut the door to keep things safe.
BEGIN {
    use diagnostics -trace;
    use Scalar::Util;
#     use Data::Dumper;
    use YAML();
#     use XXX;
    use YAML::Dumper();
    use YAML::XS();
    use Test::Base::Filter;
    use Error;
    use utf8;
    require "utf8_heavy.pl";
    use Carp::Heavy;
    delete $ENV{PERL5LIB};
    @INC = qw(lib);
}

package t::TestYAMLPerl::Filter;
use Test::Base::Filter -base;

sub yaml_load {
    YAML::XS::Load @_;
}

# use XXX;
sub assert_dump {
    my $values = $self->{current_block}{original_values};
    for my $key (@_) {
        my $value = $values->{$key} or next;
        next unless $value =~ /\S/;
        $value =~ s/\n+\z/\n/;
        return $value;
    }
    return '';
}

sub assert_dump_for_emit {
    return $self->assert_dump((qw(dump dump_emit yaml)));
}

sub assert_dump_for_dumper {
    return $self->assert_dump((qw(dump dump_dumper yaml)));
}
