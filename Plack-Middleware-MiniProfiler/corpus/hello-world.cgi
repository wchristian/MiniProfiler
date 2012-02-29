#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

package HelloWorld;

use Web::Simple;

use Test::InDistDir;
use Plack::Middleware::MiniProfiler qw' PROF profile ';
use Time::HiRes 'sleep';
use Data::Dumper;
$Data::Dumper::Indent   = 1;
$Data::Dumper::Sortkeys = 1;

sub dispatch_request {
    (
        sub () {
            Plack::Middleware::MiniProfiler->new;
        },
        sub (GET) {
            my ( $self, $env ) = @_;

            my $prof = $env->{ +PROF };

            return profile {
                my ( $date, $env2 ) = profile {
                    my $env = { %{$env} };
                    delete $env->{"Web::Dispatch.original_env"};
                    return ( "" . localtime, Dumper( $env ) );
                }
                $prof->step( "data" );
                profile { sleep rand } $prof->step( "random_sleep" );

                return profile {
                    [
                        200,
                        [],
                        [
                            <<"MEEP"
<html>
    <head>{{RENDER_INCLUDES}}</head>
    <body>
        <br />
        <h1>Hello world! $date</h1>
        <p style="text-align: justify;width: 30em;">
            This website is running an early demo of a Perl port of
            <a href="http://code.google.com/p/mvc-mini-profiler/">MVC-MiniProfiler</a>.
            You can <a href="https://github.com/wchristian/MiniProfiler">check
            out the source</a> on Github and will soon find it on a nearby CPAN
            mirror.
        </p>
        <p style="text-align: justify;width: 30em;">
            Here is an example of the Plack environment, containing the Profiler
            object during rendering phase:
        </p>
        <pre>$env2</pre>
    </body>
</html>
MEEP
                        ]
                    ];
                }
                $prof->step( "response" );
            }
            $prof->step( "main" );
        },
        sub () {
            [ 405, [ 'Content-type', 'text/plain' ], ['Method not allowed'] ];
        }
    );
}

__PACKAGE__->run_if_script;
