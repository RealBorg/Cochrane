package Cochrane::Store::Pressure;

use POSIX qw//;
use Time::HiRes qw//;

use Cochrane::Store::METAR;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    PREFIX => 'pressure_temperature',
};

sub altitude {
    my ($self) = @_;

    unless ($self->{altitude}) {
        my $qnh = 101325;
        if (my $metar = Cochrane::Store::METAR->last) {
            $qnh = $metar->qnh * 100;
        }
        $self->{altitude} = ($qnh - $self->{pressure}) / 12.2;
    }
    return $self->{altitude};
}

sub stringify {
    my ($self) = @_;

    return sprintf(
        "%s %.1f Pa %.2f C",
        POSIX::strftime('%Y-%m-%dT%H:%M:%S', POSIX::localtime($self->{time})),
        $self->{pressure},
        $self->{temperature});
}

1;
