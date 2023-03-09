#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Store::Pressure;
use Device::Thermometer::BMP085;

use POSIX qw//;
use Time::HiRes qw//;

use strict;
use warnings;

$ENV{TZ} = 'UTC';
POSIX::tzset();

my $bmp085 = Device::Thermometer::BMP085->new(I2CBusDevicePath => '/dev/i2c-1');
while (1) {
    my $t = [ localtime(time()) ];
    $t->[0] = 0;
    $t->[1]++;
    $t = POSIX::mktime(@{$t});
    my $sleep = $t - Time::HiRes::time();
    Time::HiRes::sleep($sleep) if $sleep > 0;
    my $s = $bmp085->get_data;
    $s->{time} = $t;
    $s = Cochrane::Store::Pressure->new($s);
    STDOUT->print("$s\n");
}
