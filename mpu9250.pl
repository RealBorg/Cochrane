#!/usr/bin/perl
print "starting $0\n";

use Math::Trig qw//;

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Store::Acceleration;
use Device::Accelerometer::MPU9250;

use POSIX qw//;
$ENV{TZ} = 'UTC';
POSIX::tzset();

use Time::HiRes qw//;

use strict;
use warnings;

my $mpu9250 = Device::Accelerometer::MPU9250->new;
my $ak8963 = $mpu9250->ak8963;

#$| = 1;
$SIG{'CHLD'} = 'IGNORE';

while (1) {
    my $t = [ gmtime() ];
    $t->[0] = 0;
    $t = POSIX::mktime(@{$t});

    my $sa = [];

    for (my $i = 0; $i < 60 * 100; $i++) {
        my $t1 = $t + $i * 0.01;
        my $sleep = $t1 - Time::HiRes::time();
        next if $sleep < 0;
        Time::HiRes::sleep($sleep) if $sleep > 0;
        $sa->[$i] = {
            %{$mpu9250->get_data()},
            %{$ak8963->get_data()},
            time => $t1,
        };
    }
    my $pid = fork();
    if ($pid == 0) {
        POSIX::nice(15);
        my $data = {
            time => $t,
        };
        for my $s (@{$sa}) {
            next unless $s;
            $s->{a} = sqrt($s->{a_x}**2 + $s->{a_y}**2 + $s->{a_z}**2);
            $s->{m} = sqrt($s->{m_x}**2 + $s->{m_y}**2 + $s->{m_z}**2);
            for my $k (qw/a a_x a_y a_z g_x g_y g_z m m_x m_y m_z/) {
                unless ($data->{$k}->{cnt}) {
                    $data->{$k} = {
                        cnt => 0,
                        sum => 0,
                        sqe => 0,
                    };
                }
                $data->{$k}->{cnt} += 1;
                $data->{$k}->{sum} += $s->{$k};
            }
        }
        for my $k (qw/a a_x a_y a_z g_x g_y g_z m m_x m_y m_z/) {
            $data->{$k}->{avg} = delete($data->{$k}->{sum}) / $data->{$k}->{cnt};
        }
        for my $s (@{$sa}) {
            next unless $s;
            for my $k (qw/a a_x a_y a_z g_x g_y g_z m m_x m_y m_z/) {
                $data->{$k}->{sqe} += ($s->{$k} - $data->{$k}->{avg})**2;
            }
        }
        for my $k (qw/a a_x a_y a_z g_x g_y g_z m m_x m_y m_z/) {
            $data->{$k}->{sqe} = sqrt($data->{$k}->{sqe} / $data->{$k}->{cnt});
        }
        $data = Cochrane::Store::Acceleration->new($data);
        print "$data\n";
        exit 0;
    }
}
