use t::TestYAMLPerl tests => 3 * 2;

test('YAML::Perl');
test('YAML::Perl::Dumper');

sub test {
    my $class = shift;
    eval "require $class";

    no strict 'refs';
    ok defined(&{$class . "::field"}),
        "$class class has field() exported to it";
    ok not(defined(&YAML::Perl::const)),
        "$class class does not have const() exported to it";
    ok defined(&YAML::Perl::XXX),
        "$class class has XXX() exported to it";
}
