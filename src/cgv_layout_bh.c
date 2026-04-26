/*
 * cgv_layout_bh.c — Barnes-Hut Fruchterman-Reingold 3D layout.
 *
 * Repulsion is approximated via an octree: a node is treated as a single
 * mass when its bbox size s satisfies s/d < theta. Attraction stays
 * exact, summed along edges. O(n_iter * (n log n + n_edges)).
 */
#include "cgvR.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    float cx, cy, cz;     /* centre of mass */
    float mass;
    float min[3];
    float max[3];
    int   children[8];    /* -1 if absent */
    int   point_idx;      /* >= 0: leaf holding that point; -1: internal */
} OctNode;

typedef struct {
    OctNode *nodes;
    int      capacity;
    int      n_used;
    float    theta;       /* BH opening angle */
    float    min_dist;    /* lower clamp for repulsion distance */
    float    k2;          /* ideal_len^2 */
} Octree;

static int alloc_node(Octree *t, const float min[3], const float max[3]) {
    if (t->n_used >= t->capacity) {
        Rf_error("cgvR: octree capacity exhausted (%d) — points likely degenerate",
                 t->capacity);
    }
    int idx = t->n_used++;
    OctNode *n = &t->nodes[idx];
    n->cx = n->cy = n->cz = 0.0f;
    n->mass = 0.0f;
    memcpy(n->min, min, 3 * sizeof(float));
    memcpy(n->max, max, 3 * sizeof(float));
    for (int i = 0; i < 8; i++) n->children[i] = -1;
    n->point_idx = -1;
    return idx;
}

/* Pick child octant index 0..7 for point p inside bbox (min,max). */
static int octant(const float min[3], const float max[3], const float p[3]) {
    float mx = 0.5f * (min[0] + max[0]);
    float my = 0.5f * (min[1] + max[1]);
    float mz = 0.5f * (min[2] + max[2]);
    int ox = p[0] >= mx;
    int oy = p[1] >= my;
    int oz = p[2] >= mz;
    return (ox << 2) | (oy << 1) | oz;
}

static void child_bbox(const float min[3], const float max[3], int oct,
                       float out_min[3], float out_max[3]) {
    float mx = 0.5f * (min[0] + max[0]);
    float my = 0.5f * (min[1] + max[1]);
    float mz = 0.5f * (min[2] + max[2]);
    out_min[0] = (oct & 4) ? mx : min[0];
    out_max[0] = (oct & 4) ? max[0] : mx;
    out_min[1] = (oct & 2) ? my : min[1];
    out_max[1] = (oct & 2) ? max[1] : my;
    out_min[2] = (oct & 1) ? mz : min[2];
    out_max[2] = (oct & 1) ? max[2] : mz;
}

/* Insert point at index pi (with coords pp[3]) into subtree rooted at idx. */
static void insert(Octree *t, int idx, int pi, const float *pos, int n_pts) {
    OctNode *n = &t->nodes[idx];

    /* Empty leaf — drop the point here. */
    if (n->point_idx == -1 && n->mass == 0.0f) {
        n->point_idx = pi;
        n->cx = pos[3 * pi + 0];
        n->cy = pos[3 * pi + 1];
        n->cz = pos[3 * pi + 2];
        n->mass = 1.0f;
        return;
    }

    /* Leaf with one point — split: re-insert old point as a child. */
    if (n->point_idx >= 0) {
        int old = n->point_idx;
        n->point_idx = -1;
        float old_p[3] = {pos[3 * old + 0], pos[3 * old + 1], pos[3 * old + 2]};
        int oct = octant(n->min, n->max, old_p);
        float cmin[3], cmax[3];
        child_bbox(n->min, n->max, oct, cmin, cmax);
        int cid = alloc_node(t, cmin, cmax);
        /* `t->nodes` could have been realloc'd? No — fixed prealloc. But the
         * `n` pointer is still valid since we didn't realloc. */
        n = &t->nodes[idx];
        n->children[oct] = cid;
        insert(t, cid, old, pos, n_pts);
        n = &t->nodes[idx];
    }

    /* Internal node — descend. */
    float p[3] = {pos[3 * pi + 0], pos[3 * pi + 1], pos[3 * pi + 2]};
    int oct = octant(n->min, n->max, p);
    if (n->children[oct] == -1) {
        float cmin[3], cmax[3];
        child_bbox(n->min, n->max, oct, cmin, cmax);
        int cid = alloc_node(t, cmin, cmax);
        n = &t->nodes[idx];
        n->children[oct] = cid;
    }
    int cid = n->children[oct];
    insert(t, cid, pi, pos, n_pts);

    /* Update centre of mass for this node. */
    n = &t->nodes[idx];
    float new_mass = n->mass + 1.0f;
    n->cx = (n->cx * n->mass + pos[3 * pi + 0]) / new_mass;
    n->cy = (n->cy * n->mass + pos[3 * pi + 1]) / new_mass;
    n->cz = (n->cz * n->mass + pos[3 * pi + 2]) / new_mass;
    n->mass = new_mass;
}

/* Recursive force accumulation: add repulsion from subtree onto point p. */
static void accumulate(const Octree *t, int idx, const float p[3],
                       int self_pi, float force[3]) {
    if (idx < 0) return;
    const OctNode *n = &t->nodes[idx];
    if (n->mass == 0.0f) return;

    float dx = p[0] - n->cx;
    float dy = p[1] - n->cy;
    float dz = p[2] - n->cz;
    float d2 = dx*dx + dy*dy + dz*dz;

    /* Leaf with the same point — skip. */
    if (n->point_idx == self_pi && n->mass <= 1.0f) return;

    /* Clamp tiny distances. */
    float min2 = t->min_dist * t->min_dist;
    if (d2 < min2) d2 = min2;

    /* Box size = max of (max-min) across axes. */
    float sx = n->max[0] - n->min[0];
    float sy = n->max[1] - n->min[1];
    float sz = n->max[2] - n->min[2];
    float s  = sx > sy ? (sx > sz ? sx : sz) : (sy > sz ? sy : sz);

    int is_leaf = (n->point_idx >= 0);
    /* BH criterion: s / d < theta → treat as one mass. */
    if (is_leaf || (s * s < t->theta * t->theta * d2)) {
        /* Repulsion: F = k^2 / d, applied along (p - com)/d.
         * Vector form: dx * k^2 / d^2 * mass. */
        float inv_d2 = 1.0f / d2;
        float coef = t->k2 * n->mass * inv_d2;
        force[0] += dx * coef;
        force[1] += dy * coef;
        force[2] += dz * coef;
        return;
    }

    /* Otherwise recurse. */
    for (int i = 0; i < 8; i++) {
        if (n->children[i] >= 0)
            accumulate(t, n->children[i], p, self_pi, force);
    }
}

/* ── R entry point ───────────────────────────────────── */

SEXP C_cgv_layout_fr_bh(SEXP s_pos, SEXP s_edges, SEXP s_n_iter,
                        SEXP s_ideal_len, SEXP s_theta, SEXP s_cool,
                        SEXP s_min_dist) {
    /* pos: n_nodes x 3 numeric matrix (column-major from R), modified in place
     *      via copy. We allocate an output matrix and return it. */
    int n_nodes = Rf_nrows(s_pos);
    if (Rf_ncols(s_pos) != 3) Rf_error("cgvR: positions must have 3 columns");
    int n_iter = INTEGER(s_n_iter)[0];
    int n_edges = Rf_nrows(s_edges);

    float ideal_len = (float)REAL(s_ideal_len)[0];
    float theta    = (float)REAL(s_theta)[0];
    float cool     = (float)REAL(s_cool)[0];
    float min_dist = (float)REAL(s_min_dist)[0];

    /* Convert R column-major double matrix to row-major float[n*3]. */
    float *pos = (float*) R_alloc((size_t)n_nodes * 3, sizeof(float));
    double *src = REAL(s_pos);
    for (int i = 0; i < n_nodes; i++) {
        pos[3*i + 0] = (float)src[i + 0 * n_nodes];
        pos[3*i + 1] = (float)src[i + 1 * n_nodes];
        pos[3*i + 2] = (float)src[i + 2 * n_nodes];
    }

    int *ef = NULL, *et = NULL;
    if (n_edges > 0) {
        ef = (int*) R_alloc((size_t)n_edges, sizeof(int));
        et = (int*) R_alloc((size_t)n_edges, sizeof(int));
        int *src_e = INTEGER(s_edges);
        for (int i = 0; i < n_edges; i++) {
            ef[i] = src_e[i + 0 * n_edges] - 1; /* 1-based to 0-based */
            et[i] = src_e[i + 1 * n_edges] - 1;
            if (ef[i] < 0 || ef[i] >= n_nodes ||
                et[i] < 0 || et[i] >= n_nodes) {
                Rf_error("cgvR: edge index out of range");
            }
        }
    }

    /* Octree storage — preallocated 8*n + 1024. */
    int capacity = 8 * n_nodes + 1024;
    OctNode *nodes = (OctNode*) R_alloc((size_t)capacity, sizeof(OctNode));
    Octree tree = {
        .nodes = nodes,
        .capacity = capacity,
        .n_used = 0,
        .theta = theta,
        .min_dist = min_dist,
        .k2 = ideal_len * ideal_len,
    };

    float *disp = (float*) R_alloc((size_t)n_nodes * 3, sizeof(float));
    float temp = ideal_len * 2.0f;

    for (int it = 0; it < n_iter; it++) {
        /* Build bbox over current positions. */
        float bmin[3] = {pos[0], pos[1], pos[2]};
        float bmax[3] = {pos[0], pos[1], pos[2]};
        for (int i = 1; i < n_nodes; i++) {
            for (int a = 0; a < 3; a++) {
                float v = pos[3*i + a];
                if (v < bmin[a]) bmin[a] = v;
                if (v > bmax[a]) bmax[a] = v;
            }
        }
        /* Inflate slightly so points on the edge land inside. */
        for (int a = 0; a < 3; a++) {
            float pad = 0.001f * (bmax[a] - bmin[a]) + 1e-3f;
            bmin[a] -= pad; bmax[a] += pad;
        }

        /* Build tree. */
        tree.n_used = 0;
        int root = alloc_node(&tree, bmin, bmax);
        for (int i = 0; i < n_nodes; i++) {
            insert(&tree, root, i, pos, n_nodes);
        }

        /* Repulsion via BH. */
        memset(disp, 0, (size_t)n_nodes * 3 * sizeof(float));
        for (int i = 0; i < n_nodes; i++) {
            float p[3] = {pos[3*i + 0], pos[3*i + 1], pos[3*i + 2]};
            float f[3] = {0, 0, 0};
            accumulate(&tree, root, p, i, f);
            disp[3*i + 0] += f[0];
            disp[3*i + 1] += f[1];
            disp[3*i + 2] += f[2];
        }

        /* Attraction along edges: F = d^2 / k, vector ∝ (a - b)/d * d^2/k. */
        for (int e = 0; e < n_edges; e++) {
            int a = ef[e], b = et[e];
            float dx = pos[3*b + 0] - pos[3*a + 0];
            float dy = pos[3*b + 1] - pos[3*a + 1];
            float dz = pos[3*b + 2] - pos[3*a + 2];
            float d  = sqrtf(dx*dx + dy*dy + dz*dz);
            if (d < min_dist) d = min_dist;
            float coef = d / ideal_len;     /* (d^2 / k) / d */
            float fx = dx * coef, fy = dy * coef, fz = dz * coef;
            disp[3*a + 0] += fx;
            disp[3*a + 1] += fy;
            disp[3*a + 2] += fz;
            disp[3*b + 0] -= fx;
            disp[3*b + 1] -= fy;
            disp[3*b + 2] -= fz;
        }

        /* Apply with temperature clipping. */
        for (int i = 0; i < n_nodes; i++) {
            float dx = disp[3*i + 0];
            float dy = disp[3*i + 1];
            float dz = disp[3*i + 2];
            float dl = sqrtf(dx*dx + dy*dy + dz*dz);
            if (dl < 1e-6f) continue;
            float scale = (dl < temp) ? 1.0f : (temp / dl);
            pos[3*i + 0] += dx * scale;
            pos[3*i + 1] += dy * scale;
            pos[3*i + 2] += dz * scale;
        }

        temp *= cool;

        /* Allow user interrupt every 25 iterations. */
        if ((it & 31) == 31) R_CheckUserInterrupt();
    }

    /* Return as n_nodes x 3 numeric matrix (column-major). */
    SEXP out = PROTECT(Rf_allocMatrix(REALSXP, n_nodes, 3));
    double *dst = REAL(out);
    for (int i = 0; i < n_nodes; i++) {
        dst[i + 0 * n_nodes] = (double)pos[3*i + 0];
        dst[i + 1 * n_nodes] = (double)pos[3*i + 1];
        dst[i + 2 * n_nodes] = (double)pos[3*i + 2];
    }
    UNPROTECT(1);
    return out;
}
