package Cochrane::Output::TTS;

use strict;
use warnings;

use IO::Pipe;

use constant {
    TTS => [
        '/usr/bin/festival',
        '--tts',
    ],
};

sub new {
    my ($class) = @_;

    my $self = {};
    $self = bless ($self, $class);
    return $self;
}

sub filter {
    (my $self, $_) = @_;

    s/-/ minus /g;
    s/(\d)\.(\d)/$1 decimal $2/g;
    s/0/ zero /g;
    s/1/ one /g;
    s/2/ two /g;
    s/3/ three /g;
    s/4/ four /g;
    s/5/ five /g;
    s/6/ six /g;
    s/7/ seven /g;
    s/8/ eight /g;
    s/9/ nine /g;
    s/ +/ /g;
    s/^ +//gm;

    return $_;
}

sub say {
    (my $self, $_) = @_;
    
    $_ = $self->filter($_);
    STDOUT->print("say: $_\n");
    my $pipe = IO::Pipe->new();
    $pipe->writer(@{TTS()});
    $pipe->print($_);
    $pipe->close;
}

sub duration {
    my ($self, $duration) = @_;

    my $result = '';
    if ($duration) {
        $duration = $duration / (60*60);
        if ($duration >= 1) {
            $result .= sprintf("%.0f hours", int($duration));
            $duration -= int($duration);
        }
        $duration *= 60;
        if ($duration >= 1) {
            $result .= sprintf(" %.0f minutes", $duration);
            $duration -= int($duration);
        }
        $duration *= 60;
        if ($duration >= 1) {
            $result .= sprintf(" %.0f seconds", $duration);
        }
    }
    return $result;
}

sub position {
    my ($self, $lat, $lng, $alt) = @_;

    my $result .= sprintf(
        "%.3f %s ;%.3f %s; altitude %.0f meters", 
        $lat,
        ($lat > 0 ? 'north' : 'south'),
        $lng,
        ($lng > 0 ? 'east' : 'west'),
        $alt,
    );
    $result =~ s/\./ decimal /g;
    return $result;
}

sub time {
    my ($self, $time) = @_;
    $time ||= time();
    $time = [ gmtime($time) ];
    $time = POSIX::strftime('%H %M %S', @{$time});
    return $time;
}

sub ogg {
    (my $self, $_) = @_;


    my $fn = Cochrane::Store::PATH_RUN() . '/tts/' . CORE::time() . '.txt';
    Cochrane::Store->write_file(
        "$fn.txt",
        $_,
    );
    system '/usr/bin/text2wave',
        -o => "$fn.wav",
        "$fn.txt";
    system '/usr/bin/sox',
        "$fn.wav",
        "$fn.ogg";
    $_ = Cochrane::Store->read_file("$fn.ogg");
    return $_;
}

1;
