use t::TestYAMLPerl 'no_plan';

use YAML::Perl::Loader;

for my $test_name (glob('t/data/*.error')) {
    $test_name =~ s/\.error$//;

    # XXX Fix these later.
    next if $test_name eq 't/data/spec-09-14';
    next if $test_name eq 't/data/spec-05-02-utf8';
    next if $test_name eq 't/data/spec-08-04';

    my $yaml = read_file("$test_name.data");
    my $name = read_file("$test_name.error");
    $name =~ s/\s+/ /g;
    $name =~ s/^ERROR: (.*?)\s*$/$1/;
    
    my $data;
    eval {
        my $loader = YAML::Perl::Loader->new->open($yaml);
        $data = $loader->load();
    };
    print "\n>> $test_name\n$yaml" unless $@;
    use Data::Dumper;
    print Dumper $data unless $@;

    ok $@, "Got Loader error: $name";
}
