package Cochrane::Store::TAF;

use Cochrane::Input::HTTP;

use parent 'Cochrane::Store::METAR';

use strict;
use warnings;

use constant {
    PREFIX => 'taf',
    URL => "https://tgftp.nws.noaa.gov/data/forecasts/taf/stations/%s.TXT",
};

1;
