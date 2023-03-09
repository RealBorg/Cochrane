#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Store::Pressure;
use Device::Hygrometer::BME280;

use POSIX qw//;
use Time::HiRes qw//;

use JSON qw//;
my $json = JSON->new->canonical->pretty->utf8;

use strict;
use warnings;

$ENV{TZ} = 'UTC';
POSIX::tzset();

$| = 1;

while (1) {
    eval {
        my $bme280 = Device::Hygrometer::BME280->new();
        while (1) {
            my $t = [ localtime(time()) ];
            $t->[0] = 0;
            $t->[1]++;
            $t = POSIX::mktime(@{$t});
            my $sleep = $t - Time::HiRes::time();
            Time::HiRes::sleep($sleep) if $sleep > 0;
            my $s = $bme280->get_data;
            $s->{time} = $t;
            $s = Cochrane::Store::Pressure->new($s);
            STDOUT->print("$s\n");
        }
    };
    warn $@ if $@;
    sleep 6;
}
