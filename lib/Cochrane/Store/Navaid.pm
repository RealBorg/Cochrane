package Cochrane::Store::Navaid;

use Cochrane::Input::HTTP;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    PREFIX => 'navaids',
};

my $all;
sub get_all {
    my ($self) = @_;

    unless ($all) {
        $all = $self->read_json($self->PATH_CACHE().'/'.$self->PREFIX().'/navaids.json') || [];
    }
    return @{$all};
}

sub import_csv {
    my ($self) = @_;

    use Text::CSV;

    my $data = $self->read_csv($self->PATH_CACHE().'/navaids.csv');
    delete $data->[0];
    for my $row (@{$data}) {
        # "id","filename","ident","name","type","frequency_khz","latitude_deg","longitude_deg","elevation_ft","iso_country","dme_frequency_khz","dme_channel","dme_latitude_deg","dme_longitude_deg","dme_elevation_ft","slaved_variation_deg","magnetic_variation_deg","usageType","power","associated_airport",
        $row = {
            id => $row->[0],
            filename => $row->[1],
            ident => $row->[2],
            name => $row->[3],
            type => $row->[4],
            frequency_khz => $row->[5],
            latitude => $row->[6],
            longitude => $row->[7],
            elevation => $row->[8],
            country => $row->[9],
            dme_frequency => $row->[10],
            dme_channel => $row->[11],
            dme_latitude => $row->[12],
            dme_longitude => $row->[13],
            dme_elevation => $row->[14],
            slaved_variation => $row->[15],
            magnetic_variation => $row->[16],
            usageType => $row->[17],
            power => $row->[18],
            associated_airport => $row->[19],
        };
    }
    $self->write_json($self->PATH_CACHE().'/'.$self->PREFIX().'/navaids.json', $data);
}

sub update {
    my ($self) = @_;

    my $request = 'http://ourairports.com/data/navaids.csv';
    print "fetching $request\n";
    my $response = Cochrane::Input::HTTP->get($request);
    $self->write_file($self->PATH_CACHE().'/'.$self->FILE(), $response);
}

1;
