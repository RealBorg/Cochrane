#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Store::Pressure;
use Device::Thermometer::BMP280;

use POSIX qw//;
use Time::HiRes qw//;

use JSON qw//;
my $json = JSON->new->canonical->pretty->utf8;

use strict;
use warnings;

$ENV{TZ} = 'UTC';
POSIX::tzset();

$| = 1;

my $bmp280 = Device::Thermometer::BMP280->new(I2CBusDevicePath => '/dev/i2c-1');
    my $s = $bmp280->get_calibration;
    print $json->encode($s);
while (1) {
    $s = $bmp280->get_data;
    print $json->encode($s);
    print $bmp280->get_pressure, "\n";
    print $bmp280->get_temp, "\n";
    sleep 1;
}
while (0) {
    my $t = [ localtime(time()) ];
    $t->[0] = 0;
    $t->[1]++;
    $t = POSIX::mktime(@{$t});
    my $sleep = $t - Time::HiRes::time();
    Time::HiRes::sleep($sleep) if $sleep > 0;
    my $s = $bmp280->get_data;
    $s->{time} = $t;
    $s = Cochrane::Store::Pressure->new($s);
    STDOUT->print("$s\n");
}
