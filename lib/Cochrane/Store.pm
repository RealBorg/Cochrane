package Cochrane::Store;

use strict;
use warnings;

use File::Path qw//;
use File::Spec qw//;
use IO::Dir;
use IO::File;
use POSIX qw//;
use Time::HiRes qw//;

use Cochrane::JSON;

use constant {
    PATH_CACHE => '/var/cache/cochrane',
    PATH_RUN => '/var/run/shm/cochrane',
};

sub json {
    my ($self) = @_;

    return Cochrane::JSON->encode($self);
}

sub kill_files {
    my ($self, @files) = @_;

    return unlink(@files);
}

sub list_files {
    my ($self, $dir) = @_;

    my @result;
    if (my $fh = IO::Dir->new($dir)) {
        @result = $fh->read();
        @result = grep(!/^\./, @result);
        @result = sort(@result);
    }
    return @result;
}

sub read_csv {
    my ($self, $file) = @_;

    my $result;
    if (my $fh = IO::File->new($file, O_RDONLY)) {
        use Text::CSV;
        my $csv = Text::CSV->new;
        $result = $csv->getline_all($fh);
    }
    return $result;
}

sub read_file {
    my ($self, $file) = @_;

    my $stat = [ stat($file) ];
    return undef unless $stat;
    my $result;
    #use IO::File;
    if (my $fh = IO::File->new($file, O_RDONLY)) {
        $fh->sysread($result, $stat->[7]);
    }
    return $result;
}

sub read_json {
    my ($self, $file) = @_;

    my $result = $self->read_file($file);
    eval {
        $result = Cochrane::JSON->decode($result) if $result;
    };
    if ($@) {
        warn $@;
        print $result;
        $result = undef;
    }
    return $result;
}

sub write_file {
    my ($self, $file, $data) = @_;

    my ($volume, $path, $base) = File::Spec->splitpath($file);
    eval {
        File::Path::make_path($path);
    };
    warn $@ if $@;
    unlink "$file.tmp" if -f "$file.tmp";
    if (my $fh = IO::File->new("$file.tmp", O_CREAT | O_EXCL | O_WRONLY)) {
        $fh->syswrite($data);
        $fh->close;
        rename "$file.tmp", $file;
    } else {
        warn "failed to open $file: $!";
    }
}

sub write_json {
    my ($self, $file, $data) = @_;

    return $self->write_file($file, Cochrane::JSON->encode($data));
}

1;
