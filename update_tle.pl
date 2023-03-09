#!/usr/bin/perl
print "starting $0\n";

use FindBin;
use lib "${FindBin::Bin}/lib";

use Cochrane::Store::Satellite;

use POSIX qw//;
$ENV{TZ} = 'UTC';
POSIX::tzset();

use strict;
use warnings;

Cochrane::Store::Satellite->update;

