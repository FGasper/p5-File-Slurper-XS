#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <fcntl.h>
#include <sys/stat.h>

#include <stdlib.h>

#define CHUNK_SIZE 65536

// If stat indicates 0 size, the file is likely empty, *or* it could
// be something special like /proc in Linux. Such files are usually
// small, so let’s minimize the chunk size for these.
#define STAT0_CHUNK_SIZE 4096

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

#define RETURN_FAILED_READ(fd) STMT_START {    \
    int myerrno = errno;                            \
    close_or_warn(fd);                              \
    errno = myerrno;                                \
    return &PL_sv_undef;                            \
} STMT_END

static inline const char*
_path_from_sv (pTHX_ SV* path_sv) {
    STRLEN pathlen;
    const char* path = SvPVbyte(path_sv, pathlen);

    _verify_no_null(path, pathlen);

    return path;
}

static inline SV*
_overwrite (pTHX_ SV* path_sv, SV* content, mode_t mode) {
    const char* path = _path_from_sv(aTHX_ path_sv);

    char* temppath;
    Newxz(temppath, 64 + SvCUR(path_sv), char);
    int len = snprintf(
        temppath, 64 + SvCUR(path_sv),
        "%s.tmp.%x.%x",
        path,
        (unsigned) rand(),
        getpid()
    );

    int fd = open(temppath, O_WRONLY | O_CREAT | O_EXCL, mode);
    if (-1 == fd) {
        Safefree(temppath);
        return &PL_sv_undef;
    }

    ssize_t total = 0;
    while (total < SvCUR(content)) {
        ssize_t wrote = write(fd, SvPVX(content) + total, SvCUR(content) - total);
        if (-1 == wrote) {
            Safefree(temppath);
            close_or_warn(fd);
            return &PL_sv_undef;
        }

        total += wrote;
    }

    close_or_warn(fd);

    // May be ideal to use renameat instead, but this is simpler:
    //
    if (rename(temppath, path)) {
        int myerrno = errno;
        if (unlink(temppath)) {
            warn("unlink(%s) failed: %s", temppath, strerror(errno));
        }
        errno = myerrno;
        return &PL_sv_undef;
    }

    return &PL_sv_yes;
}

static inline SV*
_slurp (pTHX_ SV* path_sv) {
    const char* path = _path_from_sv(aTHX_ path_sv);

    int fd = open(path, O_RDONLY);
    if (-1 == fd) return &PL_sv_undef;

    struct stat statbuf;
    if (-1 == fstat(fd, &statbuf)) {
        RETURN_FAILED_READ(fd);
    }

    SV* ret;
    char *buf;
    int size;

    off_t initial_size = statbuf.st_size ? statbuf.st_size : STAT0_CHUNK_SIZE;

    ret = newSV(initial_size);
    SAVEFREESV(ret);
    SvPOK_on(ret);

    ssize_t total = read(fd, SvPVX(ret), initial_size);
    if (-1 == total) RETURN_FAILED_READ(fd);

    if (LIKELY(total > 0)) {
        if (LIKELY(statbuf.st_size > 0)) {

            // Case 1: We know the file’s size. If we received that many
            // bytes already then we’re done, but if not, we need to keep
            // reading until we meet the known size, OR until we get an
            // empty read (in which case the file is smaller than the size
            // stat gave us).
            //
            while (UNLIKELY(total < statbuf.st_size)) {
                SvGROW(ret, total + CHUNK_SIZE);
                ssize_t got = read(fd, SvPVX(ret) + total, CHUNK_SIZE);
                if (-1 == got) RETURN_FAILED_READ(fd);

                if (0 == got) break;

                total += got;
            }
        }
        else {

            // Case 2: stat() said the file is empty, but our initial
            // read returned data. That means there could be more, so
            // keep slurping.
            while (1) {
                SvGROW(ret, total + STAT0_CHUNK_SIZE);
                ssize_t got = read(fd, SvPVX(ret) + total, STAT0_CHUNK_SIZE);
                if (-1 == got) RETURN_FAILED_READ(fd);

                if (0 == got) break;

                total += got;
            }
        }
    }

    SvCUR_set(ret, total);
    SvREFCNT_inc(ret);

    close_or_warn(fd);

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

SV*
_xs_overwrite_binary (SV* path_sv, SV* content_sv, SV* mode_sv=&PL_sv_undef)
    CODE:
        mode_t mode = SvOK(mode_sv) ? SvUV(mode_sv) : 0600;
        RETVAL = _overwrite(aTHX_ path_sv, content_sv, mode);
    OUTPUT:
        RETVAL
