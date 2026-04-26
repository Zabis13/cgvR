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

#define CGV_STUB(name) SEXP name() { return cgv_stub_error(); }

CGV_STUB(C_cgv_viewer_create)
CGV_STUB(C_cgv_viewer_close)
CGV_STUB(C_cgv_run)
CGV_STUB(C_cgv_set_graph)
CGV_STUB(C_cgv_highlight_path)
CGV_STUB(C_cgv_clear_path)
CGV_STUB(C_cgv_set_visibility)
CGV_STUB(C_cgv_camera_set)
CGV_STUB(C_cgv_camera_mode)
CGV_STUB(C_cgv_fly_to)
CGV_STUB(C_cgv_fly_path)
CGV_STUB(C_cgv_set_background)
CGV_STUB(C_cgv_layout_fr_bh)
CGV_STUB(C_cgv_record_start)
CGV_STUB(C_cgv_record_stop)
CGV_STUB(C_cgv_suppress_stderr)
CGV_STUB(C_cgv_restore_stderr)

#undef CGV_STUB

/* Forward declarations for the table below. */
extern SEXP C_cgv_viewer_create();
extern SEXP C_cgv_viewer_close();
extern SEXP C_cgv_run();
extern SEXP C_cgv_set_graph();
extern SEXP C_cgv_highlight_path();
extern SEXP C_cgv_clear_path();
extern SEXP C_cgv_set_visibility();
extern SEXP C_cgv_camera_set();
extern SEXP C_cgv_camera_mode();
extern SEXP C_cgv_fly_to();
extern SEXP C_cgv_fly_path();
extern SEXP C_cgv_set_background();
extern SEXP C_cgv_layout_fr_bh();
extern SEXP C_cgv_record_start();
extern SEXP C_cgv_record_stop();
extern SEXP C_cgv_suppress_stderr();
extern SEXP C_cgv_restore_stderr();

static const R_CallMethodDef CallEntries[] = {
    {"C_cgv_viewer_create",   (DL_FUNC) &C_cgv_viewer_create,   4},
    {"C_cgv_viewer_close",    (DL_FUNC) &C_cgv_viewer_close,    1},
    {"C_cgv_run",             (DL_FUNC) &C_cgv_run,             2},
    {"C_cgv_set_graph",       (DL_FUNC) &C_cgv_set_graph,       8},
    {"C_cgv_highlight_path",  (DL_FUNC) &C_cgv_highlight_path,  5},
    {"C_cgv_clear_path",      (DL_FUNC) &C_cgv_clear_path,      1},
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
