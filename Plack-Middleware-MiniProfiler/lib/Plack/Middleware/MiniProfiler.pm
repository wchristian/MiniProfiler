use strictures;

package Plack::Middleware::MiniProfiler;

# VERSION

# ABSTRACT: Perl backend for mvc-mini-profiler

# COPYRIGHT

use lib '../..';

use Moo;
use Web::MiniProfiler::Profiler;
use Exporter 'import';
use Plack::Request;
use Cache::FileCache;
use JSON 'to_json';
use List::Util 'sum';
use Carp 'croak';
use File::ShareDir 'dist_file';
use File::Slurp 'read_file';

extends 'Plack::Middleware';

has render_includes_tag => ( is => 'ro', default => sub { "<!-- RENDER_INCLUDES -->" } );

our @EXPORT_OK = qw( PROF profile auto_profile );
my %file_cache;

sub PROF () { 'plack.' . __PACKAGE__ . '.profiler' }

sub profile (&;$) {
    my ( $to_profile, $step ) = @_;
    return $step->( $to_profile );
}

sub call {
    my ( $self, $env ) = @_;

    my $res = $self->_handle_static( $env );
    return $res if $res;

    my $uri = Plack::Request->new( $env )->uri . '';
    my $profiled_app = build_profiled_sub( $self->app, $uri );

    my $prof = $env->{ +PROF } = Web::MiniProfiler::Profiler->new;
    $res = $profiled_app->( $env );

    $self->try_insert_render_includes( $res, $prof );

    $self->save( $prof );

    return $res;
}

sub auto_profile {
    my ( $sub_name, $prof_get_sub ) = @_;

    my $old_sub = do {
        no strict 'refs';
        *$sub_name{CODE};
    };
    my $new_sub = build_profiled_sub( $old_sub, $sub_name, $prof_get_sub );
    {
        no strict 'refs';
        no warnings 'redefine';
        *$sub_name = $new_sub;
    }

    return;
}

sub build_profiled_sub {
    my ( $sub, $step_name, $prof_get_sub ) = @_;

    $prof_get_sub ||= sub {
        my @args = @_;
        my $env  = pop @args;
        return $env->{ +PROF };
    };

    return sub {
        my @args = @_;
        my $prof = $prof_get_sub->( @args );
        return $sub->( @args ) if !$prof;
        return $prof->with_step( $step_name, sub { $sub->( @args ) } );
    };
}

sub try_insert_render_includes {
    my ( $self, $res, $prof ) = @_;

    my $render_includes_tag = $self->render_includes_tag;
    my $render_includes     = $prof->render_includes;

    for ( @{ $res->[2] } ) {
        next if ref $_;
        $_ =~ s/$render_includes_tag/$render_includes/;
    }

    return;
}

sub save {
    my ( $self, $prof ) = @_;

    my $cache = Cache::FileCache->new( { namespace => "miniprofiler" } );
    $cache->set( $prof->currentId, $prof );

    return;
}

sub _handle_static {
    my ( $self, $env ) = @_;

    my $path = $env->{PATH_INFO};

    $path =~ s@/mini_profiler/includes/@@;

    my %known_files = map { $_ => 1 } qw( jquery.1.6.2.js jquery.tmpl.js includes.js includes.css includes.tmpl );

    my $content;
    $content = $self->share( $path ) if $known_files{$path};
    return [ 200, [ 'Content-type' => 'text/plain', "Cache-Control" => "max-age=2600000" ], [$content] ] if $content;

    $content = $self->results( $env ) if $path eq 'results';
    return [ 200, [ 'Content-type' => 'text/plain' ], [$content] ] if $content;

    return;
}

sub share {
    my ( $self, $file ) = @_;

    my $cache = $self->file_cache;
    return $cache->{$file} if $cache->{$file};

    my $dist = __PACKAGE__;
    $dist =~ s/::/-/g;

    my $path = eval { dist_file( $dist, $file ) };
    $path ||= "../StackExchange.Profiling/UI/$file";

    $cache->{$file} = read_file $path;

    return $cache->{$file};
}

sub file_cache { \%file_cache }

sub results {
    my ( $self, $env ) = @_;

    $self->{trivial_limit} = 2;

    my $params = Plack::Request->new( $env )->parameters;

    my $timing = $self->client_timing( $params );

    my $cache = Cache::FileCache->new( { namespace => "miniprofiler" } );
    my $thing = $cache->get( $params->{id} );

    my $root  = $thing->{children}[0];
    my $start = int $root->{started} * 1000;
    my $dur   = ( $root->{ended} - $root->{started} ) * 1000;

    $root = $self->child_to_result( $root, $root );

    my $result = {
        Id                   => $thing->{currentId},
        Started              => "/Date($start)/",
        DurationMilliseconds => $dur,
        ClientTimings        => $timing,
        Root                 => $root,
        HasTrivialTimings    => $self->{has_trivial},
        MachineName          => $env->{HOSTNAME} || $env->{COMPUTERNAME} || $env->{SERVER_NAME} || $env->{SERVER_ADDR},
        Name                 => $env->{PATH_INFO},
    };
    my $json = to_json $result, { utf8 => 1, pretty => 1 };

    return $json;
}

sub client_timing {
    my ( $self, $params ) = @_;
    my $nav_start = $params->{"clientPerformance[timing][navigationStart]"};
    return if !$params->{"clientPerformance[timing][navigationStart]"};

    my %timing = map param_to_timing( $_, $params->{$_} ), keys %{$params};

    $_ -= $nav_start for values %timing;
    $timing{RedirectCount} = $params->{"clientPerformance[navigation][redirectCount]"};

    for ( keys %timing ) {
        next if $timing{$_} >= 0;
        delete $timing{$_};
    }

    $self->{has_trivial}++ if grep { $_ < $self->{trivial_limit} } values %timing;

    return \%timing;
}

sub param_to_timing {
    my ( $key, $val ) = @_;

    $key =~ /clientPerformance\[\w+\]\[(.*)\]/;
    return if !$1;

    $key = ucfirst $1;

    return ( $key, $val );
}

sub child_to_result {
    my ( $self, $root, $child ) = @_;

    my @children = map $self->child_to_result( $root, $_ ), @{ $child->{children} };

    my $start    = $child->{started} - $root->{started};
    my $duration = $child->{ended} - $child->{started};
    $_ *= 1000 for ( $start, $duration );

    my $duration_chld = sum 0, map $_->{DurationMilliseconds}, @children;
    my $duration_excl = $duration - $duration_chld;
    my $has_children;
    $has_children = 1 if @children;

    my $is_trivial = 0;
    if ( $duration < $self->{trivial_limit} ) {
        $is_trivial = 1;
        $self->{has_trivial}++;
    }

    my $result = {
        Name                                => $child->{name},
        Children                            => \@children,
        Depth                               => $child->{depth},
        StartMilliseconds                   => $start,
        DurationMilliseconds                => $duration,
        DurationWithoutChildrenMilliseconds => $duration_excl,
        HasChildren                         => $has_children,
        IsTrivial                           => $is_trivial,
    };

    return $result;
}

1;
