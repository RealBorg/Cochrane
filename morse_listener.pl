#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Device::Ammeter::INA219;
use Cochrane::Util::Morse;
use Cochrane::Output::TTS;

use POSIX qw//;

use Time::HiRes qw//;

#use JSON qw//;
#my $json = JSON->new->canonical->pretty->utf8;

use strict;
use warnings;

$ENV{TZ} = 'UTC';
POSIX::tzset();

$| = 1;

#my $interval = 0.0681;
#my $interval = 0.03405;
#my $interval = 0.0851;
#my $interval = 0.0426;
#my $interval = 0.0213;
#my $interval = 0.0106;
my $interval = 0.00851;

my $ina219 = Device::Ammeter::INA219->new();
$ina219->setBusVoltageRange(16);
$ina219->setSampleCount(16);
my $avgcnt = 4.7;
my $cnt = 0;
my $v_prev;
my $letter = '';
my $word = '';
my $v_avg;
my $t0 = Time::HiRes::time() + $interval;
SAMPLE: while (1) {
    my $sleep = $t0 - Time::HiRes::time();
    $sleep > 0 ? Time::HiRes::sleep($sleep) : warn $sleep;
    $t0 = Time::HiRes::time() + $interval;
    my $v;
    {
        my $data = $ina219->get_data();
        $v = $data->{voltage};
        #print "$v ";
        $v_avg = $v unless defined($v_avg);
        $v_prev = $v unless defined($v_prev);
        $v_avg = ($v_avg * 10 * $avgcnt + $v) / (10 * $avgcnt + 1);
        #warn $count;
    }
    #print $avg > 0 ? '+' : '-';
    print $v > $v_avg ? '-' : '_';
    if ($v > $v_avg) {
        if ($v_prev <= $v_avg) {
            #print '/';
            #warn "0 $cnt";
            if ($cnt > (6 * $avgcnt) && $cnt < (8 * $avgcnt)) {
                $avgcnt = ($avgcnt * 9 + $cnt / 7) / 10;
            } elsif ($cnt > (2 * $avgcnt) && $cnt < (4 * $avgcnt)) {
                $avgcnt = ($avgcnt * 9 + $cnt / 3) / 10;
            } elsif ($cnt > (0.5 * $avgcnt) && $cnt < (2 * $avgcnt)) {
                $avgcnt = ($avgcnt * 9 + $cnt) / 10;
            }
            $cnt = 1;
        } else {
            $cnt++;
        }
    } else {
        if ($v_prev > $v_avg) {
            #print '\\';
            if ($cnt > (0.5 * $avgcnt) && $cnt < ( 2 * $avgcnt)) {
                #print '.';
                $letter .= '.';
                $avgcnt = ($avgcnt * 9 + $cnt) / 10;
            } elsif ($cnt > (2 * $avgcnt) && $cnt < ( 4 * $avgcnt)) {
                #print '-';
                $letter .= '-';
                $avgcnt = ($avgcnt * 9 + $cnt / 3) / 10;
            }
            $cnt = 1;
        } else {
            $cnt++;
        }
        if ($cnt > (2 * $avgcnt)) {
            if (length($letter) > 0) {
                #print "$avgcnt ";
                if (defined(Cochrane::Util::Morse::M2L()->{$letter})) {
                    $letter = Cochrane::Util::Morse::M2L()->{$letter}; 
                    print "$letter";
                    $word .= $letter;
                    $letter = '';
                } else {
                    #warn "$letter";
                    $letter = '';
                }
            }
        }
        if ($cnt > (6 * $avgcnt)) {
            if (length($word) > 0) {
                print " ";
                #Cochrane::Output::TTS->say($word);
                #warn $avgcnt;
                $word = '';
            }
        }
    }
    $v_prev = $v;
    #warn "diff=$diff avg=$avg";
}
