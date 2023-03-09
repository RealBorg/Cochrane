#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Store::Particles;
use Device::PM::SDS011;
use POSIX qw//;

use Time::HiRes qw//;

use strict;
use warnings;

$ENV{TZ} = 'UTC';
POSIX::tzset();

$| = 1;

my $device = Device::PM::SDS011->new('/dev/ttyAMA0');
while (my $data = $device->get_data()) {
    $data = Cochrane::Store::Particles->new($data);
    print $data;
}

