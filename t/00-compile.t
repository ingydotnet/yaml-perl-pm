use t::TestYAMLPerl tests => 16 * 2 - 2;

# These are all of the (Perl version of the) modules that PyYaml defines:
my @modules = (qw'
    YAML::Perl
    YAML::Perl::Composer
    YAML::Perl::Constructor
    YAML::Perl::Dumper
    YAML::Perl::Emitter
    YAML::Perl::Error
    YAML::Perl::Events
    YAML::Perl::Loader
    YAML::Perl::Nodes
    YAML::Perl::Parser
    YAML::Perl::Reader
    YAML::Perl::Representer
    YAML::Perl::Resolver
    YAML::Perl::Scanner
    YAML::Perl::Serializer
    YAML::Perl::Tokens
');

for my $module (@modules) {
    use_ok($module);
    next if $module eq 'YAML::Perl::Events';
    next if $module eq 'YAML::Perl::Nodes';
    eval { $module->new() };
    is("$@", '', "Make a $module object");
}
