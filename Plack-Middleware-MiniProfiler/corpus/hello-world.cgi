#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

package ProfiledHelloWorld;

use Web::Simple;
use HelloWorld;
use Plack::Middleware::MiniProfiler qw' auto_profile ';

auto_profile( "HelloWorld::$_" ) for qw( main data random_sleep );

__PACKAGE__->run_if_script;

sub dispatch_request {
    (
        '' => sub { Plack::Middleware::MiniProfiler->new },
        '' => sub { HelloWorld->to_psgi_app },
    );
}
