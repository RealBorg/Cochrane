#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Store::Acceleration;
use Device::Accelerometer::MPU6050;

use POSIX qw//;
$ENV{TZ} = 'UTC';
POSIX::tzset();

use Time::HiRes qw//;

use strict;
use warnings;

my $mpu6050 = Device::Accelerometer::MPU6050->new;

while (1) {
    my $t0 = [ localtime(time() + 60) ];
    $t0->[0] = 0;
    $t0 = POSIX::mktime(@{$t0});
    my $d = { 
        a_x => 0,
        a_y => 0,
        a_z => 0,
        count => 0,
        g_x => 0,
        g_y => 0,
        g_z => 0,
        time => $t0,
        temperature => 0,
    };
    for (my $i = 0; $i < (60 / 0.1); $i++) {
        my $s = $mpu6050->get_raw_data;
        for my $key (qw/ a_x a_y a_z g_x g_y g_z temperature /) {
            $d->{$key} += $s->{$key};
        }
        $d->{count} += 1;
        my $sleep = $t0 - 60 + ($i + 1) * 0.1 - Time::HiRes::time();
        Time::HiRes::sleep($sleep) if $sleep > 0;
    }
    for my $key (qw/ a_x a_y a_z g_x g_y g_z temperature /) {
        $d->{$key} = $d->{$key} / $d->{count};
    }
    $d = Cochrane::Store::Acceleration->new($d);
    STDOUT->print("$d\n");
}
