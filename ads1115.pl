#!/usr/bin/perl
use lib 'lib';

use Cochrane::Store;

use JSON qw//;
my $json = JSON->new->canonical->pretty->utf8;
use Time::HiRes qw//;

use Device::ADC::ADS1115;

use strict;
use warnings;

my $ads1115 = Device::ADC::ADS1115->new;
my $avg;
DATA: while (1) {
    my $t0 = Time::HiRes::time + 1/128;
    my $data = $ads1115->get_data;
    print $json->encode($data), "\n";
    next DATA;
    #printf "%0d\n", $data->{0};
    my $diff;
    for (qw/4 8 16 32 64 128 256 512 1024/) {
        $avg->{$_} = $data->{0} unless $avg->{$_};
        $diff->{$_} = $data->{0} - $avg->{$_};
        $avg->{$_} = $avg->{$_} + $diff->{$_} / $_;
        STDOUT->printf("%0d\t", $avg->{$_} - $avg->{$_ / 2}) if $_ > 4;
    }
    STDOUT->print("\n");
    #printf "%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%d0\t%d0\n", @{$diff}{qw/d4 d8 d16 d32 d64 d128 d256 d512 d1024/};
    #for (qw/4 8 16 32 64 128 256 512 1024/) {
    #    printf "%0d\t", $avg->{"a$_"};
    #}
    #print "\n";
    #printf "%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\n", @{$diff}{qw/4 8 16 32 64 128 256 512 1024/};
    #printf "%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\t%0d\n", @{$avg}{qw/4 8 16 32 64 128 256 512 1024/};
    #print $json->encode($data), "\n";
    $t0 = $t0 - Time::HiRes::time;
    Time::HiRes::sleep($t0) if $t0 > 0;
}

