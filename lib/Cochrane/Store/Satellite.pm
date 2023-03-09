package Cochrane::Store::Satellite;

use Astro::Coord::ECI::TLE;
use Astro::Coord::ECI::TLE::Set;

use Cochrane::Input::HTTP;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    FILES => [ qw/ amateur.txt gps-ops.txt stations.txt starlink.txt weather.txt / ],
    PREFIX => 'tle',
};

sub get_all {
    my ($self) = @_;

    my @result;
    FILE: for my $file (@{$self->FILES}) {
        my $data = $self->read_file($self->PATH_CACHE.'/'.$self->PREFIX.'/'.$file);
        next FILE unless $data;
        $data = [ Astro::Coord::ECI::TLE->parse($data) ];
        next FILE unless scalar(@{$data}) > 0;
        $data = [ Astro::Coord::ECI::TLE::Set->aggregate(@{$data}) ];
        next FILE unless scalar(@{$data}) > 0;
        push @result, @{$data};
    }
    return @result;
}

sub update {
    my ($self) = @_;

    for my $file (@{$self->FILES}) {
        my $request = "http://celestrak.com/NORAD/elements/$file";
        print "fetching $request\n";
        my $response = Cochrane::Input::HTTP->get($request);
        $self->write_file($self->PATH_CACHE().'/'.$self->PREFIX.'/'.$file, $response);
    }
}

1;
