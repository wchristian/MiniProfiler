use strictures;

package Web::MiniProfiler::Step;

# VERSION

# ABSTRACT: profiler step for the Plack MiniProfiler

# COPYRIGHT

use Moo;
use Time::HiRes 'time';

sub {
    has depth    => ( is => 'ro', required => 1 );
    has name     => ( is => 'ro', required => 1 );
    has started  => ( is => 'ro', default  => sub { time } );
    has children => ( is => 'ro', default  => sub { [] } );
    has ended    => ( is => 'ro', lazy     => 1, default => sub { time } );
  }
  ->();

1;
