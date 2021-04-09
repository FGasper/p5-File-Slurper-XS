#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use blib;

use File::Slurper::XS;

use Benchmark ('cmpthese');
use File::Slurper;

use File::Temp;

my $dir = File::Temp::tempdir( CLEANUP => 1 );

for my $size ( 0, 100, 10_000, 100_000, 1_000_000, 10_000_000 ) {
    my $path = "$dir/$size";

    open my $wfh, '>', $path;
    print {$wfh} _create_dummy_random($size);
    close $wfh;

    print "$size bytes …\n";

    cmpthese(
        -1,
        {
            slurp => sub { File::Slurper::read_binary($path) },
            xs => sub { File::Slurper::XS::read_binary($path) },
        },
    );
}

sub _create_dummy_random {
    my $len = shift;

    my $str = q<>;
    while (length $str < $len) {
        $str .= rand;
    }

    substr($str, $len) = q<>;

    return $str;
}
