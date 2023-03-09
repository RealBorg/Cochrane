package Cochrane::Store::GPS;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    PREFIX => 'gps',
};

sub stringify {
    my ($self) = @_;

    my $result = sprintf("offset: %.3f count: %i\n", $self->{offset}, $self->{count});
    $result .= "sky: ";
    for my $key (sort(keys(%{$self->{sky}}))) {
        my $sat = $self->{sky}->{$key};
        $result .= sprintf("%s:%s:%s:%s ", $key, $sat->{az}, $sat->{el}, $sat->{snr});
    }
    return $result;
}


1;
