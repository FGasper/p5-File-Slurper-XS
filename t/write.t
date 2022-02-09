#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use blib;
use File::Slurper::XS;

use File::Temp;

my $dir = File::Temp::tempdir( CLEANUP => 1 );

my $ok = File::Slurper::XS::overwrite_binary("$dir/hello", "wawawa");
die "write failed: $!" if !$ok;

open my $rfh, '<', "$dir/hello";
is( (stat $rfh)[2] & 0777, 0600, 'permissions as expected' );
my $wrote = do { local $/; <$rfh> };

is( $wrote, 'wawawa', 'content OK' );

done_testing();
