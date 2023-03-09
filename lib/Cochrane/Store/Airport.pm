package Cochrane::Store::Airport;

use Cochrane::Input::HTTP;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    PREFIX => 'airports',
};

my $all;
sub get_all {
    my ($self) = @_;

    unless ($all) {
        $all = $self->read_json($self->PATH_CACHE().'/'.$self->PREFIX().'/airports.json') || [];
    }
    return @{$all};
}

sub import_csv {
    my ($self) = @_;

    my $data = $self->read_file('airports.csv');
    $data = [ split(/\n/, $data) ];
    warn scalar(@{$data});
    delete $data->[0];
    for (@{$data}) {
        # "id","ident","type","name","latitude_deg","longitude_deg","elevation_ft","continent","iso_country","iso_region","municipality","scheduled_service","gps_code","iata_code","local_code","home_link","wikipedia_link","keywords"
        # 4434,"LOWW","large_airport","Vienna International Airport",48.110298156738,16.569700241089,600,"EU","AT","AT-9","Vienna","yes","LOWW","VIE",,"http://www.viennaairport.com/en/","http://en.wikipedia.org/wiki/Vienna_International_Airport",
        # 2199,"EDBM","medium_airport","Magdeburg ""City"" Airport",52.073612,11.626389,259,"EU","DE","DE-ST","Magdeburg","no","EDBM","ZMG",,"http://www.edbm.de","https://en.wikipedia.org/wiki/Magdeburg%E2%80%93Cochstedt_Airport",
        if (/^\d+,"([^"]+)","([^"]+)","(.+)",(-?\d+\.?\d*),(-?\d+\.?\d*),(-?\d*),"[^"]+","([^"]+)","[^"]+","?[^"]*"?,"?[^"]*"?,"?([^"]*)"?,"?([^"]*)"?,"?[^"]*"?,"?([^"]*)"?,"?([^"]*)"?,"?.*"?$/) {
            $_ = {
                ident => $1,
                type => $2,
                name => $3,
                latitude => $4,
                longitude => $5,
                elevation => $6,
                country => $7,
                gps_code => $8,
                iata_code => $9,
                url => $10,
                wikipedia => $11,
            };
        } else {
            warn $_;
        }
    }
    $self->write_json($self->PATH_CACHE().'/'.$self->PREFIX().'/airports.json', $data);
}

sub update {
    my ($self) = @_;

    my $request = 'http://ourairports.com/data/airports.csv';
    print "fetching $request\n";
    my $response = Cochrane::Input::HTTP->get($request);
    $self->write_file($self->PATH_CACHE().'/'.$self->PREFIX().'/airports.csv', $response);
}

1;
