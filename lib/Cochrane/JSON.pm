package Cochrane::JSON;

use strict;
use warnings;

use JSON qw//;
my $json = JSON->new->canonical->pretty->utf8;

sub decode {
    my ($self, $data) = @_;

    my $result = $json->decode($data);
    return $result;
}

sub encode {
    my ($self, $data) = @_;

    my $result = $json->encode($data);
    return $result;
}

1;
