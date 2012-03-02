#!/usr/bin/perl

use CGI::Carp qw(fatalsToBrowser);

use Test::InDistDir;
use lib 'corpus';
use HelloWorld;

HelloWorld->run_if_script;
