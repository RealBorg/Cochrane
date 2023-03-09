package Cochrane::Graph::Map;

use parent 'Cochrane::Graph';

use Cochrane::Store::Airport;
use Cochrane::Store::Navaid;
use Cochrane::Store::Plane;
use Cochrane::Store::Position;
use Cochrane::Store::Satellite;
use Cochrane::Store::Tile;

use GD;
use GD::Polyline;
use Geo::Ellipsoid;
my $ellipsoid = Geo::Ellipsoid->new(
    ellipsoid => 'WGS84',
    units => 'degrees',
    distance_units => 'meter',
);

use Math::Trig;
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
    $opt->{zoom} ||= 12;

    my $time_spent = Time::HiRes::time();

    my $position = Cochrane::Store::Position->last;
    return undef unless $position;

    my $xtile = ($position->{lng} + 180) / 360 * 2**$opt->{zoom};
    my $ytile = (1 - log(tan(deg2rad($position->{lat})) + sec(deg2rad($position->{lat})))/pi)/2 * 2**$opt->{zoom};

    my $xpos = $xtile * 256;
    my $ypos = $ytile * 256;

    my $start_x = $xpos - $opt->{width} / 2;
    my $start_y = $ypos - $opt->{height} / 2;
    my $end_x = $xpos + $opt->{width} / 2;
    my $end_y = $ypos + $opt->{height} / 2;

    my $start_lng = ($start_x / 256) / 2**$opt->{zoom} * 360 - 180;
    my $start_lat = rad2deg(atan(sinh(pi * (1 - 2 * ($end_y / 256) / 2**$opt->{zoom}))));
    my $end_lng = ($end_x / 256) / 2**$opt->{zoom} * 360 - 180;
    my $end_lat = rad2deg(atan(sinh(pi * (1 - 2 * ($start_y / 256) / 2**$opt->{zoom}))));

    #prefetch tiles
    my $img = GD::Image->newTrueColor($opt->{width}, $opt->{height});
    my $black = $img->colorAllocate(0,0,0);
    #my $white = $img->colorAllocate(255, 255, 255);
    my $gray = $img->colorAllocate(127, 127, 127);
    my $bg = $img->colorAllocateAlpha(255, 255, 255, 63);
    $img->setAntiAliased($black);

    X: for (my $x = int($start_x / 256); $x <= int($end_x / 256); $x++) {
        next X if $x < 0;
        next X if $x >= 2**$opt->{zoom};
        Y: for (my $y = int($start_y / 256); $y <= int($end_y / 256); $y++) {
            next Y if $y < 0;
            next Y if $y >= 2**$opt->{zoom};
            my $tile = Cochrane::Store::Tile->get($x, $y, $opt->{zoom});
            $tile = GD::Image->new($tile);
            $img->copy($tile, $x * 256 - $start_x, 256 * $y - $start_y, 0, 0, 256, 256);
        }
    }

    my @planes = Cochrane::Store::Plane->list;
    PLANE: for my $plane (@planes) {
        $plane = Cochrane::Store::Plane->get($plane);
        next unless $plane;
        if ($plane->{lat} && $plane->{lng}) {
            next unless $plane->{lat} > $start_lat && $plane->{lat} < $end_lat && $plane->{lng} > $start_lng && $plane->{lng} < $end_lng;
            my $x = ($plane->{lng} + 180) / 360 * 2**$opt->{zoom} * 256 - $start_x;
            my $y = (1 - log(tan(deg2rad($plane->{lat})) + sec(deg2rad($plane->{lat})))/pi)/2 * 2**$opt->{zoom} * 256 - $start_y;
            #next PLANE unless $x > 0 && $x < $img->width && $y > 0 && $y < $img->height;
            my $label = eval {
                sprintf(
                    "%s %s %.0fm %.0fkm/h %.0fkm %.0fs",
                    $plane->{icao},
                    $plane->{flight} || '',
                    $plane->{altitude} || 0,
                    ($plane->{spd} || 0) * 3.6,
                    ($plane->{distance} || 0) / 1000,
                    Time::HiRes::time() - $plane->{seen},
                );
            };
            {
                my @bounds = $img->stringFT(gdAntiAliased, $self->FONT(), 7, 0, $x + 10, $y, $label);
                $img->filledRectangle($bounds[6], $bounds[7], $bounds[2], $bounds[3], $bg);
                $img->stringFT(gdAntiAliased, $self->FONT(), 7, 0, $x + 10, $y, $label);
            }
            $img->ellipse($x, $y, 10, 10, gdAntiAliased);
            if ($plane->{hdg} && $plane->{spd}) {
                my ($lat_h, $lng_h) = $ellipsoid->at($plane->{lat}, $plane->{lng}, $plane->{spd} * 20, $plane->{hdg});
                my $x_h = ($lng_h + 180) / 360 * 2**$opt->{zoom} * 256 - $start_x;
                my $y_h = (1 - log(tan(deg2rad($lat_h)) + sec(deg2rad($lat_h)))/pi)/2 * 2**$opt->{zoom} * 256 - $start_y;
                $img->line(int($x), int($y), int($x_h), int($y_h), gdAntiAliased);
                $img->ellipse($x_h, $y_h, 5, 5, gdAntiAliased);
            }
            my $path = $plane->{path};
            if (scalar(@{$path}) > 1) {
                my $spline = GD::Polyline->new;
                $img->setAntiAliased($gray);
                $img->setStyle(gdTransparent, gdAntiAliased);
                for my $pos (@{$path}) {
                    my $x_pos = ($pos->{lng} + 180) / 360 * 2**$opt->{zoom} * 256 - $start_x;
                    my $y_pos = (1 - log(tan(deg2rad($pos->{lat})) + sec(deg2rad($pos->{lat})))/pi)/2 * 2**$opt->{zoom} * 256 - $start_y;
                    next unless $x_pos > 0 && $x_pos < $img->width && $y_pos > 0 && $y_pos < $img->height;
                    $spline->addPt($x_pos, $y_pos);
                    $img->ellipse($x_pos, $y_pos, 2, 2, gdAntiAliased);
                }
                $img->polyline($spline, gdStyled);
                $img->setAntiAliased($black);
            }
        }
    }
    if ($opt->{zoom} > 6) {
        AIRPORT: for my $ap (Cochrane::Store::Airport->get_all) {
            next AIRPORT unless $ap->{latitude} && $ap->{latitude} > $start_lat && $ap->{latitude} < $end_lat;
            next AIRPORT unless $ap->{longitude} && $ap->{longitude} > $start_lng && $ap->{longitude} < $end_lng;
            next AIRPORT if $ap->{type} eq 'large_airport' && $opt->{zoom} < 7;
            next AIRPORT if $ap->{type} eq 'medium_airport' && $opt->{zoom} < 8;
            next AIRPORT if $ap->{type} eq 'small_airport' && $opt->{zoom} < 9;
            next AIRPORT if $ap->{type} eq 'closed' && $opt->{zoom} < 10;
            next AIRPORT if $ap->{type} eq 'seaplane_base' && $opt->{zoom} < 11;
            next AIRPORT if $ap->{type} eq 'heliport' && $opt->{zoom} < 11;
            next AIRPORT if $ap->{type} eq 'balloonport' && $opt->{zoom} < 12;
            my $x = ($ap->{longitude} + 180) / 360 * 2**$opt->{zoom} * 256 - $start_x;
            my $y = (1 - log(tan(deg2rad($ap->{latitude})) + sec(deg2rad($ap->{latitude})))/pi)/2 * 2**$opt->{zoom} * 256 - $start_y;
            my $label = sprintf("%s", $ap->{ident});
            if ($ap->{elevation}) {
                my $label = sprintf("%s %.0fm", $ap->{ident}, $ap->{elevation} * 0.3048);
            }
            $img->stringFT(gdAntiAliased, $self->FONT(), 7, 0, $x + 10, $y, $label);
        }
    }
    if ($opt->{zoom} > 6) {
        NAVAID: for my $na (Cochrane::Store::Navaid->get_all) {
            next NAVAID unless $na->{latitude} && $na->{latitude} > $start_lat && $na->{latitude} < $end_lat;
            next NAVAID unless $na->{longitude} && $na->{longitude} > $start_lng && $na->{longitude} < $end_lng;
            my $x = ($na->{longitude} + 180) / 360 * 2**$opt->{zoom} * 256 - $start_x;
            my $y = (1 - log(tan(deg2rad($na->{latitude})) + sec(deg2rad($na->{latitude})))/pi)/2 * 2**$opt->{zoom} * 256 - $start_y;
            my $label = sprintf("%s %.0fm", $na->{ident}, $na->{elevation} * 0.3048);
            $img->stringFT(gdAntiAliased, $self->FONT(), 7, 0, $x + 10, $y, $label);
        }
    }

    {
        my $start = time();
        my $end = $start + 60;
        SATELLITE: for my $sat (Cochrane::Store::Satellite->get_all) {
            next SATELLITE unless $sat->validate($start, $end);
            my $name = $sat->get('name');
            my ($lat, $lng, $alt) = $sat->model($start)->geodetic;
            $lat = rad2deg($lat);
            $lng = rad2deg($lng);
            $alt *= 1000;
            next unless $lat > $start_lat && $lat < $end_lat && $lng > $start_lng && $lng < $end_lng;
            my $x = ($lng + 180) / 360 * 2**$opt->{zoom} * 256 - $start_x;
            my $y = (1 - log(tan(deg2rad($lat)) + sec(deg2rad($lat)))/pi)/2 * 2**$opt->{zoom} * 256 - $start_y;
            $img->ellipse($x, $y, 10, 10, gdAntiAliased);
            my $label = sprintf("%s %.0fm", $name, $alt);
            $img->stringFT(gdAntiAliased, $self->FONT(), 7, 0, $x + 10, $y, $label);
            my ($lat_p, $lng_p, $alt_p) = $sat->model($end)->geodetic;
            $lat_p = rad2deg($lat_p);
            $lng_p = rad2deg($lng_p);
            $alt_p *= 1000;
            my $x_p = ($lng_p + 180) / 360 * 2**$opt->{zoom} * 256 - $start_x;
            my $y_p = (1 - log(tan(deg2rad($lat_p)) + sec(deg2rad($lat_p)))/pi)/2 * 2**$opt->{zoom} * 256 - $start_y;
            $img->line(int($x), int($y), int($x_p), int($y_p), gdAntiAliased);
            $img->ellipse($x_p, $y_p, 5, 5, gdAntiAliased);
        }
    }
    if ($position->{spd} && $position->{spd} > 0) {
        my $x = ($position->{lng} + 180) / 360 * 2**$opt->{zoom} * 256 - $start_x;
        my $y = (1 - log(tan(deg2rad($position->{lat})) + sec(deg2rad($position->{lat})))/pi)/2 * 2**$opt->{zoom} * 256 - $start_y;
        my ($lat, $lng) = $ellipsoid->at($position->{lat}, $position->{lng}, $position->{spd} * 60, $position->{hdg});
        my $xn = ($lng + 180) / 360 * 2**$opt->{zoom} * 256 - $start_x;
        my $yn = (1 - log(tan(deg2rad($lat)) + sec(deg2rad($lat)))/pi)/2 * 2**$opt->{zoom} * 256 - $start_y;
        $img->line(int($x), int($y), int($xn), int($yn), gdAntiAliased);
        $img->ellipse($x, $y, 10, 10, gdAntiAliased);
        $img->ellipse($xn, $yn, 5, 5, gdAntiAliased);
    }
    if ($position->{lat} && $position->{lng}) {
        my $label = sprintf(
            "%.4f %s %.4f %s %.0fkm/h %.0f° %.0fm %.0fs", 
            $position->{lat}, 
            $position->{lat} >= 0 ? 'N' : 'S',
            $position->{lng},
            $position->{lng} >= 0 ? 'E' : 'W',
            ($position->{spd} || 0) * 3.6,
            $position->{hdg} || 0,
            $position->{alt},
            Time::HiRes::time() - $position->{time},
        );
        my @bounds = $img->stringFT(gdAntiAliased, $self->FONT(), 8, 0, 5, 10, $label);
        $img->filledRectangle($bounds[6], $bounds[7], $bounds[2], $bounds[3], $bg);
        $img->stringFT(gdAntiAliased, $self->FONT(), 8, 0, 5, 10, $label);
    }
    if ($position->{time}) {
        my $label = POSIX::strftime("%Y-%m-%d %H:%M:%S %Z", localtime());
        my $x = 5;
        my $y = $img->height - 10;
        my @bounds = $img->stringFT(gdAntiAliased, $self->FONT(), 8, 0, $x, $y, $label);
        $img->filledRectangle($bounds[6], $bounds[7], $bounds[2], $bounds[3], $bg);
        $img->stringFT(gdAntiAliased, $self->FONT(), 8, 0, $x, $y, $label);
    }
    $img->setStyle($black, gdTransparent, gdTransparent);
    $img->line(0, $img->height / 2, $img->width, $img->height / 2, gdStyled);
    $img->line($img->width / 2, 0, $img->width / 2, $img->height, gdStyled);

    #printf("%i*%i=%ipx image generated in %.3fs\n", $img->width, $img->height, $img->width * $img->height, Time::HiRes::time() - $time_spent) if $DEBUG;

    return $img;
}

1;
