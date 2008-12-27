import sys
sys.path.insert(0, '/Users/ingy/src/cpan/YAML-Perl/pyyaml/lib')
import yaml
for x in yaml.load_all("- 1\n- 2\n- 3\n"):
    pass
