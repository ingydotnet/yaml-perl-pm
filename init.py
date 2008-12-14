import sys
sys.path.insert(0, '/Users/ingy/src/cpan/YAML-Perl/pyyaml/lib')
import yaml
for x in yaml.parse("42: 53\n"):
    pass
