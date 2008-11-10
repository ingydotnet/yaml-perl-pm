# pyyaml/lib/yaml/error.py

package YAML::Perl::Error;
use strict;
use warnings;
use YAML::Perl::Base -base;

package YAML::Perl::Mark;
use YAML::Perl::Base -base;

field 'name';
field 'index';
field 'line';
field 'column';
field 'buffer';
field 'pointer';

package YAML::Perl::Error::Marked;
use YAML::Perl::Base -base;

1;
