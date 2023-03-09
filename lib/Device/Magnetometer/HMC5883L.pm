package Device::Magnetometer::HMC5883L;;
use parent Device::SMBus;

use Time::HiRes;

use strict;
use warnings;

use constant {
    ADDRESS => 0x1e,
    BUS => '/dev/i2c-1',
    R_CFG_A => 0x00,
    R_CFG_B => 0x01,
    R_MODE => 0x02,
    R_X_MSB => 0x03,
    R_X_LSB => 0x04,
    R_Z_MSB => 0x05,
    R_Z_LSB => 0x06,
    R_Y_MSB => 0x07,
    R_Y_LSB => 0x08,
    R_STATUS => 0x09,
};

sub new {
    my ($self) = @_;

    $self = $self->SUPER::new(
        I2CBusDevicePath => BUS(),
        I2CDeviceAddress => ADDRESS(),
    );
    $self->writeByteData(R_CFG_A, 0x70); # 8-average, 15 Hz default, normal measurement
    #$self->writeByteData(R_CFG_B, 0x20); # gain=5
    $self->writeByteData(R_CFG_B, 1 << 5); # gain=5
    $self->writeByteData(R_MODE, 0x0); # continuous mode

    return $self;
}

sub calibrate {
    my ($self) = @_;

    $self->writeByteData(R_CFG_A, 0x72); # 8-average, 15 Hz default, positive bias
    Time::HiRes::sleep(0.066);
    my $data = $self->get_raw_data;
    $self->writeByteData(R_CFG_A, 0x70); # 8-average, 15 Hz default, normal measurement
    return $data;
}

sub get_raw_data {
    my ($self) = @_;

    my $result;
    @{$result}{qw/x_msb x_lsb z_msb z_lsb y_msb y_lsb/} = $self->readBlockData(R_X_MSB, 6);
    $result->{x} = (delete($result->{x_msb}) << 8) + delete($result->{x_lsb});
    $result->{x} = unpack(s => pack(S => $result->{x}));
    $result->{y} = (delete($result->{y_msb}) << 8) + delete($result->{y_lsb});
    $result->{y} = unpack(s => pack(S => $result->{y}));
    $result->{z} = (delete($result->{z_msb}) << 8) + delete($result->{z_lsb});
    $result->{z} = unpack(s => pack(S => $result->{z}));
    return $result;
}

1;
