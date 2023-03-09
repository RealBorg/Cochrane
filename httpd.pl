#!/usr/bin/perl
use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use strict;
use warnings;

while (1) {
    eval {
        use Cochrane::Output::HTTP;

        my $daemon = Cochrane::Output::HTTP->new();
        $daemon->run();
    };
    warn $@ if $@;
    sleep 6;
}
