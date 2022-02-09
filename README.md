# NAME

File::Slurper::XS - Fast file slurping

# SYNOPSIS

    my $bytes = File::Slurper::XS::read_binary('/path/to/file') // do {
        die "Failed to read: $!";
    };

    File::Slurper::XS::overwrite_binary('/path/to/file', 'the content') or do {
        die "Failed to overwrite: $!";
    };

# DESCRIPTION

This module reads and writes files via XS for maximum speed.

# CHARACTER ENCODING

All filesystem paths are to be given as _byte_ strings, not character
strings.

Note that Perl, owing to longstanding bugs in its Unicode
implementation, oftentimes will “do what you mean” if you give
it a filesystem path as a character string. (See [Sys::Binmode](https://metacpan.org/pod/Sys%3A%3ABinmode) for
more details and a fix.) This module does **not** do that, so if you
have a non-ASCII filesystem path that’s a character string, you **MUST**
encode it to bytes before giving it to this module, or you’ll either get
an exception or (worse) activity on the wrong filesystem path.

# FUNCTIONS

## $bytes = read\_binary( $PATH )

Reads the file at $PATH and returns its contents as a byte string.

This indicates failure the same way as Perl’s built-ins: undef is returned,
and the error is in Perl’s `$!`.

## overwrite\_binary( $PATH, $CONTENT \[, $MODE\] )

Writes $CONTENT (a byte string) to a temporary file _alongside_ $PATH, then
renames the temp file over the original. This clobbers any file that might
already exist at $PATH.

$MODE defaults to 0600.

(Error handling works the same as with `read_binary()`.)

Why not just a simple open-then-write on $PATH itself? Because:

- If the replacement $CONTENT exceeds the original size, and the
replacement causes a quota excess, then you’ll be unable to write the
full $CONTENT. But you’ll have written _part_ of it, which probably
means you now have a corrupt file.
- If $CONTENT is written in pieces (which can happen if, e.g., the
filesystem isn’t local), then your file will be corrupt until you’ve
written out the full $CONTENT.

The write-then-rename approach does have a few liabilities of its own:

- It assumes you have write permission on the directory.
- If $PATH already exists, then you need enough disk space to
store the old content **and** $CONTENT.
- It’s a bit slower.

**ADDITIONAL NOTE:** This function ignores SIGXFSZ on platforms where it
exists.

# BENCHMARKS

The smaller the file, the bigger the speed increase this module yields
over pure-Perl slurping. The amount of increase will depend on your
local system. See `benchmark_slurp.pl` in the distribution.
