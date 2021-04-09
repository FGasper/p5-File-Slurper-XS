package File::Slurper::XS;

use strict;
use warnings;

use XSLoader ();

our $VERSION;

BEGIN {
    $VERSION = '0.01_01';
    XSLoader::load();
}

1;
