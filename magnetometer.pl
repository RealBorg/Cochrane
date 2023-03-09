#!/usr/bin/perl
use lib 'lib';

use Cochrane::Store;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

use Device::Magnetometer::HMC5883L;

use POSIX::RT::Clock;
my $rt = POSIX::RT::Clock->new('realtime');

use strict;
use warnings;

my $mag = Device::Magnetometer::HMC5883L->new;
while (1) {
    my $t = $rt->get_time;
    my $s = $mag->get_raw_data;
    $s->{time} = $t;
    Cochrane::Store->write_magnetic_field($s);
    $rt->sleep($t + 60, 1);
}
