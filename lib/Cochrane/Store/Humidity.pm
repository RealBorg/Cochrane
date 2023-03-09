package Cochrane::Store::Humidity;

use POSIX qw//;
use Time::HiRes qw//;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    PREFIX => 'humidity',
};

1;
