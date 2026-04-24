/*
 * cgv_viewer.c — Vulkan window via Datoviz: app, scene, figure, panel
 */
#include "cgvR.h"
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <math.h>

/* ── Stderr suppression ──────────────────────────────── */

static int suppress_stderr(void) {
    int saved = dup(STDERR_FILENO);
    int devnull = open("/dev/null", O_WRONLY);
    if (devnull >= 0) {
        dup2(devnull, STDERR_FILENO);
        close(devnull);
    }
    return saved;
}

static void restore_stderr(int saved) {
    if (saved >= 0) {
        dup2(saved, STDERR_FILENO);
        close(saved);
    }
}

SEXP C_cgv_suppress_stderr(void) {
    int fd = suppress_stderr();
    return ScalarInteger(fd);
}

SEXP C_cgv_restore_stderr(SEXP saved_fd) {
    restore_stderr(INTEGER(saved_fd)[0]);
    return R_NilValue;
}

/* ── Frame callback: path animation ──────────────────── */

static void frame_callback(DvzApp* app, DvzId window_id, DvzFrameEvent* ev) {
    CgvViewer *v = (CgvViewer*)ev->user_data;
    if (!v || !v->fly || !v->camera) return;

    CgvPathAnim *anim = &v->path_anim;
    if (!anim->active || anim->pause) return;

    double now = ev->time;

    /* Sentinel: grab start time from first frame */
    if (anim->start_time < 0.0) anim->start_time = now;

    double elapsed = now - anim->start_time + anim->pause_offset;
    double t = elapsed / anim->total_duration;

    if (t >= 1.0) {
        if (anim->loop) {
            anim->start_time = now;
            anim->pause_offset = 0.0;
            t = 0.0;
        } else {
            anim->active = 0;
            return;
        }
    }

    vec3 pos, dir;
    cgv_path_interpolate(anim, t, pos, dir);

    /* Update fly camera position */
    vec3 lookat = {pos[0] + dir[0], pos[1] + dir[1], pos[2] + dir[2]};
    dvz_fly_initial_lookat(v->fly, pos, lookat);
    dvz_fly_reset(v->fly);

    /* Sync camera */
    dvz_camera_position(v->camera, pos);
    dvz_camera_lookat(v->camera, lookat);
    dvz_panel_update(v->panel);
}

/* ── Finalizer ───────────────────────────────────────── */

static void viewer_finalizer(SEXP ptr) {
    CgvViewer *v = (CgvViewer *)R_ExternalPtrAddr(ptr);
    if (v) {
        int fd = suppress_stderr();
        if (v->node_positions) { free(v->node_positions); v->node_positions = NULL; }
        if (v->node_colors)   { free(v->node_colors);   v->node_colors = NULL; }
        if (v->edge_indices)  { free(v->edge_indices);   v->edge_indices = NULL; }
        if (v->scene) dvz_scene_destroy(v->scene);
        if (v->app)   dvz_app_destroy(v->app);
        restore_stderr(fd);
        Free(v);
        R_ClearExternalPtr(ptr);
    }
}

/* ── Create ──────────────────────────────────────────── */

SEXP C_cgv_viewer_create(SEXP width, SEXP height, SEXP title) {
    CgvViewer *v = Calloc(1, CgvViewer);
    v->width  = INTEGER(width)[0];
    v->height = INTEGER(height)[0];
    v->visibility_depth = 10;
    v->running = 0;
    v->cam_mode = CGV_CAM_FLY;
    v->node_positions = NULL;
    v->node_colors = NULL;
    v->edge_indices = NULL;
    v->n_nodes = 0;
    v->n_edges = 0;

    /* Orbit defaults */
    v->orbit_target[0] = 0.0f; v->orbit_target[1] = 0.0f; v->orbit_target[2] = 0.0f;
    v->orbit_distance = 5.0f;
    v->orbit_yaw = 0.0f;
    v->orbit_pitch = 0.0f;

    /* Path anim defaults */
    memset(&v->path_anim, 0, sizeof(CgvPathAnim));

    /* Suppress Vulkan driver stderr warnings during init */
    int fd = suppress_stderr();

    v->app   = dvz_app(0);
    v->batch = dvz_app_batch(v->app);

    v->scene  = dvz_scene(v->batch);
    v->figure = dvz_figure(v->scene, (uint32_t)v->width, (uint32_t)v->height, 0);
    v->panel  = dvz_panel_default(v->figure);

    /* Fly camera controller — handles WASD + mouse automatically */
    v->fly = dvz_panel_fly(v->panel, 0);
    dvz_fly_initial_lookat(v->fly, (vec3){0, 0, 5}, (vec3){0, 0, 0});

    /* Perspective camera (created by dvz_panel_fly internally) */
    v->camera = dvz_panel_camera(v->panel, DVZ_CAMERA_FLAGS_PERSPECTIVE);

    /* Register our frame callback for path animation */
    dvz_app_on_frame(v->app, frame_callback, v);

    restore_stderr(fd);

    v->node_visual = NULL;
    v->edge_visual = NULL;
    v->path_visual = NULL;

    SEXP ptr = PROTECT(R_MakeExternalPtr(v, R_NilValue, R_NilValue));
    R_RegisterCFinalizerEx(ptr, viewer_finalizer, TRUE);
    UNPROTECT(1);
    return ptr;
}

/* ── Close ───────────────────────────────────────────── */

SEXP C_cgv_viewer_close(SEXP viewer) {
    CgvViewer *v = (CgvViewer *)R_ExternalPtrAddr(viewer);
    if (v) {
        v->running = 0;
        int fd = suppress_stderr();
        if (v->node_positions) { free(v->node_positions); v->node_positions = NULL; }
        if (v->node_colors)   { free(v->node_colors);   v->node_colors = NULL; }
        if (v->edge_indices)  { free(v->edge_indices);   v->edge_indices = NULL; }
        if (v->scene) { dvz_scene_destroy(v->scene); v->scene = NULL; }
        if (v->app)   { dvz_app_destroy(v->app);     v->app = NULL; }
        restore_stderr(fd);
        Free(v);
        R_ClearExternalPtr(viewer);
    }
    return R_NilValue;
}

/* ── Background color ────────────────────────────────── */

SEXP C_cgv_set_background(SEXP viewer, SEXP colors) {
    CgvViewer *v = get_viewer(viewer);

    /* colors: integer matrix 4x4 (4 corners × RGBA) or 1x4 (single color) */
    int n = Rf_nrows(colors);
    int *ci = INTEGER(colors);

    cvec4 bg[4];
    if (n == 1) {
        /* Single color → all 4 corners */
        for (int j = 0; j < 4; j++) {
            bg[0][j] = (uint8_t)ci[j * 1];  /* column-major: ci[row + col*nrows] */
        }
        for (int i = 1; i < 4; i++)
            memcpy(bg[i], bg[0], sizeof(cvec4));
    } else {
        /* 4 rows × 4 cols (RGBA) */
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                bg[i][j] = (uint8_t)ci[i + j * n];
            }
        }
    }

    dvz_panel_background(v->panel, bg);
    return R_NilValue;
}

/* ── Run ─────────────────────────────────────────────── */

SEXP C_cgv_run(SEXP viewer) {
    CgvViewer *v = get_viewer(viewer);
    v->running = 1;
    dvz_scene_run(v->scene, v->app, 0);
    v->running = 0;
    return R_NilValue;
}
