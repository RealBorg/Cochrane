package Cochrane::Store::MagField;

use POSIX qw//;
use Time::HiRes qw//;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    PREFIX => 'magfield',
};

sub stringify {
    my ($self) = @_;

    return sprintf(
        "%s %u %.0f/%.0f/%.0f",
        POSIX::strftime('%Y-%m-%dT%H:%M:%S', POSIX::localtime($self->{time})),
        $self->{count},
        $self->{x},
        $self->{y},
        $self->{z},
    );
}

1;
