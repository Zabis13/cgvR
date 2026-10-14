#!/usr/bin/env Rscript
# Prototype: shelves of the cube move map as cosets of the per-axis abelian
# subgroups. One start, 5 methods, as in demo_cube3_solutions.R.
#
# H_x = <R, M, L>, H_y = <U, E, D>, H_z = <F, S, B>, each Z4^3 (64 elements).
# A shelf is a coset s*H_a; its id is the canonical representative (the
# smallest state of the 64). Every state lies in exactly three shelves, one
# per axis, so the split is a property of the Cayley graph, not of the paths.
#
# A run of same-axis moves stays on one shelf. Inside a shelf a state sits on
# a 4x4x4 grid at its move counts mod 4 relative to the representative. On an
# axis change the path moves to another shelf through the same state: the two
# placements of that state are joined by a white teleport edge.
#
# Shelf positions: the shelf graph (shelves = nodes, teleports = edges) is laid
# out with cgv_layout_fr_bh, and each shelf's grid is drawn around its point.
#
# Env: SHELF_SPACING=<distance between neighbouring shelves in grid cells,
#                     default 4>
#      SHELF_GRID=1   also draw the empty grid points of every shelf (faint)
#
# Run with:  Rscript inst/examples/demo_cube3_cosets.R
suppressMessages({ library(cayleyR) })

N <- 3L; n_moves <- 985L
set.seed(2026)
g <- cube_group(N)
methods <- c("KociembaMod", "CFOP", "LBL", "M2", "OldPochmann")
solver <- list(
  KociembaMod = function(s) list(path = cube_kociemba(s)$path),
  CFOP = cube_solve_cfop, LBL = cube_solve_lbl,
  M2 = cube_solve_m2, OldPochmann = cube_solve_old_pochmann)
key_fn <- function(s) paste(as.integer(s), collapse = " ")

st <- generate_state(group = g, n_moves = n_moves)
walks <- list()
for (m in methods) {
  r <- try(solver[[m]](st), silent = TRUE)
  if (inherits(r, "try-error") || length(r$path) == 0L) next
  states <- vector("list", length(r$path) + 1L)
  states[[1]] <- s <- st
  for (i in seq_along(r$path)) states[[i + 1L]] <- s <- group_apply(g, s, r$path[i])
  walks[[m]] <- list(moves = r$path, states = states,
                     keys = vapply(states, key_fn, ""))
}

# ── Cosets ────────────────────────────────────────────
# group_apply(g, s, m) == s[perm[[m]]], so the 64 elements of s*H_a are
# s[P] for the 64 composed permutations P of H_a.
axes <- list(x = c("R", "M", "L"), y = c("U", "E", "D"), z = c("F", "S", "B"))
axis_of <- setNames(rep(names(axes), each = 3L), unlist(axes))
id <- seq_len(6L * N * N)
perm <- lapply(setNames(nm = unlist(axes)), function(m) group_apply(g, id, m))
# H_a as 64 permutations, with exponents (i, j, k) of its three generators.
coset_perms <- lapply(axes, function(gen) {
  ex <- expand.grid(i = 0:3, j = 0:3, k = 0:3)
  pw <- function(m, e) { p <- id; for (t in seq_len(e)) p <- p[perm[[m]]]; p }
  P <- lapply(seq_len(nrow(ex)), function(r)
    pw(gen[1], ex$i[r])[pw(gen[2], ex$j[r])][pw(gen[3], ex$k[r])])
  stopifnot(length(unique(vapply(P, key_fn, ""))) == 64L)
  list(P = P, ex = as.matrix(ex))
})

# Shelf of state s on axis a: representative key and the grid cell of s.
# rep = s*h(e0) => s = rep*h(-e0), so s sits at -e0 mod 4.
shelf_cache <- new.env()
shelf_of <- function(s, a) {
  ck <- paste(a, key_fn(s))
  if (!is.null(r <- shelf_cache[[ck]])) return(r)
  cp <- coset_perms[[a]]
  M <- vapply(cp$P, function(p) as.integer(s[p]), integer(length(s)))
  best <- do.call(order, as.data.frame(t(M)))[1]
  r <- list(rep = key_fn(M[, best]), cell = (-cp$ex[best, ]) %% 4L)
  shelf_cache[[ck]] <- r
  r
}

# ── Placements ────────────────────────────────────────
# One placement per (state, shelf). A step with axis a joins the placements of
# both its states on their common a-shelf.
pl <- data.frame(state = character(0), axis = character(0), shelf = character(0),
                 c1 = integer(0), c2 = integer(0), c3 = integer(0))
pl_key <- character(0)
place <- function(s, k, a) {
  sh <- shelf_of(s, a)
  pk <- paste(k, a)
  i <- match(pk, pl_key)
  if (is.na(i)) {
    pl[nrow(pl) + 1L, ] <<- list(k, a, paste(a, sh$rep), sh$cell[1], sh$cell[2],
                                 sh$cell[3])
    pl_key <<- c(pl_key, pk)
    i <- length(pl_key)
  }
  i
}
step_e <- list()
for (m in names(walks)) {
  w <- walks[[m]]
  ax <- axis_of[substr(w$moves, 1L, 1L)]
  if (anyNA(ax)) stop("unknown move axis")
  for (i in seq_along(w$moves)) {
    a <- ax[[i]]
    step_e[[length(step_e) + 1L]] <- data.frame(
      from = place(w$states[[i]], w$keys[i], a),
      to = place(w$states[[i + 1L]], w$keys[i + 1L], a), method = m)
  }
}
step_e <- do.call(rbind, step_e)
step_e <- step_e[!duplicated(step_e), ]

# Teleports: the placements of one state on different shelves, chained.
by_state <- split(seq_len(nrow(pl)), pl$state)
by_state <- by_state[lengths(by_state) > 1L]
tf <- unlist(lapply(by_state, function(i) i[-length(i)]))
tt <- unlist(lapply(by_state, function(i) i[-1L]))

# ── Report ────────────────────────────────────────────
shelves <- unique(pl$shelf)
shelf_axis <- substr(shelves, 1L, 1L)
cat(sprintf("placements=%d  distinct states=%d  shelves=%d  teleport edges=%d\n",
            nrow(pl), length(unique(pl$state)), length(shelves), length(tf)))
print(table(axis = shelf_axis))
sh_methods <- tapply(step_e$method, pl$shelf[step_e$from],
                     function(x) length(unique(x)))
cat(sprintf("shelves shared by >1 method: %d\n", sum(sh_methods > 1L)))
cat("shelf changes (axis changes) per method:\n")
print(vapply(walks, function(w) {
  ax <- axis_of[substr(w$moves, 1L, 1L)]
  sum(ax[-1] != ax[-length(ax)])
}, integer(1)))
cat("states per shelf:\n")
print(summary(as.vector(table(pl$shelf))))

# ── Layout ────────────────────────────────────────────
suppressMessages(library(cgvR))
sh_id <- match(pl$shelf, shelves)
se <- unique(t(apply(cbind(sh_id[tf], sh_id[tt]), 1, sort)))
se <- se[se[, 1] != se[, 2], , drop = FALSE]
cen <- cgv_layout_fr_bh(length(shelves), se, n_iter = 500L, seed = 1L)
# Scale so that neighbouring shelves are SHELF_SPACING cells apart (median).
spacing <- as.numeric(Sys.getenv("SHELF_SPACING", "4"))
if (nrow(se) > 0L) {
  el <- sqrt(rowSums((cen[se[, 1], , drop = FALSE] - cen[se[, 2], , drop = FALSE])^2))
  cen <- cen * spacing / median(el)
}
cell <- as.matrix(pl[c("c1", "c2", "c3")]) - 1.5
# Grid axes follow the generators: x-shelves (R,M,L) along x,y,z in that order;
# y-shelves (U,E,D) and z-shelves (F,S,B) the same, so all grids are aligned.
pos <- cen[sh_id, , drop = FALSE] + cell

# ── Drawing ───────────────────────────────────────────
method_color <- c(KociembaMod = "#FF3333", CFOP = "#FFAA00", LBL = "#33DD33",
                  M2 = "#33AAFF", OldPochmann = "#DD55FF")
axis_color <- c(x = "#B07070", y = "#70B070", z = "#7070B0")
rgba <- function(hex, alpha = 255L) c(as.integer(col2rgb(hex)), alpha)
rows <- function(hex, n, alpha = 255L) matrix(rgba(hex, alpha), n, 4, byrow = TRUE)

node_rgba <- t(vapply(pl$axis, function(a) rgba(axis_color[[a]]), integer(4)))
node_size <- rep(3, nrow(pl))
tele_ids <- unlist(by_state)
node_rgba[tele_ids, ] <- rows("#FFFFFF", length(tele_ids))
node_size[tele_ids] <- 5
solved_ids <- which(pl$state == key_fn(id))
node_rgba[solved_ids, ] <- rows("#FFFF00", length(solved_ids))
node_size[solved_ids] <- 14
start_ids <- which(pl$state == key_fn(st))
node_rgba[start_ids, ] <- rows("#00FFFF", length(start_ids))
node_size[start_ids] <- 10

edges <- rbind(as.matrix(step_e[c("from", "to")]), cbind(tf, tt))
edge_rgba <- rbind(t(vapply(step_e$method, function(m) rgba(method_color[[m]]),
                            integer(4))),
                   rows("#FFFFFF", length(tf), 160L))

# Optional faint grid: the 64 cells of every shelf.
if (Sys.getenv("SHELF_GRID", "0") == "1") {
  gc <- as.matrix(expand.grid(0:3, 0:3, 0:3)) - 1.5
  gpos <- do.call(rbind, lapply(seq_along(shelves), function(k)
    sweep(gc, 2, cen[k, ], "+")))
  pos <- rbind(pos, gpos)
  node_rgba <- rbind(node_rgba, rows("#404040", nrow(gpos)))
  node_size <- c(node_size, rep(1.5, nrow(gpos)))
}

cat(sprintf("Graph: %d nodes, %d step edges, %d teleport edges\n",
            nrow(pos), nrow(step_e), length(tf)))
v <- cgv_viewer(1280, 720, sprintf("Cube 3x3x3 cosets: %d shelves", length(shelves)))
cgv_background(v, "black")
cgv_set_graph(v, seq_len(nrow(pos)), edges, positions = pos,
              node_colors = node_rgba, node_sizes = as.double(node_size))
cgv_set_edge_colors(v, edge_rgba)

cat("\nColors:\n")
for (m in names(method_color)) cat(sprintf("  %-12s %s\n", m, method_color[[m]]))
cat("  nodes = shelf axis (x red, y green, z blue), teleports white,\n")
cat("  start cyan, solved cube yellow\n")

# Fit the whole graph: bounding sphere around the box center, seen with the
# default vertical fov of 45 deg (the vertical side is the tighter one at 16:9).
cm <- (apply(pos, 2, min) + apply(pos, 2, max)) / 2
rad <- max(sqrt(rowSums(sweep(pos, 2, cm)^2)))
dd <- rad / sin(pi / 8) * 1.05
dir <- c(0.7, 0.6, 0.8) / sqrt(sum(c(0.7, 0.6, 0.8)^2))
cgv_camera(v, position = cm + dd * dir, target = cm)
cat("Right mouse drag = rotate, scroll = zoom. Close window to exit.\n")
cgv_run(v)
