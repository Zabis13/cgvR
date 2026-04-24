/*
 * cgv_graph.c — graph data upload, coloring, and path highlighting
 */
#include "cgvR.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* ── Parse hex color "#RRGGBB" or "#RRGGBBAA" to DvzColor ── */
static void parse_hex_color(const char *hex, DvzColor out) {
    unsigned int r = 255, g = 0, b = 0, a = 255;
    if (hex && hex[0] == '#') {
        size_t len = strlen(hex);
        if (len >= 7) sscanf(hex + 1, "%02x%02x%02x", &r, &g, &b);
        if (len >= 9) sscanf(hex + 7, "%02x", &a);
    }
    out[0] = (uint8_t)r; out[1] = (uint8_t)g;
    out[2] = (uint8_t)b; out[3] = (uint8_t)a;
}

/* ── Apply colormap to a numeric vector ──────────────── */
static void apply_colormap(double *values, int n, DvzColormap cmap, DvzColor *out) {
    /* Find min/max */
    double vmin = values[0], vmax = values[0];
    for (int i = 1; i < n; i++) {
        if (values[i] < vmin) vmin = values[i];
        if (values[i] > vmax) vmax = values[i];
    }
    if (vmax <= vmin) vmax = vmin + 1.0;

    for (int i = 0; i < n; i++) {
        dvz_colormap_scale(cmap, (float)values[i], (float)vmin, (float)vmax, out[i]);
    }
}

/* ── Average color of two DvzColors ──────────────────── */
static void color_avg(DvzColor a, DvzColor b, DvzColor out) {
    out[0] = (uint8_t)(((int)a[0] + (int)b[0]) / 2);
    out[1] = (uint8_t)(((int)a[1] + (int)b[1]) / 2);
    out[2] = (uint8_t)(((int)a[2] + (int)b[2]) / 2);
    out[3] = (uint8_t)(((int)a[3] + (int)b[3]) / 2);
}

/* ──────────────────────────────────────────────────────
 *  C_cgv_set_graph(viewer, nodes, edges, positions,
 *                  node_values, node_colors, node_sizes,
 *                  cmap)
 *
 *  node_values:  numeric vector length n (for colormap) or NULL
 *  node_colors:  n x 4 integer matrix (RGBA 0-255) or NULL
 *  node_sizes:   numeric vector length n or NULL (default 10)
 *  cmap:         integer scalar colormap id (default DVZ_CMAP_VIRIDIS = 6)
 *
 *  Priority: node_colors > node_values > default
 * ────────────────────────────────────────────────────── */

SEXP C_cgv_set_graph(SEXP viewer, SEXP nodes, SEXP edges, SEXP positions,
                     SEXP node_values, SEXP node_colors, SEXP node_sizes,
                     SEXP cmap) {
    CgvViewer *v = get_viewer(viewer);

    int n_nodes = Rf_length(nodes);
    int n_edges = Rf_length(edges) / 2;
    int *edge_data = INTEGER(edges);

    /* ── Node positions ──────────────────────────────── */
    vec3 *pos = (vec3 *)R_alloc(n_nodes, sizeof(vec3));

    if (!Rf_isNull(positions)) {
        double *p = REAL(positions);
        for (int i = 0; i < n_nodes; i++) {
            pos[i][0] = (float)p[i];
            pos[i][1] = (float)p[i + n_nodes];
            pos[i][2] = (float)p[i + 2 * n_nodes];
        }
    } else {
        for (int i = 0; i < n_nodes; i++) {
            pos[i][0] = (float)i * 0.1f;
            pos[i][1] = 0.0f;
            pos[i][2] = 0.0f;
        }
    }

    /* Create node visual on first call */
    int node_visual_new = 0;
    if (!v->node_visual) {
        v->node_visual = dvz_point(v->batch, 0);
        node_visual_new = 1;
    }

    dvz_point_alloc(v->node_visual, (uint32_t)n_nodes);
    dvz_point_position(v->node_visual, 0, (uint32_t)n_nodes, pos, 0);

    /* ── Node sizes ──────────────────────────────────── */
    float *sizes = (float *)R_alloc(n_nodes, sizeof(float));
    if (!Rf_isNull(node_sizes)) {
        double *sv = REAL(node_sizes);
        for (int i = 0; i < n_nodes; i++) sizes[i] = (float)sv[i];
    } else {
        for (int i = 0; i < n_nodes; i++) sizes[i] = 10.0f;
    }
    dvz_point_size(v->node_visual, 0, (uint32_t)n_nodes, sizes, 0);

    /* ── Node colors ─────────────────────────────────── */
    DvzColor *colors = (DvzColor *)R_alloc(n_nodes, sizeof(DvzColor));

    if (!Rf_isNull(node_colors)) {
        /* n x 4 integer matrix (RGBA 0-255), column-major */
        int *cv = INTEGER(node_colors);
        for (int i = 0; i < n_nodes; i++) {
            colors[i][0] = (uint8_t)cv[i];
            colors[i][1] = (uint8_t)cv[i + n_nodes];
            colors[i][2] = (uint8_t)cv[i + 2 * n_nodes];
            colors[i][3] = (uint8_t)cv[i + 3 * n_nodes];
        }
    } else if (!Rf_isNull(node_values)) {
        /* Numeric vector → colormap */
        DvzColormap cm = (DvzColormap)INTEGER(cmap)[0];
        apply_colormap(REAL(node_values), n_nodes, cm, colors);
    } else {
        /* Default: light blue */
        for (int i = 0; i < n_nodes; i++) {
            colors[i][0] = 200; colors[i][1] = 200;
            colors[i][2] = 255; colors[i][3] = 255;
        }
    }
    dvz_point_color(v->node_visual, 0, (uint32_t)n_nodes, colors, 0);

    if (node_visual_new)
        dvz_panel_visual(v->panel, v->node_visual, 0);

    /* ── Cache node positions and colors for fly_to / highlight ── */
    if (v->node_positions) free(v->node_positions);
    v->node_positions = (vec3 *)malloc((size_t)n_nodes * sizeof(vec3));
    if (v->node_positions) {
        memcpy(v->node_positions, pos, (size_t)n_nodes * sizeof(vec3));
        v->n_nodes = n_nodes;
    }

    if (v->node_colors) free(v->node_colors);
    v->node_colors = (DvzColor *)malloc((size_t)n_nodes * sizeof(DvzColor));
    if (v->node_colors) {
        memcpy(v->node_colors, colors, (size_t)n_nodes * sizeof(DvzColor));
    }

    /* ── Edges ───────────────────────────────────────── */
    v->n_edges = n_edges;
    if (v->edge_indices) free(v->edge_indices);
    v->edge_indices = NULL;

    if (n_edges > 0) {
        /* Store edge indices for highlight_path */
        v->edge_indices = (int *)malloc((size_t)n_edges * 2 * sizeof(int));

        vec3 *edge_start = (vec3 *)R_alloc(n_edges, sizeof(vec3));
        vec3 *edge_end   = (vec3 *)R_alloc(n_edges, sizeof(vec3));
        DvzColor *ecol   = (DvzColor *)R_alloc(n_edges, sizeof(DvzColor));

        for (int i = 0; i < n_edges; i++) {
            int from = edge_data[i] - 1;
            int to   = edge_data[i + n_edges] - 1;

            if (v->edge_indices) {
                v->edge_indices[i] = from;
                v->edge_indices[i + n_edges] = to;
            }

            if (from >= 0 && from < n_nodes && to >= 0 && to < n_nodes) {
                memcpy(edge_start[i], pos[from], sizeof(vec3));
                memcpy(edge_end[i],   pos[to],   sizeof(vec3));
                /* Edge color: average of endpoint colors, full opacity */
                color_avg(colors[from], colors[to], ecol[i]);
                ecol[i][3] = 255;
            } else {
                memset(edge_start[i], 0, sizeof(vec3));
                memset(edge_end[i],   0, sizeof(vec3));
                ecol[i][0] = 100; ecol[i][1] = 100;
                ecol[i][2] = 100; ecol[i][3] = 150;
            }
        }

        int edge_visual_new = 0;
        if (!v->edge_visual) {
            v->edge_visual = dvz_segment(v->batch, 0);
            edge_visual_new = 1;
        }

        dvz_segment_alloc(v->edge_visual, (uint32_t)n_edges);
        dvz_segment_position(
            v->edge_visual, 0, (uint32_t)n_edges, edge_start, edge_end, 0);
        dvz_segment_color(v->edge_visual, 0, (uint32_t)n_edges, ecol, 0);

        if (edge_visual_new)
            dvz_panel_visual(v->panel, v->edge_visual, 0);
    }

    dvz_app_submit(v->app);

    return R_NilValue;
}

/* ──────────────────────────────────────────────────────
 *  C_cgv_highlight_path — highlight nodes and edges of a path
 *
 *  path:        integer vector of node IDs (1-based)
 *  color:       "#RRGGBB" or "#RRGGBBAA"
 *  node_scale:  float multiplier for node size on path (default 2.0)
 *  edge_width:  float line width for path edges (default 5.0)
 * ────────────────────────────────────────────────────── */

SEXP C_cgv_highlight_path(SEXP viewer, SEXP path, SEXP color,
                          SEXP node_scale, SEXP edge_width) {
    CgvViewer *v = get_viewer(viewer);

    int n = Rf_length(path);
    if (n < 1) return R_NilValue;

    if (!v->node_positions || !v->node_visual) {
        Rf_warning("cgvR: no graph loaded, call cgv_set_graph first");
        return R_NilValue;
    }

    const char *col_str = CHAR(STRING_ELT(color, 0));
    DvzColor col;
    parse_hex_color(col_str, col);

    float nscale = (float)REAL(node_scale)[0];
    float ewidth = (float)REAL(edge_width)[0];

    int *path_ids = INTEGER(path);

    /* ── Highlight nodes: override color and size ────── */
    for (int i = 0; i < n; i++) {
        int nid = path_ids[i] - 1;  /* R 1-based → C 0-based */
        if (nid < 0 || nid >= v->n_nodes) continue;

        DvzColor nc;
        memcpy(nc, col, sizeof(DvzColor));
        dvz_point_color(v->node_visual, (uint32_t)nid, 1, &nc, 0);

        float big = 10.0f * nscale;
        dvz_point_size(v->node_visual, (uint32_t)nid, 1, &big, 0);
    }

    /* ── Highlight edges: create/update path_visual ──── */
    int n_path_edges = n - 1;
    if (n_path_edges > 0) {
        vec3 *pstart = (vec3 *)R_alloc(n_path_edges, sizeof(vec3));
        vec3 *pend   = (vec3 *)R_alloc(n_path_edges, sizeof(vec3));
        DvzColor *pcol = (DvzColor *)R_alloc(n_path_edges, sizeof(DvzColor));
        float *pwidth  = (float *)R_alloc(n_path_edges, sizeof(float));

        for (int i = 0; i < n_path_edges; i++) {
            int from = path_ids[i] - 1;
            int to   = path_ids[i + 1] - 1;

            if (from >= 0 && from < v->n_nodes &&
                to >= 0 && to < v->n_nodes) {
                memcpy(pstart[i], v->node_positions[from], sizeof(vec3));
                memcpy(pend[i],   v->node_positions[to],   sizeof(vec3));
            } else {
                memset(pstart[i], 0, sizeof(vec3));
                memset(pend[i],   0, sizeof(vec3));
            }
            memcpy(pcol[i], col, sizeof(DvzColor));
            pwidth[i] = ewidth;
        }

        int path_visual_new = 0;
        if (!v->path_visual) {
            v->path_visual = dvz_segment(v->batch, 0);
            path_visual_new = 1;
        }

        dvz_segment_alloc(v->path_visual, (uint32_t)n_path_edges);
        dvz_segment_position(
            v->path_visual, 0, (uint32_t)n_path_edges, pstart, pend, 0);
        dvz_segment_color(
            v->path_visual, 0, (uint32_t)n_path_edges, pcol, 0);
        dvz_segment_linewidth(
            v->path_visual, 0, (uint32_t)n_path_edges, pwidth, 0);

        if (path_visual_new)
            dvz_panel_visual(v->panel, v->path_visual, 0);
    }

    dvz_app_submit(v->app);
    return R_NilValue;
}

/* ── Clear path highlight ────────────────────────────── */

SEXP C_cgv_clear_path(SEXP viewer) {
    CgvViewer *v = get_viewer(viewer);

    /* Remove path visual from panel */
    if (v->path_visual) {
        dvz_panel_remove(v->panel, v->path_visual);
        v->path_visual = NULL;
    }

    /* Restore original node colors and sizes */
    if (v->node_visual && v->node_colors && v->n_nodes > 0) {
        dvz_point_color(v->node_visual, 0, (uint32_t)v->n_nodes, v->node_colors, 0);
        float *sizes = (float *)R_alloc(v->n_nodes, sizeof(float));
        for (int i = 0; i < v->n_nodes; i++) sizes[i] = 10.0f;
        dvz_point_size(v->node_visual, 0, (uint32_t)v->n_nodes, sizes, 0);
    }

    dvz_app_submit(v->app);
    return R_NilValue;
}

SEXP C_cgv_set_visibility(SEXP viewer, SEXP depth) {
    CgvViewer *v = get_viewer(viewer);
    v->visibility_depth = INTEGER(depth)[0];
    return R_NilValue;
}
