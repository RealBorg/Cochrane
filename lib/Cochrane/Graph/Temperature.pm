package Cochrane::Graph::Temperature;

use parent 'Cochrane::Graph';

use Cochrane::Store::Temperature;

use GD;
use GD::Graph::lines;

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
        $opt->{start} = time() - 7 * 24 * 60 * 60;
    }
    if ($opt->{end} && $opt->{end} =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)$/) {
        $opt->{end} = POSIX::mktime($6, $5, $4, $3, $2 - 1, $1 - 1900);
    } else {
        $opt->{end} = $opt->{start} + 7 * 24 * 60 * 60;
    }
    return undef unless $opt->{end} > $opt->{start};
    if ($opt->{path} =~ /\/day/) {
        my $tm = [ gmtime() ];
        $opt->{end} = POSIX::mktime(@{$tm});
        $tm->[0] = 0;
        $tm->[1] = 0;
        $tm->[2] = 0;
        $opt->{start} = POSIX::mktime(@{$tm});
    } elsif ($opt->{path} =~ /\/(month|mtd)/) {
        my $tm = [ gmtime() ];
        $opt->{end} = POSIX::mktime(@{$tm});
        $tm->[0] = 0;
        $tm->[1] = 0;
        $tm->[2] = 0;
        $tm->[3] = 1;
        $opt->{start} = POSIX::mktime(@{$tm});
    } elsif ($opt->{path} =~ /\/(year|ytd)/) {
        my $tm = [ gmtime() ];
        $opt->{end} = POSIX::mktime(@{$tm});
        $tm->[0] = 0;
        $tm->[1] = 0;
        $tm->[2] = 0;
        $tm->[3] = 1;
        $tm->[4] = 0;
        $opt->{start} = POSIX::mktime(@{$tm});
    }

    my $x_label_format = '%Y%m%d';
    my $interval = $opt->{end} - $opt->{start};
    if ($interval < 24 * 60 * 60) {
        $interval = 60;
        $x_label_format = '%H';
    } elsif ($interval < 3 * 24 * 60 * 60) {
        $interval = 3 * 60;
        $x_label_format = '%H';
    } elsif ($interval < 8 * 24 * 60 * 60) {
        $interval = 6 * 60;
        $x_label_format = '%d';
    } elsif ($interval < 32 * 24 * 60 * 60) {
        $interval = 30 * 60;
        $x_label_format = '%d';
    } elsif ($interval < 93 * 24 * 60 * 60) {
        $interval = 60 * 60;
        $x_label_format = '%d';
    } elsif ($interval < 367 * 24 * 60 * 60) {
        $interval = 24 * 60 * 60;
        $x_label_format = '%m';
    } else {
        $interval = 24 * 60 * 60;
        $x_label_format = '%m';
    }
    my $d;
    my $day = 24 * 60 * 60;
    for (my $t = $opt->{start}; $t < $opt->{end}; $t += 24 * 60 * 60) {
        my $file = [ gmtime($t) ];
        $file->[0] = 0;
        $file->[1] = 0;
        $file->[2] = 0;
        $file = POSIX::mktime(@{$file});
        if (my $sa = Cochrane::Store::Temperature->get($file)) {
            SAMPLE: for my $s (@{$sa}) {
                next SAMPLE unless $s->{time};
                next SAMPLE unless $s->{time} > $opt->{start};
                next SAMPLE unless $s->{time} < $opt->{end};

                my $key = int($s->{time} / $interval) * $interval;
                if ($d->{$key}) {
                    $d->{$key}->{c} += 1;
                    $d->{$key}->{t} += $s->{temperature};
                } else {
                    $d->{$key}->{c} = 1;
                    $d->{$key}->{t} = $s->{temperature};
                }
                my $key2 = int($s->{time} / $day) * $day;
                if ($d->{$key2} && $d->{$key2}->{min}) {
                    $d->{$key2}->{min} = $s->{temperature} if $s->{temperature} < $d->{$key2}->{min};
                    $d->{$key2}->{max} = $s->{temperature} if $s->{temperature} > $d->{$key2}->{max};
                } else {
                    $d->{$key2}->{min} = $s->{temperature};
                    $d->{$key2}->{max} = $s->{temperature};
                }
            }
        }
    }
    my $lastlabel;
    my $legend;
    my $data;
    for my $key (sort(keys(%{$d}))) {
        my $key2 = int($key / $day) * $day;
        my $label = POSIX::strftime($x_label_format, gmtime($key));
        if ($lastlabel && $lastlabel eq $label) {
            push @{$data->[0]}, '';
        } else {
            push @{$data->[0]}, $label;
            $lastlabel = $label;
        }
        $d->{$key}->{a} = $d->{$key}->{t} / $d->{$key}->{c} if $d->{$key}->{c};
        push @{$data->[1]}, $d->{$key}->{a};
        push @{$data->[2]}, $d->{$key2}->{min};
        push @{$data->[3]}, $d->{$key2}->{max};

        if ($legend) {
            $legend->{min} = $d->{$key2}->{min} if $d->{$key2}->{min} < $legend->{min};
            $legend->{max} = $d->{$key2}->{max} if $d->{$key2}->{max} > $legend->{max};
            $legend->{cnt}++;
            $legend->{sum} += $d->{$key}->{a};
        } else {
            $legend->{min} = $d->{$key2}->{min};
            $legend->{max} = $d->{$key2}->{max};
            $legend->{cnt} = 1;
            $legend->{sum} = $d->{$key}->{a};
        }
    }
    $legend->{avg} = $legend->{sum} / $legend->{cnt};

    my $graph = GD::Graph::lines->new($opt->{width}, $opt->{height});
    $graph->set(
        y_long_ticks => 1,
        x_last_label_skip => 1,
        fgclr => 'black',
        legendclr => 'black',
        axislabelclr => 'black',
        x_ticks => 0,
        dclrs => [ 'green', 'lblue', 'lred' ],
        y_number_format => "%.0f°C",
    );
    $graph->set_legend(
        sprintf(
            'Avg: %.1f° %s - %s', 
            $legend->{avg},
            POSIX::strftime('%Y-%m-%d', gmtime($opt->{start})),
            POSIX::strftime('%Y-%m-%d', gmtime($opt->{end})),
        ),
        sprintf('Min: %.1f°', $legend->{min}),
        sprintf( 'Max: %.1f°', $legend->{max}), 
    );
    $graph->set_legend_font($self->FONT(), 10);
    $graph->set_x_axis_font($self->FONT(), 10);
    $graph->set_y_axis_font($self->FONT(), 10);
    my $gd = $graph->plot($data) or die $graph->error;
    return $gd;
}

1;
