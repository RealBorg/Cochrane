package Device::ADC::ADS1115;
use parent Device::SMBus;

use Data::Dumper;
use Time::HiRes qw//;

use strict;
use warnings;

use constant {
    ADDRESS => 0x48,
    COMP_DIS => 3,
    BUS => '/dev/i2c-1',
    MUX_A0_A1 => 0 << 12,
    MUX_A0_A3 => 1 << 12,
    MUX_A1_A3 => 2 << 12,
    MUX_A2_A3 => 3 << 12,
    MUX_A0_GND => 4 << 12,
    MUX_A1_GND => 5 << 12,
    MUX_A2_GND => 6 << 12,
    MUX_A3_GND => 7 << 12,
    OS => 1 << 15,
    PGA_6144 => 0 << 9,
    PGA_4096 => 1 << 9,
    PGA_2048 => 2 << 9,
    PGA_1024 => 3 << 9,
    PGA_512 => 4 << 9,
    PGA_256 => 5 << 9,
    SINGLE => 1 << 8,
    SPS_8 => 0 << 5,
    SPS_16 => 1 << 5,
    SPS_32 => 2 << 5,
    SPS_64 => 3 << 5,
    SPS_128 => 4 << 5,
    SPS_250 => 5 << 5,
    SPS_475 => 6 << 5,
    SPS_860 => 7 << 5,
};

sub new {
    my ($self) = @_;

    $self = $self->SUPER::new(
        I2CBusDevicePath => BUS(),
        I2CDeviceAddress => ADDRESS(),
    );
    #my @conf = $self->readNBytes(0x1, 2);
    #warn Dumper(\@conf);
    #my ($msb, $lsb) = $self->readBlockData(0x1, 2);
    #warn "msb=$msb lsb=$lsb";
    #$self->writeByteData(1, 0b01000010, 0b00000011);
    #$self->writeBlockData(1, [0b01011010, 0b10100011]); # OS | A1_GND | PGA256 | SINGLE
    #$self->writeByteData(2, 0b10100011); # DR128 | COMP_DIS
    #($msb, $lsb) = $self->readBlockData(0x1, 2);
    #warn "msb=$msb lsb=$lsb";
    #$self->writeWordData(0x1, 33413);
    #$self->writeWordData(0x1, OS | MUX_A0_GND | PGA_6144 | SINGLE | SPS_16 | COMP_DIS);
    #warn $self->readWordData(0x1);
    #warn $self->readWordData(0x1);
    #$self->writeBlockData(1, [0b01100100, 0b10000011]); # OS | A1_GND | PGA256 | SINGLE
    #$self->writeBlockData(1, [0b01100100, 0b10000011]); # OS | A2_GND | PGA256 | SINGLE
    return $self;
}

sub get_data {
    my ($self) = @_;

    my $result;
    #$self->writeBlockData(1, [0b01000010, 0b10000011]); # OS | A1_GND | PGA256 | SINGLE
    #$self->writeByteData(1, 0b11001011, 0b10000011);
    #Time::HiRes::sleep(1/64);
    my $dr = 128;
    my $sc = $dr;

    $self->writeBlockData(1, [0b01000100, 0b10000011]); # A0_GND | PGA2048 | DR128
    for (my $i = 0; $i < $sc; $i++) {
        Time::HiRes::sleep(1/128);
        my ($msb, $lsb) = $self->readBlockData(0x0, 2);
        my $v = $msb << 8 | $lsb;
        $result->{0} += $v;
    }
    $result->{0} /= $sc;
    $result->{0} *= 2048;
    $result->{0} /= 65535;

    $self->writeBlockData(1, [0b01010100, 0b10000011]); # A1_GND
    for (my $i = 0; $i < $sc; $i++) {
        Time::HiRes::sleep(1/128);
        my ($msb, $lsb) = $self->readBlockData(0x0, 2);
        my $v = $msb << 8 | $lsb;
        $result->{1} += $v;
    }
    $result->{1} /= $sc;
    $result->{1} *= 2048;
    $result->{1} /= 65535;

    $self->writeBlockData(1, [0b01100100, 0b10000011]); # A2_GND
    for (my $i = 0; $i < $sc; $i++) {
        Time::HiRes::sleep(1/128);
        my ($msb, $lsb) = $self->readBlockData(0x0, 2);
        my $v = $msb << 8 | $lsb;
        $result->{2} += $v;
    }
    $result->{2} /= $sc;
    $result->{2} *= 2048;
    $result->{2} /= 65535;

    $self->writeBlockData(1, [0b01110100, 0b10000011]); # A3_GND
    for (my $i = 0; $i < $sc; $i++) {
        Time::HiRes::sleep(1/128);
        my ($msb, $lsb) = $self->readBlockData(0x0, 2);
        my $v = $msb << 8 | $lsb;
        $result->{3} += $v;
    }
    $result->{3} /= $sc;
    $result->{3} *= 2048;
    $result->{3} /= 65535;

    #$self->writeByteData(1, 0b11011011, 0b10000011);
    #Time::HiRes::sleep(1/64);
    #$self->writeBlockData(1, [0b01010010, 0b10000011]); # OS | A1_GND | PGA256 | SINGLE
    #Time::HiRes::sleep(1/64);
    #@{$result}{qw/m1 l1/} = $self->readBlockData(0x0, 2);
    #$result->{1} = $result->{m1} << 8 | $result->{l1};
    #$self->writeByteData(1, 0b11101011, 0b10000011);
    #Time::HiRes::sleep(1/64);
    #$self->writeBlockData(1, [0b01100010, 0b10000011]); # OS | A1_GND | PGA256 | SINGLE
    #Time::HiRes::sleep(1/64);
    #@{$result}{qw/m2 l2/} = $self->readBlockData(0x0, 2);
    #$result->{2} = $result->{m2} << 8 | $result->{l2};
    #$self->writeByteData(1, 0b11111011, 0b10000011);
    #Time::HiRes::sleep(1/64);
    #$self->writeBlockData(1, [0b01110010, 0b10000011]); # OS | A1_GND | PGA256 | SINGLE
    #Time::HiRes::sleep(1/64);
    #@{$result}{qw/m3 l3/} = $self->readBlockData(0x0, 2);
    #$result->{3} = $result->{m3} << 8 | $result->{l3};
    delete @{$result}{qw/m0 l0 m1 l1 m2 l2 m3 l3/};
    return $result;
}

1;
