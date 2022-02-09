package File::Slurper::XS;

use strict;
use warnings;

use XSLoader ();

our $VERSION;

BEGIN {
    $VERSION = '0.01_01';
    XSLoader::load( __PACKAGE__, $VERSION );
}

=encoding utf-8

=head1 NAME

File::Slurper::XS - Fast file slurping

=head1 SYNOPSIS

    my $bytes = File::Slurper::XS::read_binary('/path/to/file') // do {
        die "Failed to read: $!";
    };

    File::Slurper::XS::overwrite_binary('/path/to/file', 'the content') or do {
        die "Failed to overwrite: $!";
    };

=head1 DESCRIPTION

This module reads and writes files via XS for maximum speed.

=head1 CHARACTER ENCODING

All filesystem paths are to be given as I<byte> strings, not character
strings.

Note that Perl, owing to longstanding bugs in its Unicode
implementation, oftentimes will “do what you mean” if you give
it a filesystem path as a character string. (See L<Sys::Binmode> for
more details and a fix.) This module does B<not> do that, so if you
have a non-ASCII filesystem path that’s a character string, you B<MUST>
encode it to bytes before giving it to this module, or you’ll either get
an exception or (worse) activity on the wrong filesystem path.

=head1 FUNCTIONS

=head2 $bytes = read_binary( $PATH )

Reads the file at $PATH and returns its contents as a byte string.

This indicates failure the same way as Perl’s built-ins: undef is returned,
and the error is in Perl’s C<$!>.

=head2 overwrite_binary( $PATH, $CONTENT [, $MODE] )

Writes $CONTENT (a byte string) to a temporary file I<alongside> $PATH, then
renames the temp file over the original. This clobbers any file that might
already exist at $PATH.

$MODE defaults to 0600.

(Error handling works the same as with C<read_binary()>.)

Why not just a simple open-then-write on $PATH itself? Because:

=over

=item * If the replacement $CONTENT exceeds the original size, and the
replacement causes a quota excess, then you’ll be unable to write the
full $CONTENT. But you’ll have written I<part> of it, which probably
means you now have a corrupt file.

=item * If $CONTENT is written in pieces (which can happen if, e.g., the
filesystem isn’t local), then your file will be corrupt until you’ve
written out the full $CONTENT.

=back

The write-then-rename approach does have a few liabilities of its own:

=over

=item * It assumes you have write permission on the directory.

=item * If $PATH already exists, then you need enough disk space to
store the old content B<and> $CONTENT.

=item * It’s a bit slower.

=back

B<ADDITIONAL NOTE:> This function ignores SIGXFSZ on platforms where it
exists.

=head1 BENCHMARKS

The smaller the file, the bigger the speed increase this module yields
over pure-Perl slurping. The amount of increase will depend on your
local system. See F<benchmark_slurp.pl> in the distribution.

=cut

sub _no_xfsz_overwrite_binary {
    local $SIG{'XFSZ'} = 'IGNORE';
    &_xs_overwrite_binary;
}

BEGIN {
    *overwrite_binary = exists($SIG{'XFSZ'}) ? *_no_xfsz_overwrite_binary : *_xs_overwrite_binary;
}

1;
