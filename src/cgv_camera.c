/*
 * cgv_camera.c — camera modes, fly-to, path animation
 */
#include "cgvR.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>

/* ── Catmull-Rom spline interpolation ────────────────── */

static void catmull_rom(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t, vec3 out) {
    float t2 = t * t;
    float t3 = t2 * t;
    for (int i = 0; i < 3; i++) {
        out[i] = 0.5f * (
            (2.0f * p1[i]) +
            (-p0[i] + p2[i]) * t +
            (2.0f * p0[i] - 5.0f * p1[i] + 4.0f * p2[i] - p3[i]) * t2 +
            (-p0[i] + 3.0f * p1[i] - 3.0f * p2[i] + p3[i]) * t3
        );
    }
}

void cgv_path_interpolate(CgvPathAnim *anim, double t, vec3 out_pos, vec3 out_dir) {
    int n = anim->n_waypoints;
    if (n < 2) {
        if (n == 1) {
            memcpy(out_pos, anim->waypoints[0], sizeof(vec3));
        }
        out_dir[0] = 0; out_dir[1] = 0; out_dir[2] = -1;
        return;
    }

    /* Map t [0,1] to segment index + local t */
    float ft = (float)t * (float)(n - 1);
    int seg = (int)ft;
    if (seg >= n - 1) seg = n - 2;
    float local_t = ft - (float)seg;

    /* Clamp control point indices */
    int i0 = seg > 0 ? seg - 1 : 0;
    int i1 = seg;
    int i2 = seg + 1;
    int i3 = seg + 2 < n ? seg + 2 : n - 1;

    catmull_rom(anim->waypoints[i0], anim->waypoints[i1],
                anim->waypoints[i2], anim->waypoints[i3],
                local_t, out_pos);

    /* Direction: derivative of Catmull-Rom (tangent) */
    float dt = 0.001f;
    float t2 = local_t + dt;
    if (t2 > 1.0f && i2 < n - 1) { t2 = 1.0f; }
    vec3 pos2;
    catmull_rom(anim->waypoints[i0], anim->waypoints[i1],
                anim->waypoints[i2], anim->waypoints[i3],
                t2 > 1.0f ? 1.0f : t2, pos2);

    out_dir[0] = pos2[0] - out_pos[0];
    out_dir[1] = pos2[1] - out_pos[1];
    out_dir[2] = pos2[2] - out_pos[2];

    /* Normalize */
    float len = sqrtf(out_dir[0]*out_dir[0] + out_dir[1]*out_dir[1] + out_dir[2]*out_dir[2]);
    if (len > 1e-6f) {
        out_dir[0] /= len; out_dir[1] /= len; out_dir[2] /= len;
    } else {
        out_dir[0] = 0; out_dir[1] = 0; out_dir[2] = -1;
    }
}

/* ── Camera set (programmatic) ───────────────────────── */

SEXP C_cgv_camera_set(SEXP viewer, SEXP position, SEXP target, SEXP up) {
    CgvViewer *v = get_viewer(viewer);

    double *p = REAL(position);
    double *t = REAL(target);
    double *u = REAL(up);

    vec3 pos = {(float)p[0], (float)p[1], (float)p[2]};
    vec3 tgt = {(float)t[0], (float)t[1], (float)t[2]};
    vec3 upv = {(float)u[0], (float)u[1], (float)u[2]};

    /* Stop any running animation */
    v->path_anim.active = 0;

    /* Update fly controller */
    if (v->fly) {
        dvz_fly_initial_lookat(v->fly, pos, tgt);
        dvz_fly_reset(v->fly);
    }

    dvz_camera_position(v->camera, pos);
    dvz_camera_lookat(v->camera, tgt);
    dvz_camera_up(v->camera, upv);

    dvz_panel_update(v->panel);
    dvz_app_submit(v->app);

    return R_NilValue;
}

/* ── Camera mode switching ───────────────────────────── */

SEXP C_cgv_camera_mode(SEXP viewer, SEXP mode) {
    CgvViewer *v = get_viewer(viewer);
    const char *m = CHAR(STRING_ELT(mode, 0));

    if (strcmp(m, "fly") == 0) {
        v->cam_mode = CGV_CAM_FLY;
    } else if (strcmp(m, "orbit") == 0) {
        v->cam_mode = CGV_CAM_ORBIT;
        /* Store current camera position as orbit state */
        if (v->camera) {
            vec3 pos, look;
            dvz_camera_get_position(v->camera, pos);
            dvz_camera_get_lookat(v->camera, look);
            memcpy(v->orbit_target, look, sizeof(vec3));
            float dx = pos[0] - look[0];
            float dy = pos[1] - look[1];
            float dz = pos[2] - look[2];
            v->orbit_distance = sqrtf(dx*dx + dy*dy + dz*dz);
            if (v->orbit_distance < 0.1f) v->orbit_distance = 5.0f;
            v->orbit_yaw = atan2f(dx, dz);
            v->orbit_pitch = asinf(dy / v->orbit_distance);
        }
    } else {
        Rf_warning("cgvR: unknown camera mode '%s', use 'fly' or 'orbit'", m);
    }

    return R_NilValue;
}

/* ── Fly to node ─────────────────────────────────────── */

SEXP C_cgv_fly_to(SEXP viewer, SEXP node_id, SEXP duration) {
    CgvViewer *v = get_viewer(viewer);

    int nid = INTEGER(node_id)[0];
    double dur = REAL(duration)[0];
    if (dur <= 0.0) dur = 1.0;

    /* Check we have positions cached */
    if (!v->node_positions || nid < 0 || nid >= v->n_nodes) {
        Rf_warning("cgvR: cannot fly to node %d (no positions or out of range)", nid);
        return R_NilValue;
    }

    /* Build 2-waypoint path: current position -> target node */
    CgvPathAnim *anim = &v->path_anim;
    anim->n_waypoints = 2;

    if (v->camera) {
        dvz_camera_get_position(v->camera, anim->waypoints[0]);
    } else {
        anim->waypoints[0][0] = 0; anim->waypoints[0][1] = 0; anim->waypoints[0][2] = 5;
    }

    /* Target: offset slightly so we look at the node, not inside it */
    vec3 node_pos;
    memcpy(node_pos, v->node_positions[nid], sizeof(vec3));
    float offset = 2.0f;

    /* Direction from node back toward current camera */
    float dx = anim->waypoints[0][0] - node_pos[0];
    float dy = anim->waypoints[0][1] - node_pos[1];
    float dz = anim->waypoints[0][2] - node_pos[2];
    float dist = sqrtf(dx*dx + dy*dy + dz*dz);
    if (dist > 1e-6f) {
        anim->waypoints[1][0] = node_pos[0] + offset * dx / dist;
        anim->waypoints[1][1] = node_pos[1] + offset * dy / dist;
        anim->waypoints[1][2] = node_pos[2] + offset * dz / dist;
    } else {
        anim->waypoints[1][0] = node_pos[0];
        anim->waypoints[1][1] = node_pos[1];
        anim->waypoints[1][2] = node_pos[2] + offset;
    }

    anim->total_duration = dur;
    anim->start_time = 0.0; /* will be set on first frame with ev->time */
    anim->pause_offset = 0.0;
    anim->loop = 0;
    anim->pause = 0;
    anim->active = 1;

    /* We need to grab the time from the first frame event.
     * Set start_time = -1 as sentinel. The frame callback will fix it. */
    anim->start_time = -1.0;

    return R_NilValue;
}

/* ── Fly along path (array of 3D positions) ──────────── */

SEXP C_cgv_fly_path(SEXP viewer, SEXP positions, SEXP duration, SEXP loop) {
    CgvViewer *v = get_viewer(viewer);

    /* positions: n x 3 matrix (column-major from R) */
    int n = Rf_nrows(positions);
    if (n < 2) {
        Rf_warning("cgvR: fly_path needs at least 2 waypoints");
        return R_NilValue;
    }
    if (n > CGV_MAX_WAYPOINTS) {
        Rf_warning("cgvR: too many waypoints (%d > %d), truncating", n, CGV_MAX_WAYPOINTS);
        n = CGV_MAX_WAYPOINTS;
    }

    double *p = REAL(positions);
    CgvPathAnim *anim = &v->path_anim;

    for (int i = 0; i < n; i++) {
        anim->waypoints[i][0] = (float)p[i];
        anim->waypoints[i][1] = (float)p[i + n];
        anim->waypoints[i][2] = (float)p[i + 2 * n];
    }

    anim->n_waypoints = n;
    anim->total_duration = REAL(duration)[0];
    if (anim->total_duration <= 0.0) anim->total_duration = 5.0;
    anim->loop = LOGICAL(loop)[0];
    anim->pause = 0;
    anim->pause_offset = 0.0;
    anim->start_time = -1.0; /* sentinel: grab from first frame */
    anim->active = 1;

    return R_NilValue;
}
