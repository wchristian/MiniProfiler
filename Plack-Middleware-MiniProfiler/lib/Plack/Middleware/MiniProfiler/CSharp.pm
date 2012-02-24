use strictures;

package Plack::Middleware::MiniProfiler::CSharp;

use File::Slurp 'read_file';
use Text::Balanced qw'extract_bracketed extract_multiple';

# VERSION

# ABSTRACT: profiler object for the Plack MiniProfiler

# COPYRIGHT

my $text = read_file( "../../../../../StackExchange.Profiling/UI/MiniProfilerHandler.cs" );

my ( undef, $res, undef ) = extract_multiple( $text, [ sub { extract_bracketed( $_[0], '{}', qr/[^{]*/s ) } ] );
$res =~ s/\{(.*)\}/$1/s;
( undef, $res, undef ) = extract_multiple( $res, [ sub { extract_bracketed( $_[0], '{}', qr/[^{]*/s ) } ] );
$res =~ s/\{(.*)\}/$1/s;

my @res = extract_multiple( $res, [ sub { extract_bracketed( $_[0], '{}', qr/[^{]*/s ) } ], 999 );
pop @res;

my %funcs;
for ( 0 .. ( $#res / 2 - 1 ) ) {
    my $id  = $_ * 2;
    my $key = $res[$id];
    $key =~ s/.* (\w+)(\(.*\)|)\n.*/$1/s;
    $funcs{$key} = $res[ $id + 1 ];
}

my $render_includes = $funcs{RenderIncludes};
$render_includes =~ s/.*@"(<script.*script>)";.*/$1/s;
$render_includes =~ s/""/"/g;
$render_includes =~ s/{{/{/g;
$render_includes =~ s/}}/}/g;
$render_includes =~ s/\{(\w+)\}/\$vars{$1}/g;

1;
