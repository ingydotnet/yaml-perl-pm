use t::TestYAMLPerl;

skip_all_unless_require('Test::Deep');

plan tests => 3;

use YAML::Perl;

my $data = [ [ 1, 2] ];
push @$data, $data->[0];

my $yaml = Dump($data);

is $yaml, <<'...', 'Refs get Dumped';
---
- &1
  - 1
  - 2
- *1
...

my $data2 = Load($yaml);

is_deep $data2, $data, 'Refs get Loaded';

ok(($data2->[0] == $data2->[1]), 'Data elements are identical');
