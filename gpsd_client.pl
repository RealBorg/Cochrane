#!/usr/bin/perl
use strict;
use warnings;
use bytes;

use constant {
    DEBUG => 0,
};

print "starting $0\n";

while (1) {
    eval {
        use FindBin;
        use lib "${FindBin::Bin}/lib";

        use IO::Socket::INET;

        use POSIX qw//;
        $ENV{TZ} = 'UTC';
        POSIX::tzset();

        my $gpsd = IO::Socket::INET->new(
            PeerAddr => '127.0.0.1', 
            PeerPort => 2947,
            Timeout => 10,
        );
        if ($gpsd) {
            $_ = <$gpsd>;
            print $_;
            $gpsd->write("?WATCH={\"enable\":true,\"json\":true}\n");
            # ?WATCH={"enable":true,"raw":1}
        } else {
            warn "gpsd not running";
            sleep 6;
            next;
        }

        use Cochrane::Output::GPIO;
        my $gpio = Cochrane::Output::GPIO->new(26);

        use Cochrane::JSON;
        use Cochrane::Store::Position;
        use Cochrane::Store::Pressure;

        my $position = {
            count => 0,
            lat => 0,
            lng => 0,
            time => time() + 10,
        };
        my $old_position;
        LINE: while (<$gpsd>) {
            my $line = Cochrane::JSON->decode($_);
            STDOUT->print(Cochrane::JSON->encode($line)) if DEBUG;
            if ($line->{class} eq 'DEVICES') {
            } elsif ($line->{class} eq 'GST') {
            } elsif ($line->{class} eq 'SKY') {
                my @active = grep($_->{ss} > 0, @{$line->{satellites}});
                if (scalar(@active) > 0) {
                    STDOUT->print("SKY: \n");
                    for my $sat (@active) {
                        STDOUT->printf("  prn=%s az=%s el=%s snr=%s\n", $sat->{PRN}, $sat->{az}, $sat->{el}, $sat->{ss});
                    }
                }
            } elsif ($line->{class} eq 'PPS') {
            } elsif ($line->{class} eq 'TPV') {
                if ($line->{mode} > 1) {
                    $gpio->blink;

                    next LINE unless $line->{time} =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/;
                    my $time = POSIX::mktime($6, $5, $4, $3, $2 - 1, $1 - 1900);
                    
                    if ($time > $position->{time}) {
                        if (my $p = Cochrane::Store::Pressure->last) {
                            $position->{alt} = $p->altitude;
                        } elsif ($position->{gpsalt}) {
                            $position->{alt} = $position->{gpsalt};
                        } else {
                            $position->{alt} = 0;
                        }
                        $position->{lat} /= $position->{count};
                        $position->{lng} /= $position->{count};

                        $position = Cochrane::Store::Position->new($position, $old_position);
                        STDOUT->print($position, "\n");
                        $old_position = $position;
                        $position = {
                            count => 0,
                            lat => 0,
                            lng => 0,
                            time => $time + 10,
                        };
                    }

                    if ($line->{altMSL}) {
                        $position->{gpsalt} = $line->{altMSL};
                    }
                    $position->{lat} += $line->{lat};
                    $position->{lng} += $line->{lon};
                    $position->{count}++;
                }
            } elsif ($line->{class} eq 'VERSION') {
            } elsif ($line->{class} eq 'WATCH') {
            } else {
                STDOUT->print(Cochrane::JSON->encode($line));
            }
            if ($position->{count} >= 10) {
            }
        }
    };
    warn $@ if $@;
}
