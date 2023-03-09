package Device::Accelerometer::MPU9250;
use parent Device::SMBus;
use Device::Magnetometer::AK8963;

use Math::Trig qw//;
use Time::HiRes qw//;

use strict;
use warnings;

use constant {
    ADDRESS => 0x68,
    BUS => '/dev/i2c-1',
    PWR_MGMT_1 => 0x6B,
};

my $ak8963;

sub ak8963 {
    my ($self) = @_;

    unless ($ak8963) {
        $self->writeByteData(55, 2); # BYPASS_EN
        $ak8963 = Device::Magnetometer::AK8963->new();
    }
    return $ak8963;
}

sub new {
    my ($self) = @_;

    $self = $self->SUPER::new(
        I2CBusDevicePath => BUS(),
        I2CDeviceAddress => ADDRESS(),
    );
    my $reg;
    #$reg = $self->readByteData(0x19); # MPU6050_RA_SMPLRT_DIV
    #warn $reg;
    #$reg = $self->readByteData(0x1A); # MPU6050_RA_CONFIG
    #warn $reg;
    #$reg = $self->readByteData(0x1B); # MPU6050_RA_GYRO_CONFIG
    #warn $reg;
    #$reg = $self->readByteData(0x1C); # MPU6050_RA_ACCEL_CONFIG
    #warn $reg;
    #$reg = $self->readByteData(0x6A); # MPU6050_RA_USER_CTRL
    #warn $reg;
    #$reg = $self->readByteData(0x6B); # MPU6050_RA_PWR_MGMT_1
    #warn $reg;
    #$reg = $self->readByteData(0x6C); # MPU6050_RA_PWR_MGMT_2
    #warn $reg;
    #$reg = $self->readByteData(0x71); # WHO_AM_I
    #warn $reg;
    my $id = $self->readByteData(117); # WHO_AM_I
    die $id unless 113 == $id || 115 == $id;

    #$self->writeByteData(25, 0); # SMPLRT_DIV
    $self->writeByteData(26, 0); # 185Hz Gyro
    $self->writeByteData(29, 1); # 184Hz accel
    $self->writeByteData(107, 1); # MPU6050_RA_PWR_MGMT_1
    #$self->writeByteData(0x37, 1 << 1); # MPU6050_RA_INT_PIN_CFG

    #$self->writeByte(PWR_MGMT_1, 0x01);
    #$self->writeByte(PWR_MGMT_1, 1);
    #Time::HiRes::sleep(0.1);
    #$self->writeByte(PWR_MGMT_1, 0);
    #$self->writeByte(, CLOCK_PLL_XGYRO);
    #$self->writeByte(, MPU6050_GYRO_FS_250);
    #$self->writeByte(, MPU6050_ACCEL_FS_2);
    #$self->writeByte(0x1a, 0x6);
    return $self;
}

sub get_raw_data {
    my ($self) = @_;

    my $result;
    @{$result}{qw/a_x_msb a_x_lsb a_y_msb a_y_lsb a_z_msb a_z_lsb t_msb t_lsb g_x_msb g_x_lsb g_y_msb g_y_lsb g_z_msb g_z_lsb/} =
        $self->readBlockData(59, 14);
    #$result->{t} = (delete($result->{t_msb}) << 8) + delete($result->{t_lsb});
    $result->{t} = unpack(s => pack('CC', $result->{t_lsb}, $result->{t_msb}));
    #$result->{a_x} = unpack(S => pack('WW', delete($result->{a_x_msb}), delete($result->{a_x_lsb})));
    #$result->{a_x} = (delete($result->{a_x_msb}) << 8) | delete($result->{a_x_lsb});
    #$result->{a_x} = ($result->{a_x_msb} << 8) | $result->{a_x_lsb};
    #$result->{a_x} = unpack(s => pack(S => (delete($result->{a_x_msb}) << 8) | delete($result->{a_x_lsb})));
    $result->{a_x} = unpack(s => pack('CC', $result->{a_x_lsb}, $result->{a_x_msb}));
    #$result->{a_y} = unpack(s => pack(S => ($result->{a_y_msb} << 8) | $result->{a_y_lsb}));
    $result->{a_y} = unpack(s => pack('CC', $result->{a_y_lsb}, $result->{a_y_msb}));
    $result->{a_z} = unpack(s => pack('CC', $result->{a_z_lsb}, $result->{a_z_msb}));
    $result->{g_x} = unpack(s => pack('CC', $result->{g_x_lsb}, $result->{g_x_msb}));
    $result->{g_y} = unpack(s => pack('CC', $result->{g_y_lsb}, $result->{g_y_msb}));
    $result->{g_z} = unpack(s => pack('CC', $result->{g_z_lsb}, $result->{g_z_msb}));
    #$result->{a_y} = (delete($result->{a_y_msb}) << 8) + delete($result->{a_y_lsb});
    #$result->{a_y} = unpack(s => pack(S => $result->{a_y}));
    #$result->{a_z} = (delete($result->{a_z_msb}) << 8) + delete($result->{a_z_lsb});
    #$result->{a_z} = unpack(s => pack(S => $result->{a_z}));
    #$result->{g_x} = (delete($result->{g_x_msb}) << 8) + delete($result->{g_x_lsb});
    #$result->{g_x} = unpack(s => pack(S => $result->{g_x}));
    #$result->{g_y} = (delete($result->{g_y_msb}) << 8) + delete($result->{g_y_lsb});
    #$result->{g_y} = unpack(s => pack(S => $result->{g_y}));
    #$result->{g_z} = (delete($result->{g_z_msb}) << 8) + delete($result->{g_z_lsb});
    #$result->{g_z} = unpack(s => pack(S => $result->{g_z}));
    delete @{$result}{qw/a_x_msb a_x_lsb a_y_msb a_y_lsb a_z_msb a_z_lsb t_msb t_lsb g_x_msb g_x_lsb g_y_msb g_y_lsb g_z_msb g_z_lsb/};
    return $result;
}

sub get_data {
    my ($self) = @_;

    my $result = $self->get_raw_data;
    # m/s
    $result->{a_x} = $result->{a_x} * 9.807 / 16384;
    $result->{a_y} = $result->{a_y} * 9.807 / 16384;
    $result->{a_z} = $result->{a_z} * 9.807 / 16384;
    #$result->{a_y} /= 16384;
    #$result->{a_z} /= 16384;
    #$result->{g_x} /= 16384;
    #$result->{g_y} /= 16384;
    #$result->{g_z} /= 16384;
    # rad/s
    $result->{g_x} = Math::Trig::deg2rad($result->{g_x} / 131);
    $result->{g_y} = Math::Trig::deg2rad($result->{g_y} / 131);
    $result->{g_z} = Math::Trig::deg2rad($result->{g_z} / 131);
    $result->{t} = $result->{t} / 333.87 + 21;
    return $result;
}

1;
