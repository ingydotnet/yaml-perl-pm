use t::TestYAMLPerl tests => 2;

use YAML::Perl::Composer;
use YAML::Perl::Events;

spec_file('t/data/parser_emitter');
filters {
    yaml => [qw'compose_yaml'],
    nodes => 'yaml_load',
};

run {
    my $block = shift;
    my (@nodes) = @{$block->{yaml}};
    my (@want) = @{$block->{nodes}}; 
    like ref($nodes[0]), qr/^YAML::Perl::Node::/,
        'compose() produces a YAML node';
};

sub make_events {
    map {
       my ($event, @args) = split;
       "YAML::Perl::Event::$event"->new(@args);
   } @_;
}

sub event_string {
    map {
        my $string = ref($_);
        $string =~ s/^YAML::Perl::Event:://;
        if ($string eq 'Scalar') {
            $string .= " value " . $_->value;
        }
        $string .= "\n";
    } @_;
}

sub compose_yaml {
    my $c = YAML::Perl::Composer->new();
    $c->open($_);
    $c->compose();
}
