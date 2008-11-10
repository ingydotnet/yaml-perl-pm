# use Devel::TraceSubs;
use t::TestYAMLPerl tests => 1;

use YAML::Perl;
use YAML::Perl::Loader;
use YAML::Perl::Constructor;
use YAML::Perl::Composer;
use YAML::Perl::Parser;
use YAML::Perl::Scanner;
use YAML::Perl::Reader;

# sub trace {}
# Devel::TraceSubs->new(
#     verbose => 1,
#     level => '  ',
#     params => 0,
# #    wrap => ["", ''],
#     logger => sub { 
#         return if $_[2] eq '<';
#         my $line = join '', splice(@_, 0, 6);
#         my $args = join ', ', map {
#             defined($_)
#             ? ref($_) =~ /^YAML/
#                 ? '$self'
#                 : do {
#                     my $x = $_;
# #                     s/\n/\\n/g
# #                       unless ref($x);
#                     qq{"$x"};
#                 }
#             : '~';
#         } @_;
#         print "$line($args)\n";
#     },
# );# ->
# trace(
#     'YAML::Perl::',
#     'YAML::Perl::Base::',
#     'YAML::Perl::Processor::',
#     'YAML::Perl::Loader::',
#     'YAML::Perl::Constructor::',
#     'YAML::Perl::Composer::',
#     'YAML::Perl::Parser::',
#     'YAML::Perl::Scanner::',
#     'YAML::Perl::Reader::',
# );

use YAML::Perl;

is_deeply XXX YAML::Perl::Load("---\n- 4\n- 4\n"), [2, 4],
    'Test YAML::Perl::Load';
