/*
 * cgv_record.c — video recording: pipe raw RGB frames into ffmpeg.
 *
 * cgv_record_start() only stores the request and parameters; the ffmpeg
 * pipe is opened lazily on the first frame tick once the canvas is real.
 * That way recording can be enabled before cgv_run(), and we don't have
 * to call cgv_run() twice (which would re-register objects and crash).
 */
#include "cgvR.h"
#include "datoviz/app.h"
#include "datoviz/canvas.h"
#include "datoviz/renderer.h"
#include "datoviz/board.h"
#include "datoviz/scene/scene.h"
#include "datoviz/_enums.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Helper: lookup the canvas tied to this viewer's figure. */
static DvzCanvas* viewer_canvas(CgvViewer *v) {
    if (!v || !v->figure) return NULL;
    DvzId canvas_id = v->figure->canvas_id;
    if (canvas_id == DVZ_ID_NONE) return NULL;
    DvzRenderer* rd = dvz_app_renderer(v->app);
    if (!rd) return NULL;
    return dvz_renderer_canvas(rd, canvas_id);
}

/* Quote a string for /bin/sh by wrapping in single quotes and escaping any
 * embedded single quotes as '\''. Caller must free(). Returns NULL on OOM
 * or if input is NULL. */
static char* shell_quote(const char *s) {
    if (!s) return NULL;
    size_t in_len = strlen(s);
    /* worst case: every char is ' → 4 chars out, plus 2 wrapping quotes + NUL */
    size_t cap = in_len * 4 + 3;
    char *out = (char*)malloc(cap);
    if (!out) return NULL;
    size_t j = 0;
    out[j++] = '\'';
    for (size_t i = 0; i < in_len; i++) {
        char c = s[i];
        if (c == '\'') {
            out[j++] = '\''; out[j++] = '\\'; out[j++] = '\''; out[j++] = '\'';
        } else {
            out[j++] = c;
        }
    }
    out[j++] = '\'';
    out[j] = '\0';
    return out;
}

/* ── Lifecycle ─────────────────────────────────────────── */

void cgv_record_close(CgvViewer *v) {
    if (!v) return;
    if (v->rec_pipe) {
        pclose(v->rec_pipe);
        v->rec_pipe = NULL;
    }
    if (v->rec_buf)         { free(v->rec_buf);         v->rec_buf = NULL; }
    if (v->rec_output_path) { free(v->rec_output_path); v->rec_output_path = NULL; }
    if (v->rec_extra_args)  { free(v->rec_extra_args);  v->rec_extra_args = NULL; }
    v->rec_active = 0;
    v->rec_pipe_open = 0;
    v->rec_w = 0;
    v->rec_h = 0;
}

/* Open the ffmpeg pipe. Returns 0 on success, -1 on failure. */
static int open_pipe(CgvViewer *v) {
    int W = v->width;
    int H = v->height;
    if (W <= 0 || H <= 0) return -1;

    char *quoted = shell_quote(v->rec_output_path);
    if (!quoted) return -1;

    const char *extra = v->rec_extra_args ? v->rec_extra_args : "";

    char cmd[2048];
    int n = snprintf(cmd, sizeof(cmd),
        "ffmpeg -y -loglevel error "
        "-f rawvideo -pixel_format rgb24 "
        "-video_size %dx%d -framerate %d "
        "-i - "
        "-c:v libx264 -pix_fmt yuv420p -preset veryfast "
        "%s "
        "%s",
        W, H, v->rec_fps, extra, quoted);
    free(quoted);
    if (n < 0 || n >= (int)sizeof(cmd)) {
        Rf_warning("cgvR: ffmpeg command too long, recording aborted");
        cgv_record_close(v);
        return -1;
    }

    FILE *pipe = popen(cmd, "w");
    if (!pipe) {
        Rf_warning("cgvR: failed to start ffmpeg, recording aborted");
        cgv_record_close(v);
        return -1;
    }

    /* Allocate offscreen-mode scratch buffer. */
    if (v->app->host->backend == DVZ_BACKEND_OFFSCREEN) {
        size_t buf_size = (size_t)W * (size_t)H * 3;
        v->rec_buf = (uint8_t*)malloc(buf_size);
        if (!v->rec_buf) {
            pclose(pipe);
            Rf_warning("cgvR: failed to allocate recording buffer");
            cgv_record_close(v);
            return -1;
        }
    }

    v->rec_pipe = pipe;
    v->rec_pipe_open = 1;
    v->rec_w = W;
    v->rec_h = H;
    return 0;
}

/* ── Per-frame tick ────────────────────────────────────── */

void cgv_record_tick(CgvViewer *v, double now) {
    if (!v || !v->rec_active) return;

    /* Lazy-open the pipe on the first tick. */
    if (!v->rec_pipe_open) {
        if (open_pipe(v) != 0) return;
    }

    /* Initialise wall-clock anchor on first valid tick. */
    if (v->rec_started_at < 0.0) {
        v->rec_started_at = now;
        v->rec_next_frame_time = now;
    }

    /* Stop if max duration reached. */
    if (v->rec_max_duration > 0.0 &&
        (now - v->rec_started_at) >= v->rec_max_duration) {
        cgv_record_close(v);
        return;
    }

    /* Not yet time for the next frame. */
    if (now < v->rec_next_frame_time) return;

    DvzCanvas *canvas = viewer_canvas(v);
    if (!canvas) return;

    int W = (int)canvas->width;
    int H = (int)canvas->height;
    if (W != v->rec_w || H != v->rec_h) {
        Rf_warning("cgvR: canvas size changed during recording (%dx%d -> %dx%d), stopping",
                   v->rec_w, v->rec_h, W, H);
        cgv_record_close(v);
        return;
    }

    uint8_t *rgb = NULL;
    size_t n = (size_t)W * (size_t)H * 3;
    if (v->app->host->backend == DVZ_BACKEND_OFFSCREEN) {
        if (!v->rec_buf) return;
        dvz_board_download(canvas, canvas->size, v->rec_buf);
        rgb = v->rec_buf;
    } else {
        rgb = dvz_canvas_download(canvas);
    }
    if (!rgb) return;

    size_t wrote = fwrite(rgb, 1, n, v->rec_pipe);
    if (wrote != n) {
        Rf_warning("cgvR: ffmpeg pipe write short (%zu/%zu), stopping recording",
                   wrote, n);
        cgv_record_close(v);
        return;
    }

    v->rec_frame_count++;
    v->rec_next_frame_time += 1.0 / (double)v->rec_fps;
}

/* ── Start ─────────────────────────────────────────────── */

SEXP C_cgv_record_start(SEXP viewer, SEXP output_path, SEXP fps,
                        SEXP duration, SEXP ffmpeg_args) {
    CgvViewer *v = get_viewer(viewer);

    if (v->rec_active) {
        Rf_error("cgvR: recording already in progress; call cgv_record_stop() first");
    }

    int fps_i = INTEGER(fps)[0];
    if (fps_i <= 0) Rf_error("cgvR: fps must be positive");

    double dur = REAL(duration)[0];
    if (!R_finite(dur) || dur <= 0.0) dur = 0.0;

    const char *path = CHAR(STRING_ELT(output_path, 0));
    if (!path || !*path) Rf_error("cgvR: output path is empty");

    const char *extra = "";
    if (Rf_length(ffmpeg_args) > 0 && STRING_ELT(ffmpeg_args, 0) != NA_STRING) {
        extra = CHAR(STRING_ELT(ffmpeg_args, 0));
    }

    /* Duplicate strings; freed in cgv_record_close. */
    v->rec_output_path = strdup(path);
    v->rec_extra_args  = strdup(extra);
    if (!v->rec_output_path || !v->rec_extra_args) {
        cgv_record_close(v);
        Rf_error("cgvR: out of memory storing recording parameters");
    }

    v->rec_pipe = NULL;
    v->rec_pipe_open = 0;
    v->rec_buf = NULL;
    v->rec_active = 1;
    v->rec_fps = fps_i;
    v->rec_max_duration = dur;
    v->rec_frame_count = 0;
    v->rec_started_at = -1.0;
    v->rec_next_frame_time = 0.0;
    v->rec_w = 0;
    v->rec_h = 0;

    return R_NilValue;
}

/* ── Stop ──────────────────────────────────────────────── */

SEXP C_cgv_record_stop(SEXP viewer) {
    CgvViewer *v = get_viewer(viewer);
    int frames = v->rec_frame_count;
    int fps = v->rec_fps;
    cgv_record_close(v);
    /* Reset the count too once consumed. */
    v->rec_frame_count = 0;

    SEXP out = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(out)[0] = frames;
    INTEGER(out)[1] = fps;
    UNPROTECT(1);
    return out;
}
