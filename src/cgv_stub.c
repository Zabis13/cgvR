/*
 * cgv_stub.c — fallback implementations used when the package is built
 * without Vulkan / GLFW (e.g. on CRAN check machines or any host without
 * a graphics SDK). Every .Call entry registered in init.c is provided
 * here as a function that raises an R error explaining the situation.
 *
 * The stub build keeps the package installable and its R-level metadata
 * loadable, but any attempt to actually use the rendering API fails fast.
 * Pure-R helpers like cgv_layout_fr() still work because they don't touch
 * native code.
 */
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

static SEXP cgv_stub_error(void) {
    Rf_error("cgvR was built without Vulkan support (stub build). "
             "Install libvulkan-dev (Linux) or the Vulkan SDK (Windows) "
             "and reinstall the package to enable rendering.");
    return R_NilValue; /* unreachable */
}

/* One macro per arity, so every stub has a full prototype
 * (-Wstrict-prototypes). Arity must match the CallEntries table below. */
#define CGV_STUB0(name) SEXP name(void) { return cgv_stub_error(); }
#define CGV_STUB1(name) SEXP name(SEXP a1) { \
    (void)a1; return cgv_stub_error(); }
#define CGV_STUB2(name) SEXP name(SEXP a1, SEXP a2) { \
    (void)a1; (void)a2; return cgv_stub_error(); }
#define CGV_STUB3(name) SEXP name(SEXP a1, SEXP a2, SEXP a3) { \
    (void)a1; (void)a2; (void)a3; return cgv_stub_error(); }
#define CGV_STUB4(name) SEXP name(SEXP a1, SEXP a2, SEXP a3, SEXP a4) { \
    (void)a1; (void)a2; (void)a3; (void)a4; return cgv_stub_error(); }
#define CGV_STUB5(name) SEXP name(SEXP a1, SEXP a2, SEXP a3, SEXP a4, \
                                  SEXP a5) { \
    (void)a1; (void)a2; (void)a3; (void)a4; (void)a5; \
    return cgv_stub_error(); }
#define CGV_STUB7(name) SEXP name(SEXP a1, SEXP a2, SEXP a3, SEXP a4, \
                                  SEXP a5, SEXP a6, SEXP a7) { \
    (void)a1; (void)a2; (void)a3; (void)a4; (void)a5; (void)a6; (void)a7; \
    return cgv_stub_error(); }
#define CGV_STUB8(name) SEXP name(SEXP a1, SEXP a2, SEXP a3, SEXP a4, \
                                  SEXP a5, SEXP a6, SEXP a7, SEXP a8) { \
    (void)a1; (void)a2; (void)a3; (void)a4; (void)a5; (void)a6; (void)a7; \
    (void)a8; return cgv_stub_error(); }

CGV_STUB4(C_cgv_viewer_create)
CGV_STUB1(C_cgv_viewer_close)
CGV_STUB2(C_cgv_run)
CGV_STUB8(C_cgv_set_graph)
CGV_STUB5(C_cgv_highlight_path)
CGV_STUB1(C_cgv_clear_path)
CGV_STUB2(C_cgv_set_edge_colors)
CGV_STUB2(C_cgv_set_visibility)
CGV_STUB4(C_cgv_camera_set)
CGV_STUB2(C_cgv_camera_mode)
CGV_STUB3(C_cgv_fly_to)
CGV_STUB4(C_cgv_fly_path)
CGV_STUB2(C_cgv_set_background)
CGV_STUB7(C_cgv_layout_fr_bh)
CGV_STUB5(C_cgv_record_start)
CGV_STUB1(C_cgv_record_stop)
CGV_STUB0(C_cgv_suppress_stderr)
CGV_STUB1(C_cgv_restore_stderr)

#undef CGV_STUB0
#undef CGV_STUB1
#undef CGV_STUB2
#undef CGV_STUB3
#undef CGV_STUB4
#undef CGV_STUB5
#undef CGV_STUB7
#undef CGV_STUB8

static const R_CallMethodDef CallEntries[] = {
    {"C_cgv_viewer_create",   (DL_FUNC) &C_cgv_viewer_create,   4},
    {"C_cgv_viewer_close",    (DL_FUNC) &C_cgv_viewer_close,    1},
    {"C_cgv_run",             (DL_FUNC) &C_cgv_run,             2},
    {"C_cgv_set_graph",       (DL_FUNC) &C_cgv_set_graph,       8},
    {"C_cgv_highlight_path",  (DL_FUNC) &C_cgv_highlight_path,  5},
    {"C_cgv_clear_path",      (DL_FUNC) &C_cgv_clear_path,      1},
    {"C_cgv_set_edge_colors", (DL_FUNC) &C_cgv_set_edge_colors, 2},
    {"C_cgv_set_visibility",  (DL_FUNC) &C_cgv_set_visibility,  2},
    {"C_cgv_camera_set",      (DL_FUNC) &C_cgv_camera_set,      4},
    {"C_cgv_camera_mode",     (DL_FUNC) &C_cgv_camera_mode,     2},
    {"C_cgv_fly_to",          (DL_FUNC) &C_cgv_fly_to,          3},
    {"C_cgv_fly_path",        (DL_FUNC) &C_cgv_fly_path,        4},
    {"C_cgv_set_background",  (DL_FUNC) &C_cgv_set_background,  2},
    {"C_cgv_layout_fr_bh",    (DL_FUNC) &C_cgv_layout_fr_bh,    7},
    {"C_cgv_record_start",    (DL_FUNC) &C_cgv_record_start,    5},
    {"C_cgv_record_stop",     (DL_FUNC) &C_cgv_record_stop,     1},
    {"C_cgv_suppress_stderr", (DL_FUNC) &C_cgv_suppress_stderr, 0},
    {"C_cgv_restore_stderr",  (DL_FUNC) &C_cgv_restore_stderr,  1},
    {NULL, NULL, 0}
};

void R_init_cgvR(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
