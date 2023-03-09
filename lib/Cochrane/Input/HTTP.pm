package Cochrane::Input::HTTP;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new(
    agent => __PACKAGE__,
    timeout => 6,
);

use Cochrane::JSON;

use strict;
use warnings;

sub get {
    my ($self, $request) = @_;

    my $response = $ua->get($request);
    die $response->status_line unless $response->is_success;
    my $result = $response->decoded_content;
    return $result;
}

sub get_json {
    my ($self, $request) = @_;
    my $result = $self->get($request);
    $result = Cochrane::JSON->decode($result);
    return $result;
}

1;
