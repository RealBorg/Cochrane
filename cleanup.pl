#!/usr/bin/perl
print "starting $0\n";

use FindBin;
use lib "${FindBin::Bin}/lib";


use POSIX qw//;
$ENV{TZ} = 'UTC';
POSIX::tzset();
POSIX::nice(19);

use Time::HiRes qw//;

use strict;
use warnings;

while (1) {
    my $t = [ gmtime(time() + 60 * 60) ];
    $t->[0] = 0;
    $t->[1] = 0;
    $t = POSIX::mktime(@{$t});
    my $sleep = $t - Time::HiRes::time();
    Time::HiRes::sleep($sleep) if $sleep > 0;
    if (0) {
        use Cochrane::Store::Acceleration;
        Cochrane::Store::Acceleration->cleanup();
    }
    if (0) {
        use Cochrane::Store::Humidity;
        Cochrane::Store::Humidity->cleanup();
    }
    if (0) {
        use Cochrane::Store::MagField;
        Cochrane::Store::MagField->cleanup();
    }
    if (0) {
        use Cochrane::Store::Plane;
        Cochrane::Store::Plane->cleanup();
    }
    if (0) {
        use Cochrane::Store::Position;
        Cochrane::Store::Position->cleanup();
    }
    if (1) {
        use Cochrane::Store::Pressure;
        Cochrane::Store::Pressure->cleanup();
    }
}
