package Cochrane::Graph::Warming;

use parent 'Cochrane::Graph';

use Cochrane::Store::Temperature;
use GD;
use GD::Graph::lines;
use POSIX qw//;

use strict;
use utf8;
use warnings;

use constant {
    OFFSET => 4,
};

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
    for (my $t = $opt->{start}; $t < $opt->{end}; $t += $day) {
        for (my $offset = 0; $offset < OFFSET; $offset++) {
            my $file = [ gmtime($t - $offset * 365 * $day) ];
            $file->[0] = 0;
            $file->[1] = 0;
            $file->[2] = 0;
            $file = POSIX::mktime(@{$file});
            if (my $sa = Cochrane::Store::Temperature->get($file)) {
                SAMPLE: for my $s (@{$sa}) {
                    next SAMPLE unless $s->{time};
                    next SAMPLE unless $s->{time} > ($opt->{start} - $offset * 365 * $day);
                    next SAMPLE unless $s->{time} < ($opt->{end} - $offset * 365 * $day);

                    my $key = int($s->{time} / $interval) * $interval;
                    if ($d->{$key}) {
                        $d->{$key}->{c} += 1;
                        $d->{$key}->{t} += $s->{temperature};
                    } else {
                        $d->{$key}->{c} = 1;
                        $d->{$key}->{t} = $s->{temperature};
                    }
                }
            }
        }
    }
    my $lastlabel;
    my $legend;
    my $data;
    for (my $t = int($opt->{start} / $interval) * $interval; $t < $opt->{end}; $t += $interval) {
        my $label = POSIX::strftime($x_label_format, gmtime($t));
        if ($lastlabel && $lastlabel eq $label) {
            $label = '';
        } else {
            $lastlabel = $label;
        }
        push @{$data->[0]}, $label;
        for (my $offset = 0; $offset < OFFSET; $offset++) {
            my $t2 = $t - $offset * 365 * $day;
            my $value = undef;
            if (my $val = $d->{$t2}) {
                $val->{a} = $val->{t} / $val->{c};
                $value = $val->{a};
                if (my $l = $legend->{$offset}) {
                    $l->{cnt}++;
                    $l->{sum} += $value;
                } else {
                    $legend->{$offset} = {
                        cnt => 1,
                        sum => $value,
                    };
                }
            }
            push @{$data->[1 + $offset]}, $value;
        }
    }
    #$graph->set_x_label_font("comic.ttf", 10);
    my $graph = GD::Graph::lines->new($opt->{width}, $opt->{height});
    $graph->set(
        y_long_ticks => 1,
        x_last_label_skip => 1,
        fgclr => 'black',
        legendclr => 'black',
        line_width => 5,
        axislabelclr => 'black',
        x_ticks => 0,
        dclrs => [qw/red orange gold lyellow/],
    );
    for (my $offset = 0; $offset < OFFSET; $offset++) {
        if ($legend->{$offset}) {
            $legend->{$offset}->{avg} = $legend->{$offset}->{sum} / $legend->{$offset}->{cnt};
            push @{$legend->{legend}}, sprintf('%s %.1f°C', POSIX::strftime('%Y', gmtime($opt->{start} - $offset * 365 * $day)), $legend->{$offset}->{avg});
        } else {
            push @{$legend->{legend}}, sprintf('%s', POSIX::strftime('%Y', gmtime($opt->{start} - $offset * 365 * $day)));
        }
    }
    $graph->set_legend(@{$legend->{legend}});
    #POSIX::strftime('%Y-%m-%d', gmtime($opt->{start})),
    #POSIX::strftime('%Y-%m-%d', gmtime($opt->{end})),
    $graph->set_legend_font($self->FONT(), 10);
    $graph->set_x_axis_font($self->FONT(), 10);
    $graph->set_y_axis_font($self->FONT(), 10);
    my $gd = $graph->plot($data) or die $graph->error;
    return $gd;
}

1;
