package Cochrane::Output::Morse;

use strict;
use warnings;

use IO::File;
use POSIX qw//;
use Time::HiRes qw//;

use Cochrane::Util::Morse;

use constant {
    INTERVAL => 0.1,
};

sub new {
    my ($class, $gpio, $interval) = @_;

    die "gpio must be specified" unless $gpio;
    my $self = {
        gpio => $gpio,
        interval => $interval || INTERVAL(),
    };
    system '/usr/bin/gpio', 'export', $self->{gpio}, 'out';
    $self->{fh} = IO::File->new("/sys/class/gpio/gpio$gpio/value", O_WRONLY);
    return bless($self);
}

sub send {
    my ($self, $sentence) = @_;

    my @chars = split(//, $sentence);
    CHAR: for my $char (@chars) {
        $char = uc($char);
        my $code = Cochrane::Util::Morse::L2M()->{$char};
        next CHAR unless $code;
        my @symbols = split(//, $code);
        for my $symbol (@symbols) {
            if ($symbol eq '.') {
                $self->{fh}->syswrite("1\n");
                Time::HiRes::sleep($self->{interval});
                $self->{fh}->syswrite("0\n");
            } elsif ($symbol eq '-') {
                $self->{fh}->syswrite("1\n");
                Time::HiRes::sleep(3 * $self->{interval});
                $self->{fh}->syswrite("0\n");
            } elsif ($symbol eq ' ') {
                Time::HiRes::sleep($self->{interval});
            } else {
                warn "unknown symbol: $symbol";
            }
            Time::HiRes::sleep($self->{interval});
        }
        Time::HiRes::sleep(2 * $self->{interval});
    }
}

1;
