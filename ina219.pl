#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Device::Ammeter::INA219;
use Cochrane::Store::Power;

use POSIX qw//;

use Time::HiRes qw//;

#use JSON qw//;
#my $json = JSON->new->canonical->pretty->utf8;

use strict;
use warnings;

$ENV{TZ} = 'UTC';
POSIX::tzset();

$| = 1;

my $ina219 = Device::Ammeter::INA219->new();
$ina219->setBusVoltageRange(16);
$ina219->setSampleCount(128);
while (1) {
    my $t = [ localtime() ];
    $t->[0] = 0;
    $t->[1]++;
    $t = POSIX::mktime(@{$t});
    my $sum = {
        count => 0,
        current => 0,
        voltage => 0,
        power => 0,
        time => $t,
    };
    my $t0 = Time::HiRes::time();
    while ($t0 < $t) {
        $t0 += 0.0681;
        my $sleep = $t0 - Time::HiRes::time();
        Time::HiRes::sleep($sleep) if $sleep > 0;
        my $sample = $ina219->get_data();
        $sum->{count}++;
        for (qw/current power voltage/) {
            $sum->{$_} += $sample->{$_};
        }
    }
    for (qw/current power voltage/) {
        $sum->{$_} /= $sum->{count};
    }
    $sum = Cochrane::Store::Power->new($sum);
    print $sum->stringify();
    my $sleep = $t - Time::HiRes::time();
    Time::HiRes::sleep($sleep) if $sleep > 0;
    #print $json->encode($s);
}
