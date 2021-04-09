#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <fcntl.h>
#include <sys/stat.h>

#define CHUNK_SIZE 65536

#define _verify_no_null(tomlstr, tomllen)               \
    if (strchr(tomlstr, 0) != (tomlstr + tomllen)) {    \
        croak(                                          \
            "Path contains a NUL at index %lu!",        \
            strchr(tomlstr, 0) - tomlstr                \
        );                                              \
    }

#define close_or_warn(fd) \
    if (-1 == close(fd)) {                                      \
        warn("Failed to close FD %d: %s", fd, strerror(errno)); \
    }

#define RETURN_FAILED_READ(fd, buf) STMT_START {    \
    Safefree(buf);                                  \
    int myerrno = errno;                            \
    close_or_warn(fd);                              \
    errno = myerrno;                                \
    return &PL_sv_undef;                            \
} STMT_END

SV* _slurp (pTHX_ SV* path_sv) {
    STRLEN pathlen;
    char* path = SvPVbyte(path_sv, pathlen);

    _verify_no_null(path, pathlen);

    int fd = open(path, O_RDONLY);
    if (-1 == fd) return &PL_sv_undef;

    struct stat statbuf;
    if (-1 == fstat(fd, &statbuf)) {
        int myerrno = errno;
        close_or_warn(fd);
        errno = myerrno;
        return &PL_sv_undef;
    }

    SV* ret;
    char *buf;
    int size;

    if (statbuf.st_size > 0) {
        Newx(buf, 1 + statbuf.st_size, char);

        ssize_t got = read(fd, buf, statbuf.st_size);
        if (-1 == got) RETURN_FAILED_READ(fd, buf);

        if (got < statbuf.st_size) Renew(buf, 1 + got, char);
        size = got;
    }
    else {
        size = CHUNK_SIZE;
        int offset = 0;
        Newx(buf, CHUNK_SIZE, char);

        ssize_t got;

        while (1) {
            got = read(fd, buf, size - offset);
            if (-1 == got) RETURN_FAILED_READ(fd, buf);

            if (got < CHUNK_SIZE) {
                Renew(buf, 1 + offset + got, char);
                break;
            }
            else if (got == CHUNK_SIZE) {
                Renew(buf, size + CHUNK_SIZE, char);
                size += CHUNK_SIZE;
                offset += CHUNK_SIZE;
            }
            else {
                assert(0);
            }
        }
    }

    close_or_warn(fd);

    /* Trailing NUL: */
    buf[size] = 0;

    ret = newSV(0);
    sv_usepvn(ret, buf, size);

    return ret;
}

/* ---------------------------------------------------------------------- */

MODULE = File::Slurper::XS     PACKAGE = File::Slurper::XS

PROTOTYPES: DISABLE

SV*
read_binary (SV* path_sv)
    CODE:
        RETVAL = _slurp(aTHX_ path_sv);
    OUTPUT:
        RETVAL
