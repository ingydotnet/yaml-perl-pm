package YAML::Perl;
use 5.005003;
use strict;
use warnings; # XXX requires 5.6+
use Carp;
use YAML::Perl::Base -base;

$YAML::Perl::VERSION = '0.01_01';

@YAML::Perl::EXPORT = qw'Dump Load';
@YAML::Perl::EXPORT_OK = qw'DumpFile LoadFile freeze thaw';

field dumper_class => -chain,
    -class => '-init',
    -init => '$YAML::Perl::DumperClass || $YAML::DumperClass || "YAML::Perl::Dumper"';
field dumper =>
    -class => '-init',
    -init => '$self->create("dumper")';

field loader_class => -chain,
    -class => '-init',
    -init => '$YAML::Perl::LoaderClass || $YAML::LoaderClass || "YAML::Perl::Loader"';
field loader =>
    -class => '-init',
    -init => '$self->create("loader")';

field resolver_class => -chain,
    -class => '-init',
    -init => '$YAML::Perl::ResolverClass || $YAML::ResolverClass || "YAML::Perl::Resolver"';
field resolver =>
    -class => '-init',
    -init => '$self->create("resolver")';

sub Dump {
    return YAML::Perl->new->dumper->dump(@_);
}

sub Load {
    my $loader = YAML::Perl->new->loader;
    $loader->open(@_);
    return ($loader->load());
}

{
    no warnings 'once';
    *YAML::Perl::freeze = \ &Dump;
    *YAML::Perl::thaw   = \ &Load;
}

sub DumpFile {
    my $OUT;
    my $filename = shift;
    if (ref $filename eq 'GLOB') {
        $OUT = $filename;
    }
    else {
        my $mode = '>';
        if ($filename =~ /^\s*(>{1,2})\s*(.*)$/) {
            ($mode, $filename) = ($1, $2);
        }
        open $OUT, $mode, $filename
          or YAML::Perl::Base->die('YAML_DUMP_ERR_FILE_OUTPUT', $filename, $!);
    }  
    local $/ = "\n"; # reset special to "sane"
    print $OUT Dump(@_);
}

sub LoadFile {
    my $IN;
    my $filename = shift;
    if (ref $filename eq 'GLOB') {
        $IN = $filename;
    }
    else {
        open $IN, $filename
          or YAML::Perl::Base->die('YAML_LOAD_ERR_FILE_INPUT', $filename, $!);
    }
    return Load(do { local $/; <$IN> });
}

1;

=encoding utf8

=head1 NAME

YAML::Perl - Pure Perl Port of PyYAML

=head1 WARNING

This is a very early release. Don't even bother to try this version.

=head1 SYNOPSIS

    use YAML::Perl;

    my %inc = Load Dump %INC;

=head1 DESCRIPTION

PyYAML is the most robust and correct YAML module for a dynamic
language. It is (obviously) written in/for Python. This module is a
complete port of PyYAML to Perl.

=head1 AUTHOR

Ingy döt Net <ingy@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2008. Ingy döt Net.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

=cut
