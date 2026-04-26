/*
 * R-safe I/O implementation for cgvR / bundled Datoviz.
 *
 * Defines CGV_R_IO_IMPL so cgv_r_compat.h skips macro redirections —
 * this file uses the real <stdio.h> / <stdlib.h> types and declarations.
 */

#define CGV_R_IO_IMPL

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Print.h>
#include <R_ext/Random.h>

#include "cgv_r_compat.h"

/* Non-NULL sentinels; wrappers ignore the stream argument. */
FILE *cgv_stderr_sentinel = (FILE *)1;
FILE *cgv_stdout_sentinel = (FILE *)1;

int cgv_fprintf(FILE *stream, const char *format, ...) {
    (void)stream;
    va_list args;
    va_start(args, format);
    REvprintf(format, args);
    va_end(args);
    return 0;
}

int cgv_vfprintf(FILE *stream, const char *format, va_list args) {
    (void)stream;
    REvprintf(format, args);
    return 0;
}

int cgv_printf(const char *format, ...) {
    va_list args;
    va_start(args, format);
    Rvprintf(format, args);
    va_end(args);
    return 0;
}

int cgv_vprintf(const char *format, va_list args) {
    Rvprintf(format, args);
    return 0;
}

int cgv_puts(const char *s) {
    Rprintf("%s\n", s);
    return 0;
}

int cgv_putchar(int c) {
    Rprintf("%c", c);
    return c;
}

int cgv_fflush(FILE *stream) {
    (void)stream;
    return 0;
}

int cgv_fputs(const char *s, FILE *stream) {
    (void)stream;
    REprintf("%s", s);
    return 0;
}

void cgv_abort_impl(const char *file, int line, const char *msg) {
    Rf_error("cgvR fatal error at %s:%d: %s", file, line, msg);
    while (1) {}
}

void cgv_exit_impl(int status) {
    Rf_error("cgvR: exit called with status %d", status);
    while (1) {}
}

/* rand() replacement using R's RNG. Returns a value in [0, RAND_MAX]. */
int cgv_rand(void) {
    GetRNGstate();
    double u = unif_rand();
    PutRNGstate();
    return (int)(u * (double)RAND_MAX);
}
