package Device::Hygrometer::BME280;
use parent Device::SMBus;

use Time::HiRes qw//;

use strict;
use warnings;

use constant {
	BMP280_CONTROL => 0xf4,
	BMP280_READTEMPCMD => 0x2e,
    BMP280_READPRESSURECMD => 0x34,
	BMP280_TEMPDATA => 0xf6,
    OSS => 3,
};

sub new {
    my ($self) = @_;

    $self = $self->SUPER::new(
        I2CBusDevicePath => '/dev/i2c-1',
        I2CDeviceAddress => 0x76,
    );
    # check id
    my $id = $self->readByteData(0xd0);
    die sprintf("%x", $id) unless 0x60 == $id;
    # reset
    $self->writeByteData(0xe0, 0xb6);
    sleep 1;
    $self->writeByteData(0xf2, 5);
    $self->writeByteData(0xf4, (5 << 5) | (5 << 2) | 3);
    #$self->writeByteData(0xf5, 5);
    #sleep 1;
    return $self;
}

my $calibration;

sub get_calibration {
    my ($self) = @_;

    return $calibration if $calibration;
    my $result;
    @{$result}{qw/t1l t1h t2l t2h t3l t3h p1l p1h p2l p2h p3l p3h p4l p4h p5l p5h p6l p6h p7l p7h p8l p8h p9l p9h h1/} = $self->readBlockData(0x88, 25);
    $result->{t1} = unpack(S => pack('CC', @{$result}{qw/t1l t1h/}));
    $result->{t2} = unpack(s => pack('CC', @{$result}{qw/t2l t2h/}));
    $result->{t3} = unpack(s => pack('CC', @{$result}{qw/t3l t3h/}));
    $result->{p1} = unpack(S => pack('CC', @{$result}{qw/p1l p1h/}));
    $result->{p2} = unpack(s => pack('CC', @{$result}{qw/p2l p2h/}));
    $result->{p3} = unpack(s => pack('CC', @{$result}{qw/p3l p3h/}));
    $result->{p4} = unpack(s => pack('CC', @{$result}{qw/p4l p4h/}));
    $result->{p5} = unpack(s => pack('CC', @{$result}{qw/p5l p5h/}));
    $result->{p6} = unpack(s => pack('CC', @{$result}{qw/p6l p6h/}));
    $result->{p7} = unpack(s => pack('CC', @{$result}{qw/p7l p7h/}));
    $result->{p8} = unpack(s => pack('CC', @{$result}{qw/p8l p8h/}));
    $result->{p9} = unpack(s => pack('CC', @{$result}{qw/p9l p9h/}));
    delete @{$result}{qw/t1l t1h t2l t2h t3l t3h p1l p1h p2l p2h p3l p3h p4l p4h p5l p5h p6l p6h p7l p7h p8l p8h p9l p9h/};
    @{$result}{qw/h1/} = $self->readBlockData(0xa1, 1);
    @{$result}{qw/e1 e2 e3 e4 e5 e6 e7/} = $self->readBlockData(0xe1, 7);
    $result->{h2} = unpack(s => pack('CC', @{$result}{qw/e1 e2/}));
    $result->{h3} = $result->{e3};
    #$result->{h4} = $result->{e4} * 16 + $result->{e5} & 15;
    $result->{h4} = unpack(s => pack(S => $result->{e4} << 4 | $result->{e5} & 15));;
    #$result->{h5} = $result->{e6} * 16 + $result->{e5} >> 4;
    $result->{h5} = unpack(s => pack('S', $result->{e6} << 4 | $result->{e5}));
    $result->{h6} = unpack(c => pack('C', @{$result}{qw/e7/}));
    delete @{$result}{qw/e1 e2 e3 e4 e5 e6 e7/};
    $calibration = $result;
    return $result;
}

sub get_data {
    my ($self) = @_;

    my $cal = $self->get_calibration;
    my $result;
    @{$result}{qw/f7 f8 f9 fa fb fc fd fe/} = $self->readBlockData(0xf7, 8);
    $result->{p_raw} = $result->{f7} << 12 | $result->{f8} << 4 | $result->{f9} >> 4;
    $result->{h_raw} = $result->{fd} << 8 | $result->{fe};
    $result->{t_raw} = $result->{fa} << 12 | $result->{fb} << 4 | $result->{fc} >> 4;
    delete @{$result}{qw/f7 f8 f9 fa fb fc fd fe/};
    $result->{tvar1} = ($result->{t_raw} / 16384 - $cal->{t1} / 1024) * $cal->{t2};
    $result->{tvar2} = ($result->{t_raw} / 131072 - $cal->{t1} / 8192) * ($result->{t_raw} / 131072 - $cal->{t1} / 8192) * $cal->{t3};
    $result->{t_fine} = $result->{tvar1} + $result->{tvar2};
    $result->{t} = $result->{t_fine} / 5120;
    $result->{var1} = $result->{t_fine} / 2 - 64000;
    $result->{var2} = $result->{var1} * $result->{var1} * $cal->{p6} / 32768;
    $result->{var2} = $result->{var2} + $result->{var1} * $cal->{p5} * 2;
    $result->{var2} = $result->{var2}/4 + $cal->{p4} * 65536;
    $result->{var1} = ($cal->{p3} * $result->{var1} * $result->{var1} / 524288 + $cal->{p2} * $result->{var1}) / 524288;
    $result->{var1} = (1.0 + $result->{var1} / 32768.0) * $cal->{p1};
    $result->{p} = 1048576 - $result->{p_raw};
    $result->{p} = ($result->{p} - $result->{var2} / 4096) * 6250 / $result->{var1};
    $result->{var1} = $cal->{p9} * $result->{p} * $result->{p} / 2147483648;
    $result->{var2} = $result->{p} * $cal->{p8} / 32768;
    $result->{p} = $result->{p} + ($result->{var1} + $result->{var2} + $cal->{p7}) / 16;
    $result->{h} = $result->{t_fine} - 76800;
    $result->{h} = ($result->{h_raw} - ($cal->{h4} * 64 + $cal->{h5} / 16384 * $result->{h})) * 
        ($cal->{h2} / 65536 * (1 + $cal->{h6} / 67108864 * $result->{h} * (1 + $cal->{h3} / 67108864 * $result->{h})));
    $result->{h} = $result->{h} * (1 - $cal->{h1} * $result->{h} / 524288);
    delete @{$result}{qw/tvar1 tvar2 t_fine var1 var2/};
    delete @{$result}{qw/h_raw p_raw t_raw/};
    @{$result}{qw/humidity pressure temperature/} = delete(@{$result}{qw/h p t/});
    return $result;
}

sub get_pressure {
    my ($self) = @_;

    return $self->get_data->{p};
}

sub get_temp_raw {
    my ($self) = @_;

    #$self->writeByteData(BMP280_CONTROL, BMP280_READTEMPCMD);
    #Time::HiRes::sleep(0.0045);
    my $result;
    @{$result}{qw/msb lsb xlsb/} = $self->readBlockData(0xfa, 3);
    #$result->{t} = unpack(s => pack('CC', @{$result}{qw/lsb msb/}));
    $result->{t_raw} = $result->{msb} << 12 | $result->{lsb} << 4 | $result->{xlsb} >> 4;
    delete @{$result}{qw/msb lsb xlsb/};
    return $result;
}

sub get_temp {
    my ($self) = @_;

    return $self->get_data->{t};
}

1;
