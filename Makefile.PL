use inc::Module::Install;

name 'YAML-Perl';

all_from 'lib/YAML/Perl.pm';

requires 'Error'                => 0;

use_test_base;
use_testml_tap;

clean_files 'pyyaml/lib/yaml/*.pyc';

# auto_install;

WriteAll;
