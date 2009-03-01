import sys
sys.path.insert(0, '/Users/ingy/src/ingydotnet/YAML-Perl/pyyaml/lib')
import yaml
for x in yaml.load_all("%TAG !! tag:yaml.org,2002:\n!!str 42: !!float 42\n"):
    pass
