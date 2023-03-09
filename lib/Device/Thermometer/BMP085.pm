package Device::Thermometer::BMP085;
use parent Device::SMBus;

use Time::HiRes qw//;

use strict;
use warnings;

use constant {
	BMP085_CONTROL => 0xf4,
	BMP085_READTEMPCMD => 0x2e,
    BMP085_READPRESSURECMD => 0x34,
	BMP085_TEMPDATA => 0xf6,
    OSS => 3,
};

sub new {
    my ($self) = @_;
    return $self->SUPER::new(
        I2CBusDevicePath => '/dev/i2c-1',
        I2CDeviceAddress => 0x77,
    );
}

sub get_pressure_raw {
    my ($self) = @_;

    $self->writeByteData(BMP085_CONTROL, BMP085_READPRESSURECMD + (OSS << 6) );
    Time::HiRes::sleep(0.003 * 2**OSS + 0.0015);
    my ($msb, $lsb, $xlsb) = $self->readBlockData(0xf6, 3);
    my $pressure = (( $msb << 16 ) + ( $lsb << 8 ) + $xlsb) >> (8 - OSS);
    return $pressure;
}

sub get_pressure {
    my ($self) = @_;

    return $self->get_data->{pressure};
}

sub get_data {
    my ($self) = @_;

    my $result;
    my $ut = $self->get_temp_raw;
    $result->{temperature_raw} = $ut;
    my $up = $self->get_pressure_raw;
    $result->{pressure_raw} = $up;
    my $cal = $self->get_calibration;

    my $x1 = ($ut - $cal->{ac6}) * ($cal->{ac5} / 2**15);
    my $x2 = ($cal->{mc} * 2**11) / ($x1 + $cal->{md});
    my $b5 = $x1 + $x2;
    my $t = ($b5 + 8 ) / 2**4;
    $result->{temperature} = $t / 10;
    my $b6 = $b5 - 4000;
    $x1 = ($cal->{b2} * ($b6 * ($b6 / 2**12))) / 2**11;
    $x2 = $cal->{ac2} * $b6 / 2**11;
    my $x3 = $x1 + $x2;
    my $b3 = ((($cal->{ac1} * 4 + $x3) << OSS) + 2) / 4;
    $x1 = $cal->{ac3} * $b6 / 2**13;
    $x2 = ( $cal->{b1} * ( $b6 * $b6 / 2**12 ) ) / 2**16;
    $x3 = (( $x1 + $x2 ) + 2 ) / 2**2;
    my $b4 = $cal->{ac4} * ($x3 + 32768) / 2**15;
    my $b7 = ($up - $b3) * (50000 >> OSS);
    my $p = $b7 < 0x80000000 ? $b7 * 2 / $b4 : $b7 / $b4 * 2;
    $x1 = ( $p / 2**8 ) * ( $p / 2**8 );
    $x1 = ($x1 * 3038) / 2**16;
    $x2 = (-7357 * $p ) / 2**16;
    $p = $p + ( $x1 + $x2 + 3791) / 2**4;
    $result->{pressure} = $p;
    return $result;
}

sub get_temp_raw {
    my ($self) = @_;
    $self->writeByteData(BMP085_CONTROL, BMP085_READTEMPCMD);
    Time::HiRes::sleep(0.0045);
    my $msb = $self->readByteData(0xf6);
    my $lsb = $self->readByteData(0xf7);
    my $temp = ($msb << 8 ) | $lsb;
    $temp = unpack('s' => pack('S' => $temp));
    return $temp;
}

sub get_temp {
    my ($self) = @_;

    my $ut = $self->get_temp_raw;
    my $cal = $self->get_calibration;
    my $x1 = ($ut - $cal->{ac6}) * ($cal->{ac5} / 2**15);
    my $x2 = ($cal->{mc} * 2**11) / ($x1 + $cal->{md});
    my $b5 = $x1 + $x2;
    my $t = ($b5 + 8 ) / 2**4;
    return $t;
}

sub get_calibration {
    my ($self) = @_;

    my $cal = $self->{calibration};
    unless ($cal) {
        @{$cal}{qw/ac1m ac1l ac2m ac2l ac3m ac3l ac4m ac4l ac5m ac5l ac6m ac6l b1m b1l b2m b2l mbm mbl mcm mcl mdm mdl/} = 
            $self->readBlockData(0xAA, 22);
            #$cal->{ac1} = unpack(s => pack('CC', delete @{$cal}{qw/ac1m ac1l/}));
        $cal->{ac1} = ( delete($cal->{ac1m}) << 8 ) | delete($cal->{ac1l});
        $cal->{ac1} = unpack(s => pack(S => $cal->{ac1} ));
        $cal->{ac2} = ( delete($cal->{ac2m}) << 8 ) | delete($cal->{ac2l});
        $cal->{ac2} = unpack(s => pack(S => $cal->{ac2} ));
        $cal->{ac3} = ( delete($cal->{ac3m}) << 8 ) | delete($cal->{ac3l});
        $cal->{ac3} = unpack(s => pack(S => $cal->{ac3} ));
        $cal->{ac4} = ( delete($cal->{ac4m}) << 8 ) | delete($cal->{ac4l});
        $cal->{ac5} = ( delete($cal->{ac5m}) << 8 ) | delete($cal->{ac5l});
        $cal->{ac6} = ( delete($cal->{ac6m}) << 8 ) | delete($cal->{ac6l});
        $cal->{b1} = ( delete($cal->{b1m}) << 8 ) | delete($cal->{b1l});
        $cal->{b1} = unpack(s => pack(S => $cal->{b1} ));
        $cal->{b2} = ( delete($cal->{b2m}) << 8 ) | delete($cal->{b2l});
        $cal->{b2} = unpack(s => pack(S => $cal->{b2} ));
        $cal->{mb} = ( delete($cal->{mbm}) << 8 ) | delete($cal->{mbl});
        $cal->{mb} = unpack(s => pack(S => $cal->{mb} ));
        $cal->{mc} = ( delete($cal->{mcm}) << 8 ) | delete($cal->{mcl});
        $cal->{mc} = unpack(s => pack(S => $cal->{mc} ));
        $cal->{md} = ( delete($cal->{mdm}) << 8 ) | delete($cal->{mdl});
        $cal->{md} = unpack(s => pack(S => $cal->{md} ));
        $self->{calibration} = $cal;
    }
    return $cal;
}

1;
