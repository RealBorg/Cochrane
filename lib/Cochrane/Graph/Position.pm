package Cochrane::Graph::Position;

use parent 'Cochrane::Graph';

use Cochrane::Store::Position;
use GD;

use Time::HiRes qw//;

use POSIX qw//;
$ENV{TZ} = 'UTC';
POSIX::tzset();

my $DEBUG = 1;

use strict;
use warnings;

sub new {
    my ($self, $opt) = @_;

    $opt->{width} ||= $self->WIDTH();
    $opt->{height} ||= $self->HEIGHT();
    my $portrait = $opt->{height} > $opt->{width};
    my $time = time();

    my $position = Cochrane::Store::Position->last;
    return undef unless $position;

    my $img = GD::Image->newTrueColor($opt->{width}, $opt->{height});
    my $white = $img->colorAllocate(255, 255, 255);
    $img->filledRectangle(0, 0, $opt->{width}, $opt->{height}, $white);
    my $black = $img->colorAllocate(0, 0, 0);
    $img->setAntiAliased($black);

    #if ($position->{spd} && $position->{spd} > 0) {
    #    my $x = ($position->{lng} + 180) / 360 * 2**$zoom * 256 - $start_x;
    #    my $y = (1 - log(tan(deg2rad($position->{lat})) + sec(deg2rad($position->{lat})))/pi)/2 * 2**$zoom * 256 - $start_y;
    #    my ($lat, $lng) = $ellipsoid->at($position->{lat}, $position->{lng}, $position->{spd} * 60, $position->{hdg});
    #    my $xn = ($lng + 180) / 360 * 2**$zoom * 256 - $start_x;
    #    my $yn = (1 - log(tan(deg2rad($lat)) + sec(deg2rad($lat)))/pi)/2 * 2**$zoom * 256 - $start_y;
    #    $img->line(int($x), int($y), int($xn), int($yn), gdAntiAliased);
    #    $img->ellipse($x, $y, 10, 10, gdAntiAliased);
    #    $img->ellipse($xn, $yn, 5, 5, gdAntiAliased);
    #}
    my $size = $opt->{width} / 400;
    if ($position) {
        $position->{time} = int(Time::HiRes::time());

        if ($portrait) {
            my $time = POSIX::strftime("%Y-%m-%d %H:%M:%S %Z", localtime($position->{time}));
            $img->stringFT($black, $self->FONT(), 24 * $size, 0, 5 * $size, 30 * $size, $time);
            my $label = $position->stringify();
            $label =~ s/m .*/m/;
            $img->stringFT($black, $self->FONT(), 24 * $size, 0, 5 * $size, 60 * $size, $label);
            my $ecef = $position->stringify_ecef();
            $img->stringFT($black, $self->FONT(), 24 * $size, 0, 25 * $size, 105 * $size, $ecef);
            my $eci = $position->stringify_eci();
            $img->stringFT($black, $self->FONT(), 24 * $size, 0, 25 * $size, 250 * $size, $eci);
            my $g = $position->stringify_g;
            $g =~ s/(\d+\.\d\d\d)\d*/$1/g;
            $img->stringFT($black, $self->FONT(), 24 * $size, 0, 5 * $size, 395 * $size, $g);
            my $sun = $position->stringify_sun;
            $sun =~ s/km /km\n/;
            $img->stringFT($black, $self->FONT(), 24 * $size, 0, 5 * $size, 445 * $size, $sun);
            my $moon = $position->stringify_moon;
            $moon =~ s/km /km\n/;
            $img->stringFT($black, $self->FONT(), 24 * $size, 0, 5 * $size, 520 * $size, $moon);
        } else {
            my $time = POSIX::strftime("%Y-%m-%d %H:%M:%S %Z", localtime($position->{time}));
            $img->stringFT($black, $self->FONT(), 24 * $size, 0, 5 * $size, 30 * $size, $time);
            my $label = $position->stringify();
            $img->stringFT($black, $self->FONT(), 14 * $size, 0, 5 * $size, 55 * $size, $label);
            my $ecef = $position->stringify_ecef();
            $img->stringFT($black, $self->FONT(), 14 * $size, 0, 5 * $size, 80 * $size, $ecef);
            my $eci = $position->stringify_eci();
            $img->stringFT($black, $self->FONT(), 14 * $size, 0, $opt->{width} / 2 - 5 * $size, 80 * $size, $eci);
            my $g = $position->stringify_g;
            $img->stringFT($black, $self->FONT(), 14 * $size, 0, 5 * $size, 165 * $size, $g);
            my $sun = $position->stringify_sun;
            $img->stringFT($black, $self->FONT(), 13 * $size, 0, 5 * $size, 190 * $size, $sun);
            my $moon = $position->stringify_moon;
            $img->stringFT($black, $self->FONT(), 13 * $size, 0, 5 * $size, 210 * $size, $moon);
        }



    }

    return $img;
}

1;
