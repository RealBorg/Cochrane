package Cochrane::Graph::Power;

use parent 'Cochrane::Graph';

use Cochrane::Store::Power;
use GD;
use GD::Graph::area;
use POSIX qw//;

use strict;
use utf8;
use warnings;

sub new {
    my ($self, $opt) = @_;

    $opt->{width} ||= $self->WIDTH();
    $opt->{height} ||= $self->HEIGHT();

    if ($opt->{start} && $opt->{start} =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)$/) {
        $opt->{start} = POSIX::mktime($6, $5, $4, $3, $2 - 1, $1 - 1900);
    } else {
        $opt->{start} = time() - 24 * 60 * 60;
    }
    if ($opt->{end} && $opt->{end} =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)$/) {
        $opt->{end} = POSIX::mktime($6, $5, $4, $3, $2 - 1, $1 - 1900);
    } else {
        $opt->{end} = $opt->{start} + 24 * 60 * 60;
    }
    my $int = $opt->{end} - $opt->{start};
    if ($int > 24 * 60 * 60) {
        $int = 24 * 60 * 60;
    } else {
        $int = 60;
    }

    my $graph = GD::Graph::area->new($opt->{width}, $opt->{height});
    if ($int > 60) {
        $graph->set(x_label_skip => 60);
    } else {
        $graph->set(x_label_skip => 30);
    }
    $graph->set(cumulate => 1);
    $graph->set(dclrs => [qw/gold lorange lred/]);
    my $avg = {
        count => 0,
        power => 0,
    };
    my $last;
    my $max = {
        current => 0,
        power => 0,
        voltage => 0,
    };
    my $min;

    my %data;
    FILE: for my $file (Cochrane::Store::Power->list) {
        next FILE if ( $file + 24 * 60 * 60 ) < $opt->{start};
        next FILE if $file > $opt->{end};
        if (my $sa = Cochrane::Store::Power->get($file)) {
            $sa = [ $sa ] unless ref($sa) eq 'ARRAY';
            SAMPLE: for my $s (@{$sa}) {
                next SAMPLE if $s->{time} < $opt->{start};
                next SAMPLE if $s->{time} > $opt->{end};

                my $t = int($s->{time} / $int) * $int;
                unless (defined($data{$t})) {
                    $data{$t} = {
                        count => 0,
                        current => 0,
                        power => 0,
                        time => $t,
                        voltage => 0,
                    };
                }
                $data{$t}->{count}++;
                $data{$t}->{current} += $s->{current};
                $data{$t}->{power} += $s->{power};
                $data{$t}->{voltage} += $s->{voltage};

                $last = $s;
                $avg->{count}++;
                $max->{current} = $s->{current} if $s->{current} > $max->{current};
                $min->{current} = $s->{current} if !defined($min->{current}) || $s->{current} < $min->{current};
                $avg->{power} += $s->{power};
                $max->{power} = $s->{power} if $s->{power} > $max->{power};
                $min->{power} = $s->{power} if !defined($min->{power}) || $s->{power} < $min->{power};
                $max->{voltage} = $s->{voltage} if $s->{voltage} > $max->{voltage};
                $min->{voltage} = $s->{voltage} if !defined($min->{voltage}) || $s->{voltage} < $min->{voltage};
            }
        }
    }
    my @data;
    for my $t (sort(keys(%data))) {
        my $s = $data{$t};
        $s->{current} /= $s->{count};
        $s->{power} /= $s->{count};
        $s->{voltage} /= $s->{count};

        if ($int > 60) {
            push @{$data[0]}, POSIX::strftime('%Y-%m-%d', POSIX::localtime($s->{time}));
        } else {
            push @{$data[0]}, POSIX::strftime('%H:%M:%S', POSIX::localtime($s->{time}));
        }
        push @{$data[3]}, $s->{current};
        push @{$data[2]}, $s->{power};
        push @{$data[1]}, $s->{voltage};
    }
    $avg->{power} /= $avg->{count} if $avg->{count};
    my $gd = $graph->plot(\@data) if scalar(@data) > 0;
    if ($gd) {
        my $size = 20 * $opt->{height} / 512;
        my $label = sprintf("%.3fA (%.3fA %.3fA)\n", $last->{current}, $min->{current}, $max->{current}) .
            sprintf("%.3fW (%.3fW %.3fW)\n", $last->{power}, $min->{power}, $max->{power}) .
            sprintf("%.2fV (%.2fV %.2fV)\n", $last->{voltage}, $min->{voltage}, $max->{voltage}) .
            sprintf("%.0fh %.0fWh\n", $avg->{count} / 60 , ($avg->{count} * $avg->{power}) / 60);
        my @bounds = GD::Image->stringFT(
            $gd->colorAllocate(0, 0, 0),
            $self->FONT(),
            $size,
            0,
            0,
            0,
            $label
        );
        $gd->stringFT(
            $gd->colorAllocate(0, 0, 0),
            $self->FONT(),
            $size,
            0,
            ( $gd->width - $bounds[2] ) / 2,
            ( $gd->height - $bounds[1] ) / 2,
                $label
        );
    }
    return $gd;
}


1;
