package Cochrane::Graph::Rotation;

use parent 'Cochrane::Graph';

use Cochrane::Store::Acceleration;
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
    $graph->set_legend(qw/a_x a_y a_z g_x g_y g_z/);
    $graph->set(x_label_skip => 60);
    my $data;
    FILE: for my $file (Cochrane::Store::Acceleration->list) {
        next FILE if $file < $opt->{start};
        next FILE if $file > $opt->{end};
        if (my $sa = Cochrane::Store::Acceleration->get($file)) {
            $sa = [ $sa ] unless ref($sa) eq 'ARRAY';
            SAMPLE: for my $s (@{$sa}) {
                next SAMPLE if $s->{time} < $opt->{start};
                next SAMPLE if $s->{time} > $opt->{end};

                push @{$data->[0]}, POSIX::strftime('%H:%M:%S', POSIX::localtime($s->{time}));
                push @{$data->[1]}, $s->{g_x}->{avg};
                push @{$data->[2]}, $s->{g_y}->{avg};
                push @{$data->[3]}, $s->{g_z}->{avg};
            }
        }
    }
    my $gd = $graph->plot($data) or die $graph->error;
    return $gd;
}

1;
