use TestML -run, -bridge => 't::Bridge';
__END__
%TestML: 1.0
%PointMarker: +++
%Data: data/parser_emitter

$perl.eval().dump_yaml() == $dump;

