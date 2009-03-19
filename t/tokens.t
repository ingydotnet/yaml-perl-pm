use t::TestYAMLPerl tests => 28;

use YAML::Perl::Scanner;

my $symbol = {
    "YAML::Perl::Token::Directive" => '%',
    "YAML::Perl::Token::DocumentStart" => '---',
    "YAML::Perl::Token::DocumentEnd" => '...',
    "YAML::Perl::Token::Alias" => '*',
    "YAML::Perl::Token::Anchor" => '&',
    "YAML::Perl::Token::Tag" => '!',
    "YAML::Perl::Token::Scalar" => '_',
    "YAML::Perl::Token::BlockSequenceStart" => '[[',
    "YAML::Perl::Token::BlockMappingStart" => '{{',
    "YAML::Perl::Token::BlockEnd" => ']}',
    "YAML::Perl::Token::FlowSequenceStart" => '[',
    "YAML::Perl::Token::FlowSequenceEnd" => ']',
    "YAML::Perl::Token::FlowMappingStart" => '{',
    "YAML::Perl::Token::FlowMappingEnd" => '}',
    "YAML::Perl::Token::BlockEntry" => ',',
    "YAML::Perl::Token::FlowEntry" => ',',
    "YAML::Perl::Token::Key" => '?',
    "YAML::Perl::Token::Value" => ':',
};

for my $test_name (glob('t/data/spec-02-*.tokens')) {
    $test_name =~ s/\.tokens$//;

    my $yaml = read_file("$test_name.data");
    
    my $scanner = YAML::Perl::Scanner->new->open($yaml);
    my $result = join ' ', map {
        $symbol->{$_};
    } grep {
        exists $symbol->{$_};
    } map ref($_), $scanner->scan;

    my $expected = join ' ', split /\s+/, read_file("$test_name.tokens");

    is $result, $expected, $test_name;
}
