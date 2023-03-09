#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Store::MagField;
use Device::Magnetometer::HMC5883L;

use POSIX qw//;
$ENV{TZ} = 'UTC';
POSIX::tzset();

use Time::HiRes qw//;

use strict;
use warnings;

my $mag = Device::Magnetometer::HMC5883L->new;
while (1) {

    my $t0 = [ localtime(time() + 60) ];
    $t0->[0] = 0;
    $t0 = POSIX::mktime(@{$t0});
    my $d = { 
        count => 0,
        time => $t0,
        x => 0,
        y => 0,
        z => 0,
    };
    for (my $i = 0; $i < 60; $i++) {
        my $s = $mag->get_raw_data;
        for my $key (qw/ x y z /) {
            $d->{$key} += $s->{$key};
        }
        $d->{count} += 1;
        my $sleep = $t0 - 60 + ($i + 1) - Time::HiRes::time();
        Time::HiRes::sleep($sleep) if $sleep > 0;
    }
    for my $key (qw/ x y z /) {
        $d->{$key} = $d->{$key} / $d->{count};
    }
    $d = Cochrane::Store::MagField->new($d);
    STDOUT->print("$d\n");
}
