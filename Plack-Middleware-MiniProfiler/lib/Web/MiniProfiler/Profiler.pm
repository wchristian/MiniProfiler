use strictures;

package Web::MiniProfiler::Profiler;

# VERSION

# ABSTRACT: profiler object for the Plack MiniProfiler

# COPYRIGHT

use Moo;
use lib '../..';
use Web::MiniProfiler::Step;
use Text::Xslate 'mark_raw';
use Data::GUID;

sub {
    my %template_attrs = (
        version => [ is => 'ro', default => sub { __PACKAGE__->VERSION || 0 } ],
        currentId => [ is => 'ro', default => sub { Data::GUID->new->as_string } ],

        path            => [ is => 'ro', default => sub { "/mini_profiler/includes/" } ],
        position        => [ is => 'ro', default => sub { "left" } ],
        showChildren    => [ is => 'ro', default => sub { "false" } ],
        showTrivial     => [ is => 'ro', default => sub { "false" } ],
        maxTracesToShow => [ is => 'ro', default => sub { 15 } ],
        showControls    => [ is => 'ro', default => sub { "false" } ],
        authorized      => [ is => 'ro', default => sub { "true" } ],
    );

    has $_ => @{ $template_attrs{$_} } for keys %template_attrs;

    has template_attrs => ( is => 'ro', default => sub { [ keys %template_attrs ] } );
    has current_step   => ( is => 'rw' );
    has depth          => ( is => 'ro', default => sub { -1 } );
    has children       => ( is => 'ro', default => sub { [] } );
  }
  ->();

sub step {
    my ( $self, $step_name ) = @_;
    return sub {
        my ( $to_profile ) = @_;
        return $self->with_step( $step_name, $to_profile );
    };
}

sub with_step {
    my ( $self, $step_name, $to_profile ) = @_;

    my $step = $self->current_step || $self;

    my $new_step = Web::MiniProfiler::Step->new( name => $step_name, depth => $step->depth + 1 );
    push @{ $step->children }, $new_step;
    $self->current_step( $new_step );

    my @ret;

    # evaluate the try block in the correct context
    if ( wantarray ) {
        @ret = $to_profile->();
    }
    elsif ( defined wantarray ) {
        $ret[0] = $to_profile->();
    }
    else {
        $to_profile->();
    }

    $new_step->ended;
    $self->current_step( $step );

    return wantarray ? @ret : $ret[0];
}

sub render_includes {
    my ( $self ) = @_;

    my %vars;
    $vars{$_} = $self->$_ for @{ $self->template_attrs }, qw( ids );

    my $render_includes = qq#
        <script type="text/javascript">
            (function(){
                var init = function() {
                        var load = function(s,f){
                            var sc = document.createElement("script");
                            sc.async = "async";
                            sc.type = "text/javascript";
                            sc.src = s;
                            var l = false;
                            sc.onload = sc.onreadystatechange  = function(_, abort) {
                                if (!l && (!sc.readyState || /loaded|complete/.test(sc.readyState))) {
                                    if (!abort){l=true; f();}
                                }
                            };

                            document.getElementsByTagName('head')[0].appendChild(sc);
                        };

                        var initMp = function(){
                            load("$vars{path}includes.js?v=$vars{version}",function(){
                                MiniProfiler.init({
                                    ids: $vars{ids},
                                    path: '$vars{path}',
                                    version: '$vars{version}',
                                    renderPosition: '$vars{position}',
                                    showTrivial: $vars{showTrivial},
                                    showChildrenTime: $vars{showChildren},
                                    maxTracesToShow: $vars{maxTracesToShow},
                                    showControls: $vars{showControls},
                                    currentId: '$vars{currentId}',
                                    authorized: $vars{authorized}
                                });
                            });
                        };

                         load('$vars{path}jquery.1.6.2.js?v=$vars{version}', initMp);

                };

                var w = 0;
                var f = false;
                var deferInit = function(){
                    if (f) return;
                    if (window.performance && window.performance.timing && window.performance.timing.loadEventEnd == 0 && w < 10000){
                        setTimeout(deferInit, 100);
                        w += 100;
                    } else {
                        f = true;
                        init();
                    }
                };
                if (document.addEventListener) {
                    document.addEventListener('DOMContentLoaded',deferInit);
                }
                var o = window.onload;
                window.onload = function(){if(o)o; deferInit()};
            })();
        </script>
    #;

    return $render_includes;
}

sub ids {
    my $id = shift->currentId;
    return mark_raw "['$id']";
}

1;
