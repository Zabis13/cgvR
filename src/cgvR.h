/*
 * cgvR — main internal header
 */
#ifndef CGVR_H
#define CGVR_H

#include <R.h>
#include <Rinternals.h>

/* Datoviz public API */
#include "datoviz_app.h"
#include "datoviz_visuals.h"
#include "datoviz.h"

/* ── Camera mode enum ──────────────────────────────────── */
typedef enum {
    CGV_CAM_FLY     = 0,   /* FPS-style: WASD + mouse look           */
    CGV_CAM_ORBIT   = 1,   /* orbit around target (Shift+drag/scroll) */
} CgvCameraMode;

/* ── Path animation state ──────────────────────────────── */
#define CGV_MAX_WAYPOINTS 4096

typedef struct {
    int         active;            /* animation running?           */
    int         n_waypoints;       /* total waypoints              */
    vec3        waypoints[CGV_MAX_WAYPOINTS]; /* positions         */
    double      total_duration;    /* seconds for the whole path   */
    double      start_time;        /* wall-clock start (seconds)   */
    int         loop;              /* loop when reaching the end?  */
    int         pause;             /* paused?                      */
    double      pause_offset;      /* accumulated time before pause*/
} CgvPathAnim;

/* ── Viewer state ───────────────────────────────────────── */
typedef struct {
    DvzApp*     app;
    DvzBatch*   batch;
    DvzScene*   scene;
    DvzFigure*  figure;
    DvzPanel*   panel;
    DvzCamera*  camera;
    DvzFly*     fly;

    /* Camera control */
    CgvCameraMode cam_mode;
    vec3        orbit_target;      /* center of orbit rotation      */
    float       orbit_distance;    /* distance from target          */
    float       orbit_yaw;
    float       orbit_pitch;

    /* Path animation */
    CgvPathAnim path_anim;

    /* Node/edge cache (for fly_to and highlight) */
    vec3*       node_positions;    /* NULL until graph is set       */
    DvzColor*   node_colors;       /* original colors for restore   */
    int*        edge_indices;      /* from/to pairs (0-based)       */
    int         n_nodes;
    int         n_edges;

    /* Visuals */
    DvzVisual*  node_visual;   /* point visual for graph nodes */
    DvzVisual*  edge_visual;   /* segment visual for graph edges */
    DvzVisual*  path_visual;   /* segment visual for highlighted path */

    /* Settings */
    int         width;
    int         height;
    int         visibility_depth;
    int         running;
} CgvViewer;

/* ── .Call functions ────────────────────────────────────── */

/* Viewer */
SEXP C_cgv_viewer_create(SEXP width, SEXP height, SEXP title);
SEXP C_cgv_viewer_close(SEXP viewer);
SEXP C_cgv_run(SEXP viewer);

/* Graph */
SEXP C_cgv_set_graph(SEXP viewer, SEXP nodes, SEXP edges, SEXP positions,
                     SEXP node_values, SEXP node_colors, SEXP node_sizes,
                     SEXP cmap);
SEXP C_cgv_highlight_path(SEXP viewer, SEXP path, SEXP color,
                          SEXP node_scale, SEXP edge_width);
SEXP C_cgv_clear_path(SEXP viewer);
SEXP C_cgv_set_visibility(SEXP viewer, SEXP depth);

/* Camera */
SEXP C_cgv_camera_set(SEXP viewer, SEXP position, SEXP target, SEXP up);
SEXP C_cgv_camera_mode(SEXP viewer, SEXP mode);
SEXP C_cgv_fly_to(SEXP viewer, SEXP node_id, SEXP duration);
SEXP C_cgv_fly_path(SEXP viewer, SEXP positions, SEXP duration, SEXP loop);

/* Background */
SEXP C_cgv_set_background(SEXP viewer, SEXP colors);

/* Stderr suppression (callable from R for wrapping external C code) */
SEXP C_cgv_suppress_stderr(void);
SEXP C_cgv_restore_stderr(SEXP saved_fd);

/* ── Helpers ────────────────────────────────────────────── */
static inline CgvViewer* get_viewer(SEXP ptr) {
    CgvViewer* v = (CgvViewer*)R_ExternalPtrAddr(ptr);
    if (!v) Rf_error("cgvR: viewer pointer is NULL (already closed?)");
    return v;
}

/* Catmull-Rom interpolation between waypoints */
void cgv_path_interpolate(CgvPathAnim *anim, double t, vec3 out_pos, vec3 out_dir);

#endif /* CGVR_H */
