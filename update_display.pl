#!/usr/bin/perl
use FindBin;
chdir "${FindBin::Bin}";
use lib "${FindBin::Bin}/lib";

use Cochrane::Store;
use Data::Dumper;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;

use POSIX qw//;
$ENV{TZ} = 'UTC';
POSIX::tzset();

use Time::HiRes qw//;

use strict;
use warnings;

use constant {
    FILES => {
        'position.jpg' => 'http://localhost:8081/position?height=1080&width=1920',
        #'map02.jpg' => 'http://localhost:8081/map?zoom=2&height=1080&width=1920',
        #'map02.jpg' => 'http://localhost:8081/map?zoom=3&height=1080&width=1920',
        #'map04.jpg' => 'http://localhost:8081/map?zoom=4&height=1080&width=1920',
        #'map05.jpg' => 'http://localhost:8081/map?zoom=5&height=1080&width=1920',
        #'map06.jpg' => 'http://localhost:8081/map?zoom=6&height=1080&width=1920',
        #'map07.jpg' => 'http://localhost:8081/map?zoom=7&height=1080&width=1920',
        #'map08.jpg' => 'http://localhost:8081/map?zoom=8&height=1080&width=1920',
        #'map09.jpg' => 'http://localhost:8081/map?zoom=9&height=1080&width=1920',
        #'map10.jpg' => 'http://localhost:8081/map?zoom=10&height=1080&width=1920',
        #'map11.jpg' => 'http://localhost:8081/map?zoom=11&height=1080&width=1920',
        #'map12.jpg' => 'http://localhost:8081/map?zoom=12&height=1080&width=1920',
        #'map13.jpg' => 'http://localhost:8081/map?zoom=13&height=1080&width=1920',
        #'map14.jpg' => 'http://localhost:8081/map?zoom=14&height=1080&width=1920',
        'map15.jpg' => 'http://localhost:8081/map?zoom=15&height=1080&width=1920',
        #'map16.jpg' => 'http://localhost:8081/map?zoom=16&height=1080&width=1920',
        'map17.jpg' => 'http://localhost:8081/map?zoom=17&height=1080&width=1920',
        #'map18.jpg' => 'http://localhost:8081/map?zoom=18&height=1080&width=1920',
        'pressure.jpg' => 'http://localhost:8081/pressure?height=1080&width=1920',
        'temperature.jpg' => 'http://localhost:8081/temperature?height=1080&width=1920',
        'power.jpg' => 'http://localhost:8081/power?height=1080&width=1920',
    },
};

while (1) {
    for my $file (sort(keys(%{FILES()}))) {
        my $request = FILES()->{$file};
        my $response = $ua->get($request);
        if ($response->is_success) {
            Cochrane::Store->write_file(Cochrane::Store::PATH_RUN.'/display/'.$file, $response->decoded_content);
        }
        if (-f Cochrane::Store::PATH_RUN.'/display/'.$file) {
            system 'xloadimage', '-display', ':0.0', '-onroot', Cochrane::Store::PATH_RUN.'/display/'.$file;
        }
        Time::HiRes::sleep(6);
    }
}
