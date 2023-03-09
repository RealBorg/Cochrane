package Cochrane::Store::Position;

use POSIX qw//;
use Time::HiRes qw//;

use Astro::Coord::ECI;
use Astro::Coord::ECI::Utils qw//;

use Geo::ECEF;

use Geo::Ellipsoid;
my $ellipsoid = Geo::Ellipsoid->new(
    ellipsoid => 'WGS84',
    units => 'degrees',
    distance_units => 'meter',
);

use Math::Trig qw//;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    PREFIX => 'position',
    C => 299792458,
    EARTH_GRAVITATION => 3.9860044189e14,
    G => 6.67408e-11,
};

sub new {
    my ($class, $self, $previous) = @_;

    my $ecef = Geo::ECEF->new();
    ($self->{ecef}->{x}, $self->{ecef}->{y}, $self->{ecef}->{z}) = $ecef->ecef($self->{lat}, $self->{lng}, $self->{alt});

    if ($previous) {
        my $dt = $self->{time} - $previous->{time};
        (undef, $self->{hdg}) = $ellipsoid->to($previous->{lat}, $previous->{lng}, $self->{lat}, $self->{lng});
        $self->{ecef}->{dx} = $self->{ecef}->{x} - $previous->{ecef}->{x};
        $self->{ecef}->{dx} /= $dt;
        $self->{ecef}->{dy} = $self->{ecef}->{y} - $previous->{ecef}->{y};
        $self->{ecef}->{dy} /= $dt;
        $self->{ecef}->{dz} = $self->{ecef}->{z} - $previous->{ecef}->{z};
        $self->{ecef}->{dz} /= $dt;
        $self->{ecef}->{v} = sqrt($self->{ecef}->{dx}**2 + $self->{ecef}->{dy}**2 + $self->{ecef}->{dz}**2);
        $self->{spd} = $self->{ecef}->{v};
        $self->{vspd} = $self->{alt} - $previous->{alt};
        $self->{vspd} /= $dt;
        $self->{hspd} = $self->{spd} - abs($self->{vspd});
    }
    $class->SUPER::new($self);
}

sub stringify {
    my ($self) = @_;

    my $result = '';
    if ($self->valid) {
        $result = sprintf(
            "%.4f%s %.4f%s %.0fm %.0fm/s %.0fkm/h %.0f°",
            $self->{lat},
            ($self->{lat} >= 0 ? 'N' : 'S'),
            $self->{lng},
            ($self->{lng} >= 0 ? 'E' : 'W'),
            $self->{alt},
            ($self->{spd} || 0),
            ($self->{spd} || 0) * 3.6,
            ($self->{hdg} || 0),
        );
    }
    return $result;
}

sub stringify_ecef {
    my ($self) = @_;

    my $result = '';
    if (my $ecef = $self->{ecef}) {
        $result = sprintf(
            "ECEF:  %.0fm/s %.0fkm/h\nX: %4.3f %+.0fm/s\nY: %4.3f %+.0fm/s\nZ: %4.3f %+.0fm/s", 
            $ecef->{v},
            $ecef->{v} * 3.6,
            $ecef->{x} / 1000, 
            $ecef->{dx},
            $ecef->{y} / 1000,
            $ecef->{dy},
            $ecef->{z} / 1000,
            $ecef->{dz},
        );
    }
    return $result;
}

sub stringify_eci {
    my ($self) = @_;

    my $result = '';
    if (my $eci = $self->{eci}) {
        $result = sprintf(
            "ECI:  %.0fm/s %.0fkm/h\nX: %4.3f %+.0fm/s\nY: %4.3f %+.0fm/s\nZ: %4.3f %+.0fm/s", 
            $eci->{v},
            $eci->{v} * 3.6,
            $eci->{x} / 1000, 
            $eci->{dx},
            $eci->{y} / 1000,
            $eci->{dy},
            $eci->{z} / 1000,
            $eci->{dz},
        );
    }
    return $result;
}

sub stringify_g {
    my ($self) = @_;

    my $result = '';
    if (my $g = $self->g) {
        $result = sprintf(
            "g = %.6f - %.6f = %.6f", 
            $g->{g},
            $g->{f},
            $g->{g} - $g->{f},
        );
    }
    return $result;
}

sub stringify_sun {
    my ($self) = @_;

    my $result = '';
    if (my $sun = $self->sun) {
        $result = sprintf(
            "Sun: %.0f° %.0f° %.0fkm %s %s %s", 
            Astro::Coord::ECI::Utils::rad2deg($sun->{az}), 
            Astro::Coord::ECI::Utils::rad2deg($sun->{el}),
            $sun->{ra} / 1000,
            POSIX::strftime("%Hh%M", localtime($sun->{rise})),
            POSIX::strftime("%Hh%M", localtime($sun->{noon})),
            POSIX::strftime("%Hh%M", localtime($sun->{set})),
        );
    }
    return $result;
}

sub stringify_moon {
    my ($self) = @_;
    
    my $result = '';
    if (my $moon = $self->moon) {
        $result = sprintf(
            "Moon: %.0f° %.0f° %.0fkm %s %s %s", 
            Math::Trig::rad2deg($moon->{az}), 
            Math::Trig::rad2deg($moon->{el}),
            $moon->{ra} / 1000,
            POSIX::strftime("%Hh%M", localtime($moon->{rise})),
            POSIX::strftime("%Hh%M", localtime($moon->{noon})),
            POSIX::strftime("%Hh%M", localtime($moon->{set})),
        );
    }
    return $result;
}

sub valid {
    my ($self) = @_;
    
    my $result = 0;
    if (defined($self->{lat}) && defined($self->{lng}) && defined($self->{alt})) {
        $result = 1;
    }
    return $result;
}

sub g {
    my ($self) = @_;

    my $result = $self->{g};
    if (!$result && $self->{eci}) {
        #my $o = 2 * Math::Trig::pi() / (23 * 60 * 60 + 56 * 60 + 4.1);
        #my $dst_axis = sqrt($ecef->{x}**2 + $ecef->{y}**2);
        #my $f = $o**2 * $dst_axis * cos(Math::Trig::deg2rad($position->{lat}));
        my $eci = $self->{eci};
        my $dst_center = sqrt($eci->{x}**2 + $eci->{y}**2 + $eci->{z}**2);
        $result->{g} = EARTH_GRAVITATION() / $dst_center**2;
        $result->{f} = $eci->{v}**2 / $dst_center;
        $self->{g} = $result;
    }
    return $result;
}

sub moon {
    my ($self) = @_;

    my $result = $self->{moon};
    if (!$result && (my $ecef = $self->{ecef})) {
        eval {
            use Astro::Coord::ECI::Moon;

            my $eci = Astro::Coord::ECI->ecef(
                $ecef->{x} / 1000,
                $ecef->{y} / 1000,
                $ecef->{z} / 1000,
                $ecef->{dx} / 1000,
                $ecef->{dy} / 1000,
                $ecef->{dz} / 1000,
            );

            my $moon = Astro::Coord::ECI::Moon->universal($self->{time});
            ($result->{az}, $result->{el}, $result->{ra}) = $eci->azel($moon);
            $result->{ra} *= 1000;

            my ($t, $r) = $eci->next_elevation($moon, 0, 0);
            $result->{$r ? 'rise' : 'set'} = $t;
            ($t, $r) = $eci->next_elevation($moon, 0, 0);
            $result->{$r ? 'rise' : 'set'} = $t;
            ($result->{noon}) = $eci->next_meridian($moon, 1);
            $self->{moon} = $result;
        };
        warn $@ if $@;
    }
    return $result;
}

sub sun {
    my ($self) = @_;


    my $result = $self->{sun};
    if (!$result && (my $ecef = $self->{ecef})) {
        eval {
            use Astro::Coord::ECI::Sun;

            my $eci = Astro::Coord::ECI->ecef(
                $ecef->{x} / 1000,
                $ecef->{y} / 1000,
                $ecef->{z} / 1000,
                ($ecef->{dx} || 0) / 1000,
                ($ecef->{dy} || 0) / 1000,
                ($ecef->{dz} || 0) / 1000,
            );

            #$eci->universal($self->{time});

            my $sun = Astro::Coord::ECI::Sun->universal(time());

            ($result->{az}, $result->{el}, $result->{ra}) = $eci->azel($sun);
            $result->{ra} *= 1000;

            my ($t, $r) = $eci->next_elevation($sun, 0, 0);
            $result->{$r ? 'rise' : 'set'} = $t;
            ($t, $r) = $eci->next_elevation($sun, 0, 0);
            $result->{$r ? 'rise' : 'set'} = $t;

            ($result->{noon}) = $eci->next_meridian($sun, 1);
            $result->{day} = abs($result->{set} - $result->{rise});
            $self->{sun} = $result;
        };
        warn $@ if $@;
    }
    return $result;
}

1;
