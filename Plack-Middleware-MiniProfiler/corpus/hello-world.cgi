#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

package HelloWorld;

use Web::Simple;

use Test::InDistDir;
use Plack::Middleware::MiniProfiler qw' PROF profile ';
use Time::HiRes 'sleep';
use Data::Dumper;
$Data::Dumper::Indent = 1;
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
                my ( $date, $env1, $env2 ) =
                  profile { return ( "" . localtime, Dumper( \%ENV ), Dumper( $env ) ) } $prof->step( "data" );
                profile { sleep rand } $prof->step( "random_sleep" );
                my $includes = profile { $prof->render_includes } $prof->step( "includes" );

                return profile {
                    [
                        200,
                        [],
                        [
"<html><head>$includes</head><body>Hello world! $date<pre>$env1</pre><pre>$env2</pre></body></html>"
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
