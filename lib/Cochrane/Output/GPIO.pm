package Cochrane::Output::GPIO;

use IO::File;

use strict;
use warnings;

use constant {
    PMW_FREQUENCY => 100,
};

sub blink {
    my ($self) = @_;
    my $cmd = sprintf("w %i 1 mils 50 w %i 0", $self->{gpio}, $self->{gpio});
    $self->pigpio($cmd);
}

sub new {
    my ($self, $gpio) = @_;
    return bless({
            gpio => $gpio,
    });
}

sub pigpio {
    my ($self, $cmd) = @_;

    if (my $fh = IO::File->new('/dev/pigpio', O_WRONLY)) {
        $fh->print("$cmd\n");
    }
}

sub pwm {
    my ($self, $value) = @_;

    my $cmd = sprintf(
        "pfs %i %i prs %i %i pwm %i %i", 
        $self->{gpio}, 
        100, 
        $self->{gpio}, 
        1024,
        $self->{gpio}, 
        $value,
    );
    $self->pigpio($cmd);
}

sub write {
    my ($self, $value) = @_;
    my $cmd = sprintf(
        "w %i %i",
        $self->{gpio},
        $value,
    );
    $self->pigpio($cmd);
}
1;
