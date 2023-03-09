package Device::Thermometer::MLX90614;
use parent Device::SMBus;

use POSIX::RT::Clock;
my $mt = POSIX::RT::Clock->new('monotonic');

use strict;
use warnings;

use constant {
	MLX90614_ADDRESS => 0x5a,
	MLX90614_AMBIENT => 0x06,
    MLX90614_OBJECT => 0x07,
};

sub new {
    my ($self) = @_;
    return $self->SUPER::new(
        I2CBusDevicePath => '/dev/i2c-1',
        I2CDeviceAddress => MLX90614_ADDRESS,
    );
}


sub get_ambient_temperature {
    my ($self) = @_;

    my $temp = $self->readWordData(MLX90614_AMBIENT);
    #$temp *= 0.02;
    return $temp;

}

sub get_temperature {
    my ($self) = @_;

    my $temp = $self->readWordData(MLX90614_OBJECT);
    $temp = unpack('s' => pack('S' => $temp));
    #$temp *= 0.02;
    return $temp;
}

1;
