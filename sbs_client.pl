#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "${FindBin::Bin}/lib";
chdir "${FindBin::Bin}";

use Cochrane::Store;
use Cochrane::Store::Plane;
use Cochrane::Store::Position;

my $ft2m = 0.3048;
my $kt2m = 1852;

use Data::Dumper;
use Geo::ECEF;
my $ecef = Geo::ECEF->new;
use Geo::Ellipsoid;
my $ellipsoid = Geo::Ellipsoid->new(
    ellipsoid => 'WGS84',
    units => 'degrees',
    distance_units => 'meter',
);
use IO::File;
use IO::Socket::INET;
use Math::Trig;
use POSIX ();
use Socket;
use Time::HiRes qw//;

$ENV{TZ} = 'UTC';
POSIX::tzset();

my $cfg = {
    ttl => 60,
};
my $dbg = {
};

print "starting $0\n";
while (1) {

    my $source = IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => 30003, Reuse => 1);
    unless ($source) {
        warn "Failed to connect: $!";
        sleep 1;
        next;
    }

    LINE: while (<$source>) {
        chomp;
        next if /^$/;
        my @msg = split(/,/, $_);
        my $icao = $msg[4];
        next unless $icao;
        my $plane = Cochrane::Store::Plane->get($icao);
        $plane = {
            count => 0,
            icao => $icao,
            path => [],
        } unless $plane;
        $plane->{count} += 1;
        $plane->{seen} = Time::HiRes::time();
        if (my $flight = $msg[10]) {
            $flight =~ s/[^\w]+//g;
            $plane->{flight} = $flight;
        }
        if (my $altitude = $msg[11]) {
            $altitude = sprintf("%.0f", $msg[11] * $ft2m);
            $plane->{altitude} = $altitude;
        }
        if (my $spd = $msg[12]) {
            $spd = sprintf("%.0f", $spd * $kt2m / 3600);
            $plane->{spd} = $spd;
        }
        if (my $hdg = $msg[13]) {
            $plane->{hdg} = $msg[13]
        }

        if ((my $lat = $msg[14]) && (my $lng = $msg[15])) {
            $plane->{lat} = $lat;
            $plane->{lng} = $lng;
            push @{$plane->{path}}, {
                lat => $lat,
                lng => $lng,
            };
            my $position = Cochrane::Store::Position->last;
            if ($position && $plane->{altitude}) {
                my ($x, $y, $z) = $ecef->ecef($lat, $lng, $plane->{altitude});
                my $distance = sprintf('%.0f', sqrt(($position->{x} - $x)**2 + ($position->{y} - $y)**2 + ($position->{z} - $z)**2));
                $plane->{distance} = $distance;
                $plane->{distance_max} = $distance unless $plane->{distance_max} && $plane->{distance_max} > $distance;
                $plane->{distance_min} = $distance unless $plane->{distance_min} && $plane->{distance_min} < $distance;
            }
        }
        if (my $vertical = $msg[16]) {
            $plane->{vertical} = sprintf("%.0f", $vertical * $ft2m);
        }
        $plane->{squawk} = $msg[17] if $msg[17];
        #$json = undef;
        $plane = Cochrane::Store::Plane->new($plane);
    }
}
warn;
