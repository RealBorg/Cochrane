package Device::PM::SDS011;

use IO::File;
use Time::HiRes qw//;

use strict;
use warnings;

use constant {
};

sub new {
    my ($self, $device) = @_;

    die unless $device;
    system 'stty', '-F', $device, '9600', 'raw';
    my $fh = IO::File->new($device, O_RDONLY);
    die unless $fh;
    $self = {
        buf => '',
        device => $device,
        fh => $fh,
    };
    return bless($self);
}

sub get_data {
    my ($self) = @_;

    my $result;
    C: while (defined(my $c = $self->{fh}->getc())) {
        $self->{buf} .= $c;
        if ($self->{buf} =~ s/.*\x{aa}\x{c0}(.)(.)(.)(.)...\x{ab}//) {
            $result = {
                pm2 => ( unpack('C', $1) + unpack('C', $2) * 256 ) / 10,
                pm10 => ( unpack('C', $3) + unpack('C', $4) * 256) / 10,
                time => time(),
            };
            last C;
        }
    }
    return $result;
}


1;
