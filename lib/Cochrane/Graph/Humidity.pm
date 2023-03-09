package Cochrane::Graph::Humidity;

use parent 'Cochrane::Graph';

use Cochrane::Store::Humidity;
use GD;
use GD::Graph::area;
use POSIX qw//;
use Physics::Psychrometry;

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

    my $graph = GD::Graph::area->new($opt->{width}, $opt->{height});
    $graph->set(
        dclrs => [qw/gold cyan/],
        x_label_skip => 24 * 60,
        y_long_ticks => 1,
        x_labels_vertical => 1,
    );
    my ($a, $data);
    my $c = 0;
    my $last;
    FILE: for my $file (Cochrane::Store::Humidity->list) {
        next FILE if $file < $opt->{start};
        next FILE if $file > $opt->{end};
        if (my $sa = Cochrane::Store::Humidity->get($file)) {
            $sa = [ $sa ] unless ref($sa) eq 'ARRAY';
            SAMPLE: for my $s (@{$sa}) {
                next SAMPLE if $s->{time} < $opt->{start};
                next SAMPLE if $s->{time} > $opt->{end};
                $last = $s;
                push @{$data->[0]}, POSIX::strftime('%a %Hh', localtime($s->{time}));
                my $e = Physics::Psychrometry::dbrh2e($s->{temperature}, $s->{humidity} / 100);
                my $dp = Physics::Psychrometry::e2dp($e);
                push @{$data->[2]}, $dp;
                push @{$data->[1]}, $s->{temperature};
            }
        }
    }
    my $gd = $graph->plot($data) or die $graph->error;
    my @bounds = GD::Image->stringFT(
        $gd->colorAllocate(0, 0, 0),
        $self->FONT(),
        35,
        0,
        0,
        0,
        sprintf("%.2f %%RH\n%.2f°C", $last->{humidity}, $last->{temperature}),
    );
    $gd->stringFT(
        $gd->colorAllocate(0, 0, 0),
        $self->FONT(),
        35,
        0,
        ( $gd->width - $bounds[2] ) / 2,
        ( $gd->height - $bounds[5] ) / 2,
        sprintf("%.2f %%RH\n%.2f°C", $last->{humidity}, $last->{temperature}),
    );
    return $gd;
}

1;
