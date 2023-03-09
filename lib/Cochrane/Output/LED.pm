package Cochrane::Output::LED;

use strict;
use warnings;

use IO::File;

sub new {
    my ($class, $led) = @_;

    die unless $led;
    my $self = {
        led => $led,
    };
    $class->sysfs("$led/trigger", "oneshot\n");
    $class->sysfs("$led/delay_on", "100\n");
    $class->sysfs("$led/delay_off", "100\n");
    return bless($self, $class);
}

sub sysfs {
    my ($self, $file, $value) = @_;

    if (my $fh = IO::File->new("/sys/class/leds/$file", O_WRONLY)) {
        $fh->write($value);
        $fh->close();
    }
}

sub shot {
    my ($self) = @_;

    $self->sysfs("$self->{led}/shot", "1\n");
}

1;
