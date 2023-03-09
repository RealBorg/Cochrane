package Cochrane::Store::Object;

use Cochrane::JSON;

use POSIX qw//;
use Time::HiRes qw//;

use parent 'Cochrane::Store';

use strict;
use warnings;

use overload '""' => 'stringify';

sub cleanup {
    my ($self) = @_;

    if (! -d $self->PATH_RUN()) {
        warn "Skipping ".$self->PATH_RUN();
        return;
    }
    my $end = [ gmtime() ];
    $end->[0] = 0;
    $end->[1] = 0;
    $end = POSIX::mktime(@{$end});

    my $data;
    FILE: for my $file ( $self->list_files($self->PATH_RUN.'/'.$self->PREFIX) ) {
        next FILE unless $file =~ /^\d+$/;
        next FILE unless $file < $end;
        my $key = [ gmtime($file) ];
        $key->[0] = 0;
        $key->[1] = 0;
        $key = POSIX::mktime(@{$key});
        $file = $self->PATH_RUN.'/'.$self->PREFIX.'/'.$file;
        next FILE unless -f $file;
        print "$key < $file\n";
        if (my $s = $self->read_json($file)) {
            $data->{$key}->{$s->{time}} = $s;
            push @{$data->{$key}->{unlink}}, $file;
        }
    }
    for my $key (sort(keys(%{$data}))) {
        my $value = $data->{$key};
        my $file = $self->PATH_CACHE() . '/' . $self->PREFIX() . '/' . $key;
        if (-f $file) {
            my $sa = $self->read_json($file);
            for my $s (@{$sa}) {
                $value->{$s->{time}} = $s;
            }
        }
        my $unlink = delete($value->{unlink});
        my $json = [ @{$value}{sort(keys(%{$value}))} ];
        $self->write_json($file, $json);
        $self->kill_files(@{$unlink});
    }
}

sub cleanup2 {
    my ($self) = @_;

    my $end = [ gmtime() ];
    $end->[0] = 0;
    $end->[1] = 0;
    $end->[2] = 0;
    $end = POSIX::mktime(@{$end});

    my $data;
    FILE: for my $file ( $self->list_files($self->PATH_CACHE.'/'.$self->PREFIX) ) {
        next FILE unless $file =~ /^\d+$/;
        next FILE unless $file < $end;
        my $key = [ gmtime($file) ];
        $key->[0] = 0;
        $key->[1] = 0;
        $key->[2] = 0;
        $key = POSIX::mktime(@{$key});
        next FILE if $key == $file;
        $file = $self->PATH_CACHE.'/'.$self->PREFIX.'/'.$file;
        next FILE unless -f $file;
        push @{$data->{$key}->{files}}, $file;
    }
    for my $key (sort(keys(%{$data}))) {
        my $value = $data->{$key};

        my $file = $self->PATH_CACHE() . '/' . $self->PREFIX() . '/' . $key;
        if (my $sa = $self->read_json($file)) {
            for my $s (@{$sa}) {
                $value->{$s->{time}} = $s;
            }
        }
        my $files = delete($value->{files});
        for my $in (@{$files}) {
            print "$key < $in\n";
            my $sa = $self->read_json($in);
            SAMPLE: for my $s (@{$sa}) {
                next SAMPLE unless $s->{time};
                $value->{$s->{time}} = $s;
            }
        }
        my $json = [ @{$value}{sort(keys(%{$value}))} ];
        $self->write_json($file, $json);
        $self->kill_files(@{$files});
    }
}

sub get {
    my ($self, $file) = @_;

    my $data;
    $file = $self->PREFIX.'/'.$file;
    if (-f $self->PATH_CACHE().'/'.$file) {
        $data = $self->read_json($self->PATH_CACHE().'/'.$file);
    } elsif (-f $self->PATH_RUN().'/'.$file) {
        $data = $self->read_json($self->PATH_RUN().'/'.$file);
    }
    return $data;
}

sub json {
    my ($self) = @_;

    return Cochrane::JSON->encode({%{$self}});
}

sub last {
    my ($self) = @_;

    my $last;
    my @files = $self->list_files($self->PATH_RUN().'/'.$self->PREFIX);
    if (scalar(@files) > 0) {
        $last = pop(@files);
        $last = $self->get($last);
    } else {
        @files = $self->list_files($self->PATH_CACHE().'/'.$self->PREFIX);
        if (scalar(@files) > 0) {
            $last = pop(@files);
            $last = $self->get($last);
            $last = pop(@{$last});
        }
    }
    $last = bless($last, $self) if $last;
    return $last;
}

sub list {
    my ($self) = @_;

    my @result;
    {
        my $dir = $self->PATH_CACHE().'/'.$self->PREFIX();
        push @result, $self->list_files($dir);
    }
    {
        my $dir = $self->PATH_RUN().'/'.$self->PREFIX();
        push @result, $self->list_files($dir);
    }
    return @result;
}

sub new {
    my ($self, $data) = @_;

    $self->write_json($self->PATH_RUN().'/'.$self->PREFIX.'/'.sprintf("%.0f", $data->{time}), $data);
    return bless($data, $self);
}

sub stringify {
    my ($self) = @_;

    return $self->json();
}

1;
