#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Store::Humidity;
use Device::Hygrometer::SI7021;
use POSIX qw//;
use Time::HiRes qw//;

use strict;
use warnings;

$ENV{TZ} = 'UTC';
POSIX::tzset();

my $si7021 = Device::Hygrometer::SI7021->new(I2CBusDevicePath => '/dev/i2c-1');
while (1) {
    my $t = [ POSIX::localtime(Time::HiRes::time()) ];
    $t->[0] = 0;
    $t->[1]++;
    $t = POSIX::mktime(@{$t});
    my $sleep = $t - Time::HiRes::time();
    Time::HiRes::sleep($sleep) if $sleep > 0;
    my $data = $si7021->get_data();
    $data->{time} = $t;
    $data = Cochrane::Store::Humidity->new($data);
    print "$data\n";
    #POSIX::strftime('%Y-%m-%dT%H:%M:%S', POSIX::localtime($s->{time})).' pressure='.$s->{pressure}.' temperature='.$s->{temperature}."\n";
}
