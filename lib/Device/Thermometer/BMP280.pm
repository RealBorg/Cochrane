package Device::Thermometer::BMP280;
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
    die $id unless 88 == $id;
    # reset
    $self->writeByteData(0xe0, 0xb6);
    sleep 1;
    $self->writeByteData(0xf4, (3 << 5) | (3 << 2) | 3);
    #$self->writeByteData(0xf5, 5);
    #sleep 1;
    return $self;
}

my $calibration;

sub get_calibration {
    my ($self) = @_;

    return $calibration if $calibration;
    my $result;
    @{$result}{qw/t1l t1h t2l t2h t3l t3h p1l p1h p2l p2h p3l p3h p4l p4h p5l p5h p6l p6h p7l p7h p8l p8h p9l p9h/} = $self->readBlockData(0x88, 24);
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
    $calibration = $result;
    return $result;
}

sub get_pressure_raw {
    my ($self) = @_;

    my $result;
    @{$result}{qw/msb lsb xlsb/} = $self->readBlockData(0xf7, 3);
    $result->{p_raw} = $result->{msb} << 12 | $result->{lsb} << 4 | $result->{xlsb} >> 4;
    delete @{$result}{qw/msb lsb xlsb/};
    return $result;
}

sub get_data {
    my ($self) = @_;

    my $cal = $self->get_calibration;
    my $result = {
        %{$self->get_temp_raw},
        %{$self->get_pressure_raw},
    };
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
    delete @{$result}{qw/tvar1 tvar2 t_fine var1 var2/};
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
