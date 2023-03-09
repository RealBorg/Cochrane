package Device::Magnetometer::AK8963;;
use parent Device::SMBus;

use Time::HiRes;

use strict;
use warnings;

use constant {
    ADDRESS => 0x0c,
    BUS => '/dev/i2c-1',
};

my $asa;

sub new {
    my ($self) = @_;

    $self = $self->SUPER::new(
        I2CBusDevicePath => BUS(),
        I2CDeviceAddress => ADDRESS(),
    );
    my $id = $self->readByteData(0, 1);
    die unless 72 == $id;
    $self->writeByteData(10, 0b00011111); # fuse rom access
    @{$asa}{qw/y x z/} = $self->readBlockData(16, 3);
    $self->writeByteData(10, 0b00010000); # fuse rom access
    $self->writeByteData(10, 0b00010110); # continous 16-bit
    return $self;
}


sub get_raw_data {
    my ($self) = @_;

    my $result;
    @{$result}{qw/st1 m_y_lsb m_y_msb m_x_lsb m_x_msb m_z_lsb m_z_msb st2/} = $self->readBlockData(2, 8);
    $result->{m_x} = unpack(s => pack('CC', $result->{m_x_lsb}, $result->{m_x_msb}));
    $result->{m_y} = unpack(s => pack('CC', $result->{m_y_lsb}, $result->{m_y_msb}));
    $result->{m_z} = unpack(s => pack('CC', $result->{m_z_lsb}, $result->{m_z_msb}));
    #$result->{x} = unpack(s => pack(S => $result->{x}));
    #$result->{y} = $result->{y_msb} << 8 | $result->{y_lsb};
    #$result->{y} = unpack(s => pack(S => $result->{y}));
    #$result->{z} = $result->{z_msb} << 8 | $result->{z_lsb};
    #$result->{z} = unpack(s => pack(S => $result->{z}));
    #$result->{x} = unpack(s => pack('CC', $result->{x_lsb}, $result->{x_msb}));
    #$result->{y} = unpack(s => pack('CC', $result->{y_lsb}, $result->{y_msb}));
    #$result->{z} = unpack(s => pack('CC', $result->{z_lsb}, $result->{z_msb}));
    #$result->{x} = delete($result->{x_msb}) << 8 | delete($result->{x_lsb});
    #$result->{x1} = ($result->{x_msb} << 8) + $result->{x_lsb};
    #$result->{x} = unpack(s => pack('CC', delete($result->{x_msb}), delete($result->{x_lsb})));
    #$result->{y} = unpack(s => pack('CC', delete($result->{y_msb}), delete($result->{y_lsb})));
    #$result->{z} = unpack(s => pack('CC', delete($result->{z_msb}), delete($result->{z_lsb})));
    #$result->{y} = delete($result->{y_msb}) << 8 | delete($result->{y_lsb});
    #$result->{y} = unpack(s => pack(S => $result->{y}));
    #$result->{z} = delete($result->{z_msb}) << 8 | delete($result->{z_lsb});
    #$result->{z} = unpack(s => pack(S => $result->{z}));
    delete @{$result}{qw/st1 m_x_lsb m_x_msb m_y_lsb m_y_msb m_z_lsb m_z_msb st2/};
    return $result;
}

sub get_data {
    my ($self) = @_;

    my $result = $self->get_raw_data;
    $result->{m_x} = $result->{m_x} * (($asa->{x} - 128) * 0.5 / 128 + 1);
    $result->{m_y} = $result->{m_y} * (($asa->{y} - 128) * 0.5 / 128 + 1);
    $result->{m_z} = $result->{m_z} * (($asa->{z} - 128) * 0.5 / 128 + 1);
    return $result;
}
1;
