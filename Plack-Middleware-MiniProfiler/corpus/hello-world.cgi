#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

package ProfiledHelloWorld;

use Web::Simple;
use Web::Dispatch;
use HelloWorld;
use Plack::Middleware::MiniProfiler qw' auto_profile ';

auto_profile( "HelloWorld::$_" ) for qw( main data random_sleep );
auto_profile( "Web::Dispatch::call" );

__PACKAGE__->run_if_script;

sub dispatch_request {
    my $app = HelloWorld->to_psgi_app;
    return Plack::Middleware::MiniProfiler->wrap( $app );
}
