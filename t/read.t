#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use blib;
use File::Slurper::XS;

use File::Temp;

my $dir = File::Temp::tempdir( CLEANUP => 1 );

for my $size ( 0, 100, 10_000, 100_000, 1_000_000 ) {
    my $path = "$dir/$size";

    open my $wfh, '>', $path;
    print {$wfh} _create_dummy_random($size);
    close $wfh;

    my $got = File::Slurper::XS::read_binary($path);

    my $perlgot = _perl_slurp($path);

    is($got, $perlgot, "$size bytes");
}

SKIP: {
    skip 'Skipping Linux tests on $^O' if $^O ne 'linux';

    my @paths = qw(/proc/self/status);

    for my $path (@paths) {
        my $got = File::Slurper::XS::read_binary($path);

        my $perlgot = _perl_slurp($path);

        is($got, $perlgot, $path);
    }
}

done_testing;

#----------------------------------------------------------------------

sub _perl_slurp {
    my $path = shift;

    open my $fh, '<', $path;
    local $/;
    return scalar <$fh>;
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
