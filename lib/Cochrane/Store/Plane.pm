package Cochrane::Store::Plane;

use POSIX qw//;
use Time::HiRes qw//;

use parent 'Cochrane::Store::Object';

use strict;
use warnings;

use constant {
    PREFIX => 'planes',
};

sub cleanup {
    my ($self) = @_;

    my $ceil = Time::HiRes::time() - 60 * 60;
    for my $file ($self->list) {
        my $plane = $self->get($file);
        if ($plane->{seen} < $ceil) {
            if (my $oldplane = $self->read_json($self->PATH_CACHE().'/'.$self->PREFIX.'/'.$file)) {
                my @path;
                push @path, @{$oldplane->{path}} if $oldplane->{path};
                push @path, @{$plane->{path}} if $plane->{path};
                $plane = {
                    %{$oldplane},
                    %{$plane},
                    path => \@path,
                };
            }
            $self->write_json($self->PATH_CACHE().'/'.$self->PREFIX.'/'.$file, $plane);
            $self->kill_files($self->PATH_RUN().'/'.$self->PREFIX.'/'.$file);
        }
    }
}

sub get {
    my ($self, $file) = @_;

    return $self->read_json($self->PATH_RUN().'/'.$self->PREFIX.'/'.$file);
}

sub list {
    my ($self) = @_;

    return $self->list_files($self->PATH_RUN().'/'.$self->PREFIX);
}

sub new {
    my ($self, $data) = @_;

    return unless $data->{icao};
    $self->write_json($self->PATH_RUN().'/'.$self->PREFIX.'/'.$data->{icao}, $data);
    return bless($data, $self);
}

1;
