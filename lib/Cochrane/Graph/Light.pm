package Cochrane::Graph::Light;

use parent 'Cochrane::Graph';

use Cochrane::Store::Light;
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
        $opt->{start} = time() - 24 * 60 * 60;
    }
    if ($opt->{end} && $opt->{end} =~ /^(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)$/) {
        $opt->{end} = POSIX::mktime($6, $5, $4, $3, $2 - 1, $1 - 1900);
    } else {
        $opt->{end} = $opt->{start} + 24 * 60 * 60;
    }

    my $graph = GD::Graph::lines->new($opt->{width}, $opt->{height});
    $graph->set_legend(qw/IR R G B/);
    $graph->set(dclrs => [qw/purple red green blue/]);
    $graph->set(x_label_skip => 60);
    my $data;
    FILE: for my $file (Cochrane::Store::Light->list) {
        next FILE if $file < $opt->{start};
        next FILE if $file > $opt->{end};
        if (my $sa = Cochrane::Store::Light->get($file)) {
            $sa = [ $sa ] unless ref($sa) eq 'ARRAY';
            SAMPLE: for my $s (@{$sa}) {
                next SAMPLE if $s->{time} < $opt->{start};
                next SAMPLE if $s->{time} > $opt->{end};

                push @{$data->[0]}, POSIX::strftime('%H:%M:%S', POSIX::localtime($s->{time}));
                push @{$data->[1]}, $s->{IR};
                push @{$data->[2]}, $s->{R};
                push @{$data->[3]}, $s->{G};
                push @{$data->[4]}, $s->{B};
            }
        }
    }
    my $gd = $graph->plot($data) or die $graph->error;
    my $label = sprintf(
        "%.0f IR\r\n%.0f R\r\n%.0f G\r\n%.0f B",
        $data->[1]->[scalar(@{$data->[1]}) - 1],
        $data->[2]->[scalar(@{$data->[2]}) - 1],
        $data->[3]->[scalar(@{$data->[3]}) - 1],
        $data->[4]->[scalar(@{$data->[4]}) - 1],
    );
    my $size = 35 * $opt->{height} / 512;
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
    return $gd;
}


1;
