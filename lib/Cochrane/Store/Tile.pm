package Cochrane::Store::Tile;

use Cochrane::Input::HTTP;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    PREFIX => 'tiles',
};

sub get {
    my ($self, $x, $y, $zoom) = @_;

    my $tile = "$zoom/$x/$y.png";
    my $file = $self->PATH_CACHE."/tiles/$tile";
    my $result = $self->read_file($file);
    unless ($result) {
        my $request = "http://tile.openstreetmap.org/$tile";
        print "fetching $request\n";
        $result = Cochrane::Input::HTTP->get($request);
        $self->write_file($file, $result);
    }
    return $result;
}

1;
