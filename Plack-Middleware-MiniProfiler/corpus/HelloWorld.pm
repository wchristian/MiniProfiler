use strictures;

package HelloWorld;

use Web::Simple;

use Test::InDistDir;
use Time::HiRes 'sleep';
use Data::Dumper;
use Plack::Middleware::MiniProfiler 'PROF';

sub dispatch_request {
    (
        'GET' => \&main,
        ''    => sub { [ 405, [ 'Content-type', 'text/plain' ], ['Method not allowed'] ] }
    );
}

sub main {
    my ( $self, $env ) = @_;

    my ( $date, $profiler_status, $env2 ) = $self->data( $env );
    $self->random_sleep( $env );

    return [ 200, [], [ sprintf( $self->template, $date, $profiler_status, $env2 ) ] ];
}

sub data {
    my ( $self, $env ) = @_;

    my $profiler_status =
        'This is the unprofiled version. It runs the same '
      . 'framework code as the <a href="/">profiled version</a>, only '
      . 'without the profiler middleware.';
    $profiler_status =
        'This is the profiled version. It runs the same '
      . 'framework code as the <a href="/plain">unprofiled version</a>, only '
      . 'with the profiler middleware.'
      if $env->{ +PROF };
    $profiler_status .= " You can easily switch between the two without having to modify your code.";

    my $env2 = { %{$env} };
    delete $env2->{"Web::Dispatch.original_env"};

    local $Data::Dumper::Indent   = 1;
    local $Data::Dumper::Sortkeys = 1;
    $env2 = Dumper( $env2 );

    my $date = "" . localtime;

    return ( $date, $profiler_status, $env2 );
}

sub random_sleep { sleep( rand() / 5 ) }

sub template {
    <<'MEEP'
<html>
    <head><!-- RENDER_INCLUDES --></head>
    <body>
        <br />
        <h1>Hello world! %s</h1>
        <p style="text-align: justify;width: 30em;">
            This website is running an early demo of a Perl port of
            <a href="http://code.google.com/p/mvc-mini-profiler/">MVC-MiniProfiler</a>.
            You can <a href="https://github.com/wchristian/MiniProfiler">check
            out the source</a> on Github and will soon find it on a nearby CPAN
            mirror.
        </p>
        <p style="text-align: justify;width: 30em;">%s</p>
        <p style="text-align: justify;width: 30em;">
            Here is an example of the Plack environment, containing the Profiler
            object (for the profiled version) during rendering phase:
        </p>
        <pre>%s</pre>
    </body>
</html>
MEEP
}

1;
