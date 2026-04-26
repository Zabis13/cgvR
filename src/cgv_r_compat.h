/*
 * R compatibility header for cgvR / bundled Datoviz.
 *
 * Redirects standard C I/O, error and RNG functions to R-safe alternatives.
 * Force-included via -include flag in Makevars before any other headers.
 *
 * Addresses CRAN policy requirements:
 * - No direct writes to stdout/stderr (must use Rprintf/REprintf)
 * - No abort()/exit() that terminate R
 * - No rand()/srand() (must use R's RNG)
 *
 * Pure-C wrappers declared here are implemented in cgv_r_io.c, which
 * itself defines CGV_R_IO_IMPL to skip the macro redirections (so it
 * can include the real <stdio.h> / <stdlib.h>).
 */

#ifndef CGV_R_COMPAT_H
#define CGV_R_COMPAT_H

#if !defined(CGV_R_IO_IMPL)

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__GNUC__) || defined(__clang__)
#  define CGV_FORMAT_PRINTF(fmt_idx, first_arg) __attribute__((format(printf, fmt_idx, first_arg)))
#  define CGV_NORETURN __attribute__((noreturn))
#else
#  define CGV_FORMAT_PRINTF(fmt_idx, first_arg)
#  define CGV_NORETURN
#endif

CGV_FORMAT_PRINTF(2, 3)
int cgv_fprintf(FILE *stream, const char *format, ...);
int cgv_vfprintf(FILE *stream, const char *format, va_list args);
CGV_FORMAT_PRINTF(1, 2)
int cgv_printf(const char *format, ...);
int cgv_vprintf(const char *format, va_list args);
int cgv_puts(const char *s);
int cgv_putchar(int c);
int cgv_fflush(FILE *stream);
int cgv_fputs(const char *s, FILE *stream);
CGV_NORETURN
void cgv_abort_impl(const char *file, int line, const char *msg);
CGV_NORETURN
void cgv_exit_impl(int status);

int cgv_rand(void);

extern FILE *cgv_stderr_sentinel;
extern FILE *cgv_stdout_sentinel;

#ifdef __cplusplus
}
#endif

/* sprintf: CRAN bans it; redirect to snprintf with a large buffer.
 * Datoviz only uses sprintf for short error messages, so a fixed 2048
 * byte cap is safe. */
#undef sprintf
#define sprintf(buf, ...) snprintf((buf), 2048, __VA_ARGS__)

#undef stderr
#define stderr cgv_stderr_sentinel
#undef stdout
#define stdout cgv_stdout_sentinel

#undef fprintf
#define fprintf cgv_fprintf
#undef vfprintf
#define vfprintf cgv_vfprintf
#undef printf
#define printf cgv_printf
#undef vprintf
#define vprintf cgv_vprintf
#undef puts
#define puts cgv_puts
#undef putchar
#define putchar cgv_putchar
#undef fflush
#define fflush cgv_fflush
#undef fputs
#define fputs cgv_fputs

#undef abort
#define abort() do { cgv_abort_impl(__FILE__, __LINE__, "abort called"); __builtin_unreachable(); } while(0)

#undef exit
#define exit(status) cgv_exit_impl(status)

#undef _Exit
#define _Exit(status) cgv_exit_impl(status)

#ifndef __cplusplus
#undef rand
#define rand() cgv_rand()
#endif

#endif /* !CGV_R_IO_IMPL */

#endif /* CGV_R_COMPAT_H */
