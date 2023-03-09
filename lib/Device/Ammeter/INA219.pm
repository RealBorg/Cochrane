package Device::Ammeter::INA219;
use parent Device::SMBus;

use Time::HiRes qw//;

use strict;
use warnings;

use constant {
};

sub new {
    my ($self) = @_;

    $self = $self->SUPER::new(
        I2CBusDevicePath => '/dev/i2c-1',
        I2CDeviceAddress => 0x40,
    );
    $self->{config} = [ 0b00111001, 0b10011111 ]; # default, 32V, 320mV, 532us, continuous
    $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    $self->writeBlockData(5, [ 0, 0 ]);
    return $self;
}

sub get_data {
    my ($self) = @_;

    my $result;
    my ($smsb, $slsb) = $self->readBlockData(1, 2);
    my ($vmsb, $vlsb) = $self->readBlockData(2, 2);
    #warn "$smsb $slsb $vmsb $vlsb";
    $result->{shunt} = unpack('s>', pack('CC', $smsb, $slsb));
    $result->{voltage} = $vmsb << 5 | $vlsb >> 3;
    #$result->{shunt} = unpack('s>', pack('S', $msb << 8 | $lsb));
    $result->{shunt} = $result->{shunt} / 100_000;
    #($msb, $lsb) = $self->readBlockData(2, 2);
    #$result->{voltage} = $msb << 5 | $lsb >> 3;
    $result->{voltage} = $result->{voltage} * 4 / 1000;
    $result->{current} = $result->{shunt} * 10;
    $result->{power} = $result->{current} * $result->{voltage};
    #@{$result}{qw/p_m p_l/} = $self->readBlockData(3, 2);
    #$result->{p} = $result->{p_m} << 8 | $result->{p_l};
    #$result->{power} = $result->{p} * 0.002;
    #@{$result}{qw/c_m c_l/} = $self->readBlockData(4, 2);
    #$result->{c} = $result->{c_m} << 8 | $result->{c_l};
    #$result->{current} = $result->{c} / 10_000;
    return $result;
}

sub setBusVoltageRange {
    my ($self, $range) = @_;
    if ($range == 16) {
        $self->{config}->[0] = $self->{config}->[0] & ~0b00100000;
        $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    } elsif ($range == 32) {
        $self->{config}->[0] = $self->{config}->[0] | 0b00100000;
        $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    } else {
        die "Invalid Bus Voltage Range";
    }
}

sub setShuntVoltageRange {
    my ($self, $range) = @_;
    if ($range == 0.040) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00011000);
        $self->writeBlockData(0, $self->{config});
    } elsif ($range == 0.080) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00011000) | 0b00001000;
        $self->writeBlockData(0, $self->{config});
    } elsif ($range == 0.160) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00011000) | 0b00010000;
        $self->writeBlockData(0, $self->{config});
    } elsif ($range == 0.320) {
        $self->{config}->[0] = $self->{config}->[0] | 0b00011000;
        $self->writeBlockData(0, $self->{config});
    } else {
        die "Invalid Bus Voltage Range";
    }
}

sub setSampleCount {
    my ($self, $samples) = @_;
    if ($samples == 1) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00000111) | 0b00000100;
        $self->{config}->[1] = ($self->{config}->[1] & ~0b11111000) | 0b01000000;
        $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    } elsif ($samples == 2) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00000111) | 0b00000100;
        $self->{config}->[1] = ($self->{config}->[1] & ~0b11111000) | 0b11001000;
        $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    } elsif ($samples == 4) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00000111) | 0b00000101;
        $self->{config}->[1] = ($self->{config}->[1] & ~0b11111000) | 0b01010000;
        $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    } elsif ($samples == 8) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00000111) | 0b00000101;
        $self->{config}->[1] = ($self->{config}->[1] & ~0b11111000) | 0b11011000;
        $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    } elsif ($samples == 16) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00000111) | 0b00000110;
        $self->{config}->[1] = ($self->{config}->[1] & ~0b11111000) | 0b01100000;
        $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    } elsif ($samples == 32) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00000111) | 0b00000110;
        $self->{config}->[1] = ($self->{config}->[1] & ~0b11111000) | 0b11101000;
        $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    } elsif ($samples == 64) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00000111) | 0b00000111;
        $self->{config}->[1] = ($self->{config}->[1] & ~0b11111000) | 0b01110000;
        $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    } elsif ($samples == 128) {
        $self->{config}->[0] = ($self->{config}->[0] & ~0b00000111) | 0b00000111;
        $self->{config}->[1] = ($self->{config}->[1] & ~0b11111000) | 0b11111000;
        $self->writeBlockData(0, $self->{config}); # 16V, 320mV, 4.26ms, continuous
    } else {
        die "Invalid sample count";
    }
}

1;
