package Cochrane::Graph::Vibration;

use parent 'Cochrane::Graph';

use Cochrane::Store::Acceleration;
use GD;
use GD::Graph::lines;
use POSIX qw//;

use strict;
use utf8;
use warnings;

$| = 1;

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
    $graph->set_legend(qw/a a_x a_y a_x g_x g_y g_z/);
    $graph->set(dclrs => [qw/red lred lred lred green green green/]);
    $graph->set(x_label_skip => 60);
    $graph->set(line_types => [ 1, 3, 3, 3, 3, 3, 3 ]);
    my $data;
    FILE: for my $file (Cochrane::Store::Acceleration->list) {
        next FILE if ( $file + 24 * 60 * 60 ) < $opt->{start};
        next FILE if $file > $opt->{end};
        if (my $sa = Cochrane::Store::Acceleration->get($file)) {
            $sa = [ $sa ] unless ref($sa) eq 'ARRAY';
            SAMPLE: for my $s (@{$sa}) {
                next SAMPLE if $s->{time} < $opt->{start};
                next SAMPLE if $s->{time} > $opt->{end};

                push @{$data->[0]}, POSIX::strftime('%H:%M:%S', POSIX::gmtime($s->{time}));
                push @{$data->[1]}, $s->{a}->{sqe};
                push @{$data->[2]}, $s->{a_x}->{sqe};
                push @{$data->[3]}, $s->{a_y}->{sqe};
                push @{$data->[4]}, $s->{a_z}->{sqe};
                push @{$data->[5]}, $s->{g_x}->{sqe} * 10;
                push @{$data->[6]}, $s->{g_y}->{sqe} * 10;
                push @{$data->[7]}, $s->{g_z}->{sqe} * 10;
            }
        }
    }
    my $gd = $graph->plot($data) or die $graph->error;
    return $gd;
}


1;
