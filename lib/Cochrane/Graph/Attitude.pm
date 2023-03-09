package Cochrane::Graph::Attitude;

use parent 'Cochrane::Graph';

use Cochrane::Store::Attitude;
use GD;

use Math::Trig qw//;
use Time::HiRes qw//;

use POSIX qw//;
$ENV{TZ} = 'UTC';
POSIX::tzset();

my $DEBUG = 1;

use strict;
use warnings;

sub new {
    my ($self, $opt) = @_;

    $opt->{width} ||= $self->WIDTH();
    $opt->{height} ||= $self->HEIGHT();
    my $time = time();

    my $attitude = Cochrane::Store::Attitude->last;
    return undef unless $attitude;

    my $img = GD::Image->newTrueColor($opt->{width}, $opt->{height});
    my $white = $img->colorAllocate(255, 255, 255);
    $img->filledRectangle(0, 0, $opt->{width}, $opt->{height}, $white);
    my $black = $img->colorAllocate(0, 0, 0);
    $img->setAntiAliased($black);

    #my $px = $opt->{height} / 60;
    my $cx = $opt->{width} / 2;
    my $cy = $opt->{height} / 2;

    #$img->line($cx, $cy, $opt->{width}, $cy - $cx * sin($attitude->{roll}), $black);
    #$img->line($cx, $cy, 0, $cy + $cx * sin($attitude->{roll}), $black);

    my $range = atan2($cy, $cx);

    my $py = $cy + $cy / $range * $attitude->{pitch};
    #$img->line(0, $py, $opt->{width}, $py, $black);

    $img->line($cx, $py, $opt->{width}, $py - $cx * sin($attitude->{roll}), $black);
    $img->line($cx, $py, 0, $py + $cx * sin($attitude->{roll}), $black);

    {
        my $heading = $attitude->{heading};
        if ($heading < 0) {
            $heading += 360;
        }
        my $label = sprintf("%.0f", $heading);
        my @bounds = GD::Image->stringFT($black, $self->FONT(), $opt->{height} / 10, 0, $cx, $cy, $label);
        my $width = $bounds[2] - $bounds[0];
        my $height = $bounds[1] - $bounds[5];
        warn "$width $height";
        $img->stringFT($black, $self->FONT(), $opt->{height} / 10, 0, $cx - $width / 2, $cy - $height / 2, $label);
    }

    return $img;
}

1;
