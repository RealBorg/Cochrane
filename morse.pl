#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Output::Morse;
my $morse = Cochrane::Output::Morse->new(12, 0.040);

use POSIX qw//;

use Time::HiRes qw//;

use strict;
use warnings;

$ENV{TZ} = 'UTC';
POSIX::tzset();

$| = 1;

while (1) {
    $morse->send("Hello world. My name is Raspberry Pi ");
}

