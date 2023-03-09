#!/usr/bin/perl
print "starting $0\n";

use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use constant {
    AMIXER => [ '/usr/bin/amixer' ],
    MUSIC => '/home/tom/ogg/playlist',
    POCKETSPHINX => [
        'pocketsphinx_continuous', 
        -agc => 'noise', 
        -vad_postspeech => 20,
        -vad_prespeech => 50,
        -vad_startspeech => 5,
        -vad_threshold => 3, 
        -remove_dc => 'yes',
        -remove_noise => 'yes',
        -remove_silence => 'yes',
        -inmic => 'yes', 
        -dict => 'my.dict',
    ],
    POSITION => "http://raspi18.home.hostmaster.org:8081/position/data",
    PRESSURE => "http://raspi18.home.hostmaster.org:8081/temperature/data",
    PULSEAUDIO => '/usr/bin/pulseaudio',
};

my $self;

while (1) {
    eval {
        use Cochrane::Store;
        use Cochrane::Output::GPIO;
        use Cochrane::Output::TTS;
        use Cochrane::Input::HTTP;

        use IO::Pipe;
        use List::Util qw//;
        use POSIX qw//;
        use Time::HiRes qw//;

        use strict;
        use warnings;


        $ENV{TZ} = 'UTC';
        POSIX::tzset();

        $| = 1;

        $self = {
            light => 5,
            lights => [
                Cochrane::Output::GPIO->new(26),
            ],
            tts => Cochrane::Output::TTS->new(),
            volume => 5,
        };


        system '/usr/bin/pulseaudio', '--start';
        set_volume();
        unmute();
        my $pipe = IO::Pipe->new;
        $pipe->reader(@{POCKETSPHINX()});
        LINE: while (<$pipe>) {
            chomp;
            STDOUT->print("===>$_<===\n");
            next LINE if (/^$/);
            eval {
                if (/^altitude/) {
                    say_altitude();
                } elsif (/^favorite/) {
                    my $best = $self->{best};
                    unless ($best) {
                        $best = Cochrane::Store->read_file(MUSIC() . "/favorite.txt");
                        $best = [ split(/\r?\n/, $best) ];
                        $best = [ grep(!/^#/, @{$best}) ];
                        $best = [ List::Util::shuffle(@{$best}) ];
                        $self->{best} = $best;
                    }
                    my $file = shift(@{$best});
                    push @{$best}, $file;
                    $self->{last} = MUSIC() . '/' . $file;
                    play($self->{last});
                } elsif (/^date/) {
                    my $time = POSIX::time();
                    $time = [ POSIX::localtime($time) ];
                    $time = POSIX::strftime("%A, %B %e", @{$time});
                    say($time);
                } elsif (/^environment/) {
                    say_environment();
                } elsif (/^humidity/) {
                    say_humidity();
                } elsif (/^light down/) {
                    $self->{light}-- if $self->{light} > 0;
                    set_light();
                    say_light();
                } elsif (/^light up/) {
                    $self->{light}++ if $self->{light} < 11;
                    set_light();
                    say_light();
                } elsif (/^moon/) {
                    say_moon();
                } elsif (/^music/) {
                    my $music = $self->{music};
                    unless ($music) {
                        $music = Cochrane::Store->read_file(MUSIC() . "/all.txt");
                        $music = [ split(/\r?\n/, $music) ];
                        $music = [ List::Util::shuffle(@{$music}) ];
                    }
                    my $file = shift(@{$music});
                    push @{$music}, $file;
                    $self->{last} = MUSIC() . '/' . $file;
                    play($self->{last});
                } elsif (/^position/) {
                    say_position();
                } elsif (/^pressure/) {
                    say_pressure();
                } elsif (/^repeat/) {
                    if ($self->{last}) {
                        play($self->{last});
                    }
                } elsif (/^sun/) {
                    say_sun();
                } elsif (/^temperature/) {
                    say_temperature();
                } elsif (/^time/) {
                    say($self->{tts}->time() . ".\n");
                } elsif (/^volume down/) {
                    $self->{volume}-- if $self->{volume} > 0;
                    set_volume();
                    say_volume();
                } elsif (/^volume up/) {
                    $self->{volume}++ if $self->{volume} < 10;
                    set_volume();
                    say_volume();
                } elsif (/^weather/) {
                    use Cochrane::Store::METAR;
                    my $metar = Cochrane::Store::METAR->latest('LOWW');
                    $metar = $metar->ogg();
                    play('-', $metar);
                } elsif (/^forecast/) {
                    use Cochrane::Store::TAF;
                    my $taf = Cochrane::Store::TAF->latest('LOWW');
                    $taf = $taf->ogg();
                    play('-', $taf);
                } 
            };
            warn $@ if $@;
        }
    };
    warn $@ if $@;
    sleep 6;
}

sub mute {
    system @{AMIXER()}, 'cset', 'name=Capture Volume', 0;
}

sub unmute {
    do {
        system @{AMIXER()}, 'cset', "name=Capture Volume", 32768;
        if ($? != 0) {
            STDOUT->print("waiting for microphone...\n");
            sleep 6;
        }
    } while ($? != 0);
}

sub set_light {
    for (@{$self->{lights}}) {
        $_->pwm(2 ** $self->{light});
        #$_->pwm(2 ** $self->{light} - 1);
    }
}

sub say_light {
    say("light ".$self->{light});
}

sub set_volume {
    system @{AMIXER()}, 'cset', "name=Master Playback Volume", $self->{volume} * 6553;
}
sub say_volume {
    say("volume ".$self->{volume});
}

sub play {
    my ($file, $data) = @_;
    $last = $file;
    STDOUT->print("play: $file\n");
    mute();
    if ($file eq '-') {
        my $pipe = IO::Pipe->new();
        $pipe->writer('play', '-q', '-');
        $pipe->print($data);
        $pipe->close();
    } else {
        system 'play', '-q', $file;
    }
    unmute();
}

sub say {
    my ($say) = @_;

    #$say =~ s/(\d)\.(\d)/$1 decimal $2/g;
    #$say =~ s/(\d)/ $1 /g;
    mute();
    $self->{tts}->say($say);
    unmute();
}

sub say_altitude {
    eval {
        use Cochrane::Store::Pressure;
        use Cochrane::Store::METAR;

        my $qnh = 101325;
        if (my $metar = Cochrane::Store::METAR->last()) {
            if ($metar->{text} =~ /Q(\d\d\d\d)/) {
                $qnh = $1 * 100;
            }
        }
        my $pressure = Cochrane::Input::HTTP->get_json(PRESSURE());
        my $qne = $pressure->{'pressure'};
        my $alt = ($qnh - $qne ) / 12.2;
        $alt = sprintf("altitude %.1f meters", $alt);
        #$alt .= $tts->duration(time() - $pressure->{time}) . ' ago';
        say ($alt);
    };
    warn $@ if $@;
}

sub say_moon {
    if (my $p = Cochrane::Store::Position->last) {
        if ($p->moon) {

            my $say = 'Moon: ';
            use Math::Trig qw//;
            my $deg = Math::Trig::rad2deg($p->{moon}->{el});
            $say .= sprintf(
                "%.0f degree %s the horizon. ",
                abs($deg),
                ($deg > 0 ? 'above' : 'below'),
            );
            if ($p->{moon}->{set} < $p->{moon}->{rise}) {
                $say .= $tts->duration($p->{moon}->{set} - time()) . ' until moonset.';
            } else {
                $say .= $tts->duration($p->{moon}->{rise} - time()) . ' until moonrise.';
            }
            say($say);
        }
    }
}

sub say_environment {
    use Cochrane::Store::Pressure;
    use Cochrane::Store::Position;

    my $say = '';
    if (my $p = Cochrane::Store::Pressure->last) {
        if ($p->{temperature}) {
            $say .= sprintf("temperature %.0f", $p->{temperature});
        }
        if ($p->{humidity}) {
            use Physics::Psychrometry;

            my $e = Physics::Psychrometry::dbrh2e($p->{temperature}, $p->{humidity} / 100);
            my $dp = Physics::Psychrometry::e2dp($e);
            $say .= sprintf("; dew point %.0f", $dp);
        }
        if ($p->{pressure}) {
            $say .= sprintf("; Q N E %.0f", $p->{pressure} / 100);
            #if (my $pos = Cochrane::Store::Position->last) {
            #    if ($pos->{alt}) {
            #        $say .= sprintf('; Q N H %.0f.', ($p->{pressure} + $pos->{alt} * 12.2) / 100);
            #    }
            #}
        }
        if (length($say) > 0) {
            say($say);
        }
    }
}

sub say_humidity {
    say_environment();
}

sub say_position {
    eval {
        my $p = Cochrane::Input::HTTP->get_json(POSITION());
        if ($p) {
            my $ago = time() - $p->{time};
            warn $ago;
            my $say = 'Position: '.$self->{tts}->position($p->{lat}, $p->{lng}, $p->{alt})."\n".$self->{tts}->duration($ago).' ago';
            say($say);
        }
    };
    warn $@ if $@;
}
sub say_pressure {
    say_environment();
}

sub say_temperature {
    say_environment();
}

sub say_sun {
    if (my $p = Cochrane::Store::Position->last) {
        if ($p->sun) {

            my $say = 'Sun: ';
            use Math::Trig qw//;
            my $deg = Math::Trig::rad2deg($p->{sun}->{el});
            $say .= sprintf(
                "%.0f degree %s the horizon. ",
                abs($deg),
                ($deg > 0 ? 'above' : 'below'),
            );
            if ($p->{sun}->{set} < $p->{sun}->{rise}) {
                $say .= $tts->duration($p->{sun}->{set} - time()) . ' until sunset.';
            } else {
                $say .= $tts->duration($p->{sun}->{rise} - time()) . ' until sunrise.';
            }
            say($say);
        }
    }
}
