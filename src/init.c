/*
 * R_init_cgvR — register .Call entries
 */
#include "cgvR.h"
#include <R_ext/Rdynload.h>

static const R_CallMethodDef CallEntries[] = {
    {"C_cgv_viewer_create",    (DL_FUNC) &C_cgv_viewer_create,    4},
    {"C_cgv_viewer_close",     (DL_FUNC) &C_cgv_viewer_close,     1},
    {"C_cgv_run",              (DL_FUNC) &C_cgv_run,              2},
    {"C_cgv_set_graph",        (DL_FUNC) &C_cgv_set_graph,        8},
    {"C_cgv_highlight_path",   (DL_FUNC) &C_cgv_highlight_path,   5},
    {"C_cgv_clear_path",       (DL_FUNC) &C_cgv_clear_path,       1},
    {"C_cgv_set_visibility",   (DL_FUNC) &C_cgv_set_visibility,   2},
    {"C_cgv_camera_set",       (DL_FUNC) &C_cgv_camera_set,       4},
    {"C_cgv_camera_mode",      (DL_FUNC) &C_cgv_camera_mode,      2},
    {"C_cgv_fly_to",           (DL_FUNC) &C_cgv_fly_to,           3},
    {"C_cgv_fly_path",         (DL_FUNC) &C_cgv_fly_path,         4},
    {"C_cgv_set_background",   (DL_FUNC) &C_cgv_set_background,   2},
    {"C_cgv_layout_fr_bh",     (DL_FUNC) &C_cgv_layout_fr_bh,     7},
    {"C_cgv_record_start",     (DL_FUNC) &C_cgv_record_start,     5},
    {"C_cgv_record_stop",      (DL_FUNC) &C_cgv_record_stop,      1},
    {"C_cgv_suppress_stderr",  (DL_FUNC) &C_cgv_suppress_stderr,  0},
    {"C_cgv_restore_stderr",   (DL_FUNC) &C_cgv_restore_stderr,   1},
    {NULL, NULL, 0}
};

void R_init_cgvR(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
