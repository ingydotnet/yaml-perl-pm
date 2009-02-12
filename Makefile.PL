use inc::Module::Install;

name 'YAML-Perl';

all_from 'lib/YAML/Perl.pm';

requires 'Error'                => 0;

test_requires 'Test::Base'      => 0;
test_requires 'Devel::Trace'    => 0;

clean_files 'pyyaml/lib/yaml/*.pyc';

auto_install;

WriteAll;
