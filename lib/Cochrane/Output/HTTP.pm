package Cochrane::Output::HTTP;

use Cochrane::Store;
use HTTP::Date;
use HTTP::Response;
use Time::HiRes;

use parent 'HTTP::Daemon';

use bytes;
use strict;
use warnings;

my $sites;

sub new {
    my ($class, @args) = @_;

    my $self = $class->SUPER::new(
        LocalPort => 10080,
        ReuseAddr => 1,
        @args,
    );
}

sub run {
    my ($self) = @_;

    $ENV{TZ} = 'UTC';
    POSIX::tzset();
    POSIX::nice(10);

    load_filelist();
    $SIG{HUP} = sub {
        load_filelist();
    };
    $SIG{CHLD} = 'IGNORE';
    STDERR->print($self->url . "\n");
    while (my $client = $self->accept) {
        my $pid = fork();
        if ($pid > 0) {
            # parent
        } elsif ($pid == 0) {
            $self->client($client);
            exit 0;
        } else {
            warn "failed to fork: $!";
        }
    }
}

sub load_filelist {
    my $new_sites;
    for my $site (glob('/var/www/*')) {
        next unless -d $site;
        next unless -f "$site/files.txt";
        my $f = Cochrane::Store->read_file("$site/files.txt");
        next unless $f;
        my $files;
        for (split(/\n/, $f)) {
            $files->{"/$_"} = "$site/$_";
        }
        $site =~ s/\/var\/www\///;
        $new_sites->{$site} = $files;
    }
    $sites = $new_sites;
}

sub client {
    my ($self, $client) = @_;

    $SIG{PIPE} = sub {
        exit 0;
    };
    REQUEST: while (my $request = $client->get_request) {
        my $time = Time::HiRes::time();
        #$client->force_last_request;
        my $response = HTTP::Response->new(200, "OK");
        $response->header(Date => HTTP::Date::time2str(int($time)));

        my $path = $request->uri->path;
        $path = "/index.html" if $path eq "/";
        my $host = $request->header('Host') || '';
        my $file;
        my $params = { $request->uri->query_form };
        $params->{path} = $request->uri->path;
        if ($params->{refresh}) {
            $response->header(Refresh => $params->{refresh});
        }
        if ($path =~ /^\/acceleration/) {
            use Cochrane::Graph::Acceleration;
            my $g = Cochrane::Graph::Acceleration->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/attitude/) {
            use Cochrane::Graph::Attitude;
            my $g = Cochrane::Graph::Attitude->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/humidity\/data/) {
            use Cochrane::Store::Humidity;
            my $o = Cochrane::Store::Humidity->last();
            $o = $o->json();
            $response->header('Content-Length' => length($o));
            $response->header('Content-Type' => 'text/json');
            $response->content($o);
        } elsif ($path =~ /^\/humidity/) {
            use Cochrane::Graph::Humidity;
            my $g = Cochrane::Graph::Humidity->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/light/) {
            use Cochrane::Graph::Light;
            my $g = Cochrane::Graph::Light->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/magfield/) {
            use Cochrane::Graph::MagField;
            my $g = Cochrane::Graph::MagField->new($params);
            if ($g) {
                $g = $g->jpeg(100);
                $response->header('Content-Length' => length($g));
                $response->header('Content-Type' => 'image/jpeg');
                $response->content($g);
            } else {
                $response->code(503);
                $response->message('TEMPORARILY NOT AVAILABLE');
            }
        } elsif ($path =~ /^\/magfluc/) {
            use Cochrane::Graph::MagFluc;
            my $g = Cochrane::Graph::MagFluc->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/map/) {
            use Cochrane::Graph::Map;
            my $g = Cochrane::Graph::Map->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/metar/) {
            use Cochrane::Store::METAR;
            if (my $metar = Cochrane::Store::METAR->latest($params->{location} || 'LOWW')) {
                $params->{format} ||= 'txt';
                if ($params->{format} eq 'ogg') {
                    $metar = $metar->ogg();
                    $response->header('Content-Type' => 'audio/ogg');
                } elsif ($params->{format} eq 'raw') {
                    $metar = $metar->{text};
                    $response->header('Content-Type' => 'text/plain');
                } else {
                    $metar = $metar->decode();
                    $response->header('Content-Type' => 'text/plain');
                }
                $response->header('Content-Length' => length($metar));
                $response->content($metar);
            }
        } elsif ($path =~ /^\/position\/data/) {
            my $o = Cochrane::Store::Position->last;
            $o = $o->json();
            $response->header('Content-Length' => length($o));
            $response->header('Content-Type' => 'text/json');
            $response->content($o);
        } elsif ($path =~ /^\/position/) {
            use Cochrane::Graph::Position;
            my $g = Cochrane::Graph::Position->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/power\/data/) {
            use Cochrane::Store::Power;
            my $o = Cochrane::Store::Power->last();
            $o = $o->json();
            $response->header('Content-Length' => length($o));
            $response->header('Content-Type' => 'text/json');
            $response->content($o);
        } elsif ($path =~ /^\/power/) {
            use Cochrane::Graph::Power;
            my $g = Cochrane::Graph::Power->new($params);
            if ($g) {
                $g = $g->jpeg(100);
                $response->header('Content-Length' => length($g));
                $response->header('Content-Type' => 'image/jpeg');
                $response->content($g);
            } else {
                $response->code(503);
                $response->message('TEMPORARILY NOT AVAILABLE');
            }
        } elsif ($path =~ /^\/pressure/) {
            use Cochrane::Graph::Pressure;
            my $g = Cochrane::Graph::Pressure->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/rotation/) {
            use Cochrane::Graph::Rotation;
            my $g = Cochrane::Graph::Rotation->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/taf/) {
            use Cochrane::Store::TAF;
            if (my $taf = Cochrane::Store::TAF->latest($params->{location} || 'LOWW')) {
                $params->{format} ||= 'txt';
                if ($params->{format} eq 'ogg') {
                    $taf = $taf->ogg();
                    $response->header('Content-Type' => 'audio/ogg');
                } elsif ($params->{format} eq 'raw') {
                    $taf = $taf->{text};
                    $response->header('Content-Type' => 'text/plain');
                } else {
                    $taf = $taf->decode();
                    $response->header('Content-Type' => 'text/plain');
                }
                $response->header('Content-Length' => length($taf));
                $response->content($taf);
            }
        } elsif ($path =~ /^\/temperature\/data/) {
            use Cochrane::Store::Temperature;
            my $o = Cochrane::Store::Temperature->last();
            $o = $o->json();
            $response->header('Content-Length' => length($o));
            $response->header('Content-Type' => 'text/json');
            $response->content($o);
        } elsif ($path =~ /^\/temperature/) {
            use Cochrane::Graph::Temperature;
            my $g = Cochrane::Graph::Temperature->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/vibration/) {
            use Cochrane::Graph::Vibration;
            my $g = Cochrane::Graph::Vibration->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } elsif ($path =~ /^\/warming/) {
            use Cochrane::Graph::Warming;
            my $g = Cochrane::Graph::Warming->new($params);
            $g = $g->jpeg(100);
            $response->header('Content-Length' => length($g));
            $response->header('Content-Type' => 'image/jpeg');
            $response->content($g);
        } else {
            for my $site (keys(%{$sites})) {
                if (substr($host, -length($site)) eq $site) {
                    $file = $sites->{$site}->{$path};
                }
            }
            unless ($file) {
                $file = $sites->{'riseflyorbit.org'}->{$path};
            }
            if ($file && -f $file) {
                if ($file =~ /\.html$/) {
                    $response->header('Content-Type' => 'text/html');
                } elsif ($file =~ /\.jpg$/) {
                    $response->header('Content-Type' => 'image/jpeg');
                } elsif ($file =~ /\.mp4$/) {
                    $response->header('Content-Type' => 'video/mp4');
                } elsif ($file =~ /\.(pl|pm)$/) {
                    $response->header('Content-Type' => 'text/plain');
                } elsif ($file =~ /\.png$/) {
                    $response->header('Content-Type' => 'image/png');
                }
                my $data = Cochrane::Store->read_file($file);
                $response->header('Content-Length' => length($data));
                $response->content($data);
            } else {
                $response->code(404);
                $response->message("NOT FOUND");
            }
        }
        unless ($response) {
            $response = HTTP::Response->new(503, "TEMPORARILY NOT AVAILABLE");
        }
        $client->send_response($response);
        STDOUT->printf("%s %.3fs %s %s\n",
            POSIX::strftime("%Y-%m-%dT%H:%M:%S", localtime($time)),
            Time::HiRes::time() - $time,
            $client->peerhost, 
            "$host$path",
            $file,
        );
    }
    $client->close;
}

sub product_tokens {
    my ($self) = @_;
    return __PACKAGE__;
}

1;
