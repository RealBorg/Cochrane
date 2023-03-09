package Device::Hygrometer::SI7021;
use parent Device::SMBus;

use Time::HiRes qw//;

use strict;
use warnings;

sub new {
    my ($class) = @_;

    my $self = $class->SUPER::new(
        I2CBusDevicePath => '/dev/i2c-1',
        I2CDeviceAddress => 0x40,
    );
    $self->writeByte(0xFE);
    return $self;
}

sub get_data {
    my ($self) = @_;

    my $result = {
        humidity => $self->get_humidity(),
        temperature => $self->get_temperature(),
    };
    return $result;
}

sub get_humidity {
    my ($self) = @_;

    my $humidity = $self->get_humidity_raw;
    $humidity = 125 * $humidity / 65536 - 6;
    return $humidity;
}

sub get_humidity_raw {
    my ($self) = @_;

    $self->writeByte(0xF5);
    Time::HiRes::sleep(0.02);
    my $msb = $self->readByte();
    my $humidity = $msb * 256;
    return $humidity;
}

sub get_temperature {
    my ($self) = @_;

    my $temperature = $self->get_temperature_raw;
    $temperature = 175.72 * $temperature / 65536 - 46.85;
    return $temperature;
}

sub get_temperature_raw {
    my ($self) = @_;

    $self->writeByte(0xF3);
    Time::HiRes::sleep(0.02);
    my $msb = $self->readByte();
    my $temperature = $msb * 256;
    return $temperature;
}


1;
