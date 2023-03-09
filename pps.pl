#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Output::LED;
use Cochrane::Output::GPIO;

use POSIX qw//;
use Time::HiRes qw//;

use strict;
use warnings;

$ENV{TZ} = 'UTC';
POSIX::tzset();

$| = 1;

my $led = Cochrane::Output::LED->new("led1"); # led0 = red, led1 = green
my $gpio = Cochrane::Output::GPIO->new(26);

while (1) {
    my $time = Time::HiRes::time;
    my $sleep = 1 - ($time - int($time));
    STDOUT->printf("%.6f\n", $sleep);
    Time::HiRes::sleep($sleep);
    $gpio->blink();
    $led->shot();
}
