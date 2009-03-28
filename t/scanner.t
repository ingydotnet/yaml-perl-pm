use t::TestYAMLPerl;

use YAML::Perl::Scanner;
use YAML::Perl::Tokens;

spec_file('t/data/parser_emitter');
filters { yaml => [qw'scan_yaml token_string join'] };

run_is yaml => 'tokens';

sub token_string {
    map {
        my $token = ref($_);
#         XXX $_ if $token =~ /Directive/;
        my $string = $token;
        $string =~ s/^YAML::Perl::Token:://;
        if ($_->can('version') and $_->version) {
            $string .= " version " . $_->version;
        }
        if ($_->can('anchor') and $_->anchor) {
            $string .= " anchor " . $_->anchor;
        }
        if ($token =~ /::Directive$/) {
            my $name = $_->name;
            my $value = $_->value;
            $value =~ s/\n/\\n/g;
            $string .= " value $name";
        }
        if ($token =~ /::Scalar$/) {
            my $value = $_->value;
            $value =~ s/\n/\\n/g;
            $string .= " value $value";
        }
        $string .= "\n";
    } @_;
}

sub scan_yaml {
    my $p = YAML::Perl::Scanner->new();
    $p->open($_);
    $p->scan();
}
