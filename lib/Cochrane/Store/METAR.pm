package Cochrane::Store::METAR;

use Cochrane::Input::HTTP;
use Cochrane::Store;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    PATH_RUN => Cochrane::Store::PATH_CACHE(),
    PREFIX => 'metar',
    URL => "https://tgftp.nws.noaa.gov/data/observations/metar/stations/%s.TXT",
};

sub latest {
    my ($self, $location) = @_;

    $location = 'LOWW' unless $location;
    my $result;
    eval {
    	my $request = sprintf($self->URL(), $location);
    	$result->{text} = Cochrane::Input::HTTP->get($request);
    	$result->{time} = time();
    	$result->{location} = $location;
    	if ($result->{text} =~ s/^(\d\d\d\d)\/(\d\d)\/(\d\d) (\d\d):(\d\d)//) {
        	$result->{time} = POSIX::mktime(0, $5, $4, $3, $2 - 1, $1 - 1900);
    	}
    	$result = $self->new($result);
    };
    if ($@) {
        warn $@;
        $result = $self->last();
    }
    return $result;
}

sub decode {
    my ($self) = @_;
    
    my @text = split(/ +/, $self->{text});
    my $location = $self->{location};
    foreach (@text) {
        if (/$location$/) {
            s/(\w)(\w)(\w)(\w)/$1.$2.$3.$4.\r\n/;
        } elsif (/^(\d\d)(\d\d)(\d\d)Z/) {
            $_ = "$2$3";
        } elsif (/^(\d\d\d\d)$/) {
            $_ = "visibility ";
            if ($1 == 9999) {
                $_ .= "one zero kilometers or more";
            } else {
                if (int($1 / 1000) > 0) {
                    $_ .= sprintf("%i thousand", int($1 / 1000));
                }
                if ($1 % 1000 > 0) {
                    $_ .= sprintf("%i hundred", $1 % 1000 / 100);
                }
                $_ .= " meters";
            }
        } elsif (/^(\d\d\d)(\d\d)(?:G(\d\d))?KT/) {
            $_ = sprintf("wind %i degrees %i", $1, $2);
            if ($3) {
                $_ .= sprintf(" gusting %i", $3);
            }
            $_ .= " knots";
        } elsif (s/^BECMG$/becoming/) {
        } elsif (s/^CAVOK$/cav ok/) {
        } elsif (/(\d\d\d)V(\d\d\d)/) {
            $_ = sprintf("wind varying between %i and %i", $1, $2);
        } elsif (s/(\d\d\d\d)\/(\d\d\d\d)/from $1 till $2/) {
        } elsif (s/^Q(\d\d\d\d)/Q N H $1/) {
        } elsif (/^(M?\d\d)\/(M?\d\d)$/) {
            my $t = $1;
            my $d = $2;
            $t =~ s/M/-/;
            $d =~ s/M/-/;
            $_ = sprintf("temperature %i.\r\ndew point %i", $t, $d);
        } elsif (s/^NOSIG$/no sig/) {
        } elsif (s/^NSW$/no significant weather/) {
        } elsif (/^(FEW|SCT|BKN|OVC)(\d\d\d)/) {
            if ($1 eq 'FEW') {
                $_ = "few ";
            } elsif ($1 eq 'SCT') {
                $_ = "scattered ";
            } elsif ($1 eq 'BKN') {
                $_ = "broken ";
            } elsif ($1 eq 'OVC') {
                $_ = "overcast ";
            }

            if ($2 > 10) {
                $_ .= sprintf("%i thousand ", $2 / 10);
            }
            if ($2 % 10 > 0) {
                $_ .= sprintf("%i hundred ", $2 % 10);
            }
            if ($2 == 0) {
                $_ .= "0";
            }
            $_ .= "feet";
        } elsif (/^([+-])?(BC|BR|DZ|FG|FZ|HA|RA|RE|SH|SN|TS)+/) {
            s/^[+]/heavy/;
            s/^[-]/light/;
            s/BC/ patches of /;
            s/BR/ mist /;
            s/DZ/ drizzle /;
            s/FG/ fog /;
            s/FZ/ freezing /;
            s/HA/ hail /;
            s/RA/ rain /;
            s/RE/ recent /;
            s/SH/ showers of /;
            s/SN/ snow /;
            s/TS/ thunderstorm /;
            s/VC/ vicinity /;
            s/ +/ /g;
        } elsif (s/^FM/from /) {
        } elsif (s/^PROB(\d\d)/probability $1/) {
        } elsif (s/TAF$/T A F/) {
        } elsif (s/^TEMPO/temporary/) {
        } elsif (/^TX(M?\d\d)\/(\d\d)(\d\d)Z$/) {
            my $t = $1;
            my $d = "$2$3";
            $t =~ s/M/-/;
            $_ = sprintf("maximum temperature %i at %s", $t, $d);
        } elsif (/^TN(M?\d\d)\/(\d\d)(\d\d)Z$/) {
            my $t = $1;
            my $d = "$2$3";
            $t =~ s/M/-/;
            $_ = sprintf("minimum temperature %i at %s", $t, $d);
        } elsif (/^VV(\d\d\d)/) {
            $_ = sprintf("vertical visibility %i hundred feet", $1);
        } elsif (/^VRB(\d\d)KT/) {
            $_ = sprintf("wind variable %i knots", $1);
        }
    }
	$_ = join(".\r\n", @text);
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

sub ogg {
    my ($self) = @_;

    my $fn = Cochrane::Store->PATH_RUN() . '/' . $self->PREFIX() . '/' . $self->{time} . '_' . $self->{location} . '.ogg';
    my $result = $self->read_file($fn);
    unless ($result) {
        use Cochrane::Output::TTS;
        $result = Cochrane::Output::TTS->ogg($self->decode);
        $self->write_file($fn, $result);
    }
    return $result;
}

sub qnh {
    my ($self) = @_;
    
    unless ($self->{qnh}) {
        if ($self->{text} =~ /Q(\d\d\d\d)/) {
            $self->{qnh} = $1;
        }
    }
    return $self->{qnh};
}

1;
