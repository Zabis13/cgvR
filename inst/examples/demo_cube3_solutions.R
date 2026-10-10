#!/usr/bin/env Rscript
# cgvR demo — the solutions of the 3x3x3 from cayleyR's demo_cube3_solve.R
# (n_states random states x 5 methods) drawn as one graph, one line per solve,
# colored by method. States where two or more lines meet or part are
# highlighted; with show_nb, the BFS-1 neighbours of every state are drawn too.
# Two views, chosen with CUBE_VIEW:
#
#   fr            every state is a node, merged by key, so the start states
#                 and the solved cube are shared hubs.
#                 Barnes-Hut Fruchterman-Reingold layout.
#   spindle (default)  on the same merged graph, from real closeness
#                 between states (stickers in which they differ): height =
#                 distance to the solved cube, the two cross coordinates =
#                 MDS of that distance with the distance-to-solved part
#                 regressed out.
#   celestial     each solve is its own curve on the celestial sphere, as in
#                 TopSpin's convert_LRX_to_celestial, with the cube's moves
#                 counted by axis: x = R L M, y = U D E, z = F B S, a
#                 clockwise turn +1 and a prime turn -1. Counts run backwards
#                 from the solved cube, so it sits at the origin. Coordinates
#                 depend on the path, so each solve keeps its own copies of
#                 its states. No layout.
#
# Run with:  Rscript inst/examples/demo_cube3_solutions.R
#            CUBE_VIEW=fr Rscript inst/examples/demo_cube3_solutions.R
#            CUBE_VIEW=celestial Rscript inst/examples/demo_cube3_solutions.R
library(cayleyR)
library(cgvR)

view <- Sys.getenv("CUBE_VIEW", "celestial")
if (!view %in% c("spindle", "celestial", "fr"))
  stop("CUBE_VIEW must be spindle, celestial or fr")

# Same parameters and seed as demo_cube3_solve.R, so the states are the same.
N             <- 3L
n_states      <- 1L
n_moves       <- 985L
show_nb      <- FALSE   # draw the BFS-1 neighbours of every path state

set.seed(2026)
g <- cube_group(N)

methods <- c("KociembaMod", "CFOP", "LBL", "M2", "OldPochmann")
method_color <- c(KociembaMod = "#FF3333", CFOP = "#FFAA00", LBL = "#33DD33",
                  M2 = "#33AAFF", OldPochmann = "#DD55FF")
solver <- list(
  KociembaMod = function(s) list(path = cube_kociemba(s)$path),
  CFOP        = cube_solve_cfop,
  LBL         = cube_solve_lbl,
  M2          = cube_solve_m2,
  OldPochmann = cube_solve_old_pochmann)

# ── Solve ─────────────────────────────────────────────
key_fn <- function(s) paste(as.integer(s), collapse = " ")

# State keys along a word, start included.
walk_keys <- function(state, path) {
  keys <- character(length(path) + 1L)
  keys[1] <- key_fn(state)
  for (i in seq_along(path)) {
    state <- group_apply(g, state, path[i])
    keys[i + 1L] <- key_fn(state)
  }
  keys
}

walks <- list()   # each: method, traj, moves, keys
start_keys <- character(0)
for (i in seq_len(n_states)) {
  st <- generate_state(group = g, n_moves = n_moves)
  start_keys <- c(start_keys, key_fn(st))
  for (m in methods) {
    r <- try(solver[[m]](st), silent = TRUE)
    if (inherits(r, "try-error") || length(r$path) == 0L) {
      cat(sprintf("state %2d  %-12s FAILED\n", i, m)); next
    }
    cat(sprintf("state %2d  %-12s %4d moves\n", i, m, length(r$path)))
    walks[[length(walks) + 1L]] <- list(method = m, traj = paste(i, m),
                                        moves = r$path,
                                        keys = walk_keys(st, r$path))
  }
}
solved_key <- key_fn(seq_len(6L * N * N))
move_names <- cube_move_names(N)

# ── Intersections: states on >= 2 trajectories ────────
# A trajectory is one solve, a (start, method) pair; neighbours do not count.
# The starts and the solved cube are shared by construction and are left out.
key_traj <- unique(data.frame(
  key  = unlist(lapply(walks, `[[`, "keys")),
  traj = unlist(lapply(walks, function(w) rep(w$traj, length(w$keys))))))
n_traj <- table(key_traj$key)
shared_keys <- setdiff(names(n_traj)[n_traj >= 2L], c(start_keys, solved_key))

# Trajectories often run together for many moves; only the ends of such a
# shared run are highlighted -- the states where the set of trajectories
# passing through changes from one step to the next along some walk.
traj_set <- tapply(key_traj$traj, key_traj$key,
                   function(x) paste(sort(x), collapse = "|"))
cross_keys <- character(0)
for (w in walks) {
  ts <- traj_set[w$keys]
  k  <- length(ts)
  junction <- c(TRUE, ts[-1] != ts[-k]) | c(ts[-k] != ts[-1], TRUE)
  cross_keys <- c(cross_keys, w$keys[junction & w$keys %in% shared_keys])
}
cross_keys <- unique(cross_keys)
cat(sprintf("Intersections: %d states on >= 2 trajectories, %d junctions\n",
            length(shared_keys), length(cross_keys)))

rgba <- function(hex, alpha = 255L) c(as.integer(col2rgb(hex)), alpha)
nb_node_rgba <- rgba("#666666")
nb_edge_rgba <- c(80L, 80L, 80L, 100L)
nb_size      <- 1.5

# ── Graph: one node per state, merged by key ──────────
path_keys <- unique(unlist(lapply(walks, `[[`, "keys")))
uniq_keys <- path_keys
n_path    <- length(path_keys)

ef <- integer(0); et <- integer(0); emeth <- character(0)
for (w in walks) {
  ids <- match(w$keys, uniq_keys)
  k <- length(ids)
  if (k < 2L) next
  ef <- c(ef, ids[-k]); et <- c(et, ids[-1])
  emeth <- c(emeth, rep(w$method, k - 1L))
}
# Dedup undirected edges; a shared edge keeps the first method's color.
ekeys <- ifelse(ef < et, paste(ef, et), paste(et, ef))
keep  <- !duplicated(ekeys) & ef != et
edges <- cbind(ef[keep], et[keep])
emeth <- emeth[keep]
path_ekeys <- ekeys[keep]
path_edges <- edges

edge_rgba <- t(vapply(emeth, function(m) rgba(method_color[[m]]),
                      integer(4)))

# Node: method color of the first walk it appears in; hubs override.
node_meth <- rep(NA_character_, n_path)
for (w in walks) {
  ids <- match(w$keys, uniq_keys)
  node_meth[ids[is.na(node_meth[ids])]] <- w$method
}
node_rgba <- t(vapply(node_meth, function(m) rgba(method_color[[m]]),
                      integer(4)))

n_nodes   <- n_path
node_size <- rep(3, n_path)

# BFS-1 neighbours of every path state, merged by key like the rest; a
# neighbour that is itself a path state just adds an edge between the two.
if (show_nb) {
  nb_keys <- lapply(path_keys, function(key) {
    s <- as.integer(strsplit(key, " ", fixed = TRUE)[[1]])
    vapply(move_names, function(m) key_fn(group_apply(g, s, m)), character(1))
  })
  nb_from <- rep(seq_len(n_path), lengths(nb_keys))
  nb_move <- rep(seq_along(move_names), n_path)
  nb_keys <- unlist(nb_keys, use.names = FALSE)
  uniq_keys <- c(path_keys, setdiff(unique(nb_keys), path_keys))
  n_nodes   <- length(uniq_keys)
  nb_to <- match(nb_keys, uniq_keys)
  nek   <- ifelse(nb_from < nb_to, paste(nb_from, nb_to),
                  paste(nb_to, nb_from))
  nkeep <- !duplicated(nek) & !(nek %in% path_ekeys) & nb_from != nb_to
  # Neighbour edges first, so the paths are drawn over them.
  edges <- rbind(cbind(nb_from[nkeep], nb_to[nkeep]), edges)
  edge_rgba <- rbind(matrix(nb_edge_rgba, sum(nkeep), 4, byrow = TRUE),
                     edge_rgba)
  node_rgba <- rbind(node_rgba,
                     matrix(nb_node_rgba, n_nodes - n_path, 4, byrow = TRUE))
  node_size <- c(node_size, rep(nb_size, n_nodes - n_path))
}
cross_ids <- match(cross_keys, uniq_keys)
start_ids <- match(start_keys, uniq_keys)
solved_id <- match(solved_key, uniq_keys)

if (view == "fr") {
  start_size <- 14
  set.seed(1L)
  pos <- cgv_layout_fr_bh(n_nodes, edges, n_iter = 300L, theta = 1.0,
                          cool = 0.98, min_dist = 0.01)
} else if (view == "celestial") {
  # ── Celestial: one curve per walk, solved cube shared at the origin ──
  # Coordinates depend on the path, not the state, so this view does not use
  # the merged graph: every walk gets its own copy of its states.
  axis_of <- c(R = "x", L = "x", M = "x", U = "y", D = "y", E = "y",
               F = "z", B = "z", S = "z")

  cel_xyz <- function(nx, ny, nz) {
    cc <- convert_LRX_to_celestial(nx, ny, nz)
    r <- cc$omega_conformal
    c(r * sin(cc$theta) * cos(cc$phi),
      r * sin(cc$theta) * sin(cc$phi),
      r * cos(cc$theta))
  }
  # Signed weight of a move: +1 clockwise, -1 prime.
  move_sign <- function(moves) ifelse(endsWith(moves, "'"), -1, 1)

  # BFS-1 neighbours of a node with counts (nx, ny, nz). The way back from a
  # neighbour reached by move m starts with m's inverse, so its count on m's
  # axis changes by -sign(m); the 18 neighbours fall on 6 points.
  move_axis <- axis_of[substr(move_names, 1L, 1L)]
  move_sgn  <- move_sign(move_names)
  nb_xyz <- function(nx, ny, nz) {
    t(vapply(seq_along(move_axis), function(i) {
      a <- move_axis[i]; d <- -move_sgn[i]
      cel_xyz(nx + d * (a == "x"), ny + d * (a == "y"), nz + d * (a == "z"))
    }, numeric(3)))
  }

  # Node 1 is the solved cube; every walk adds its own nodes for the rest.
  pos <- list(c(0, 0, 0))
  node_rgba <- list(rgba("#FFFF00"))
  node_key  <- solved_key
  cnt <- list(c(0, 0, 0))   # per-axis counts of each path node
  ef <- integer(0); et <- integer(0); ecol <- list()
  start_ids <- integer(0)
  next_id <- 2L
  for (w in walks) {
    ax <- axis_of[substr(w$moves, 1L, 1L)]
    if (anyNA(ax)) stop("unknown move axis: ",
                        paste(unique(w$moves[is.na(ax)]), collapse = " "))
    # Moves from each node to the solved cube, signed and counted per axis.
    sg <- move_sign(w$moves)
    nx <- rev(cumsum(rev(sg * (ax == "x"))))
    ny <- rev(cumsum(rev(sg * (ax == "y"))))
    nz <- rev(cumsum(rev(sg * (ax == "z"))))
    k <- length(w$moves)
    xyz <- t(vapply(seq_len(k), function(j) cel_xyz(nx[j], ny[j], nz[j]),
                    numeric(3)))
    ids <- c(next_id + seq_len(k) - 1L, 1L)
    next_id <- next_id + k
    start_ids <- c(start_ids, ids[1])
    col <- rgba(method_color[[w$method]])
    pos <- c(pos, split(xyz, row(xyz)))
    cn  <- cbind(nx, ny, nz)
    cnt <- c(cnt, split(cn, row(cn)))
    node_rgba <- c(node_rgba, rep(list(col), k))
    node_key  <- c(node_key, w$keys[seq_len(k)])
    ef <- c(ef, ids[-length(ids)]); et <- c(et, ids[-1])
    ecol <- c(ecol, rep(list(col), k))
  }
  n_path <- next_id - 1L

  # Neighbours of every path node, the solved cube included.
  pc <- do.call(rbind, pos)
  n_nb <- if (show_nb) length(move_names) else 0L
  nb_pos <- if (show_nb) {
    do.call(rbind, lapply(cnt, function(c3) nb_xyz(c3[1], c3[2], c3[3])))
  } else matrix(numeric(0), 0, 3)
  nb_ids <- n_path + seq_len(nrow(nb_pos))
  # Neighbour edges first, so the paths are drawn over them.
  edges <- rbind(cbind(rep(seq_len(n_path), each = n_nb), nb_ids),
                 cbind(ef, et))
  edge_rgba <- rbind(matrix(rep(nb_edge_rgba, each = length(nb_ids)), ncol = 4),
                     do.call(rbind, ecol))
  pos <- rbind(pc, nb_pos)
  # Normalize to a compact scale, as in demo_path_coords.R.
  pos <- pos / max(sqrt(rowSums(pos^2))) * 10
  node_rgba <- rbind(do.call(rbind, node_rgba),
                     matrix(rep(nb_node_rgba, each = length(nb_ids)), ncol = 4))
  n_nodes <- nrow(pos)
  node_size <- c(rep(2, n_path), rep(nb_size, length(nb_ids)))
  cross_ids <- which(node_key %in% cross_keys)
  solved_id <- 1L
  start_size <- 8
} else {
  # ── Spindle + MDS: real closeness between states ──
  # Distance between two states: the number of stickers (of 54) in which they
  # differ. Along the axis: distance to the solved cube (solved at z = +H).
  # Across it: classical MDS on the same distance, with the part that only
  # repeats the distance to solved regressed out, so the two cross coordinates
  # show how states differ beyond being more or less solved. MDS runs on up
  # to n_landmarks path states; every node is then placed by landmark MDS
  # (de Silva & Tenenbaum), so neighbours need no special handling.
  H           <- 10      # half-length of the spindle
  R           <- 6       # largest distance from the axis
  n_landmarks <- 1500L

  st_mat <- do.call(rbind, lapply(strsplit(uniq_keys, " ", fixed = TRUE),
                                  as.integer))
  hamming <- function(A, B) {   # every row of A against every row of B
    d <- matrix(0, nrow(A), nrow(B))
    for (cc in seq_len(ncol(A))) d <- d + outer(A[, cc], B[, cc], "!=")
    d
  }
  h <- hamming(st_mat, matrix(seq_len(ncol(st_mat)), 1L))[, 1]

  set.seed(1L)
  lm_ids <- if (n_path <= n_landmarks) seq_len(n_path)
            else sort(sample(n_path, n_landmarks))
  lm_mat <- st_mat[lm_ids, , drop = FALSE]
  D2  <- hamming(lm_mat, lm_mat)^2
  mds <- cmdscale(sqrt(D2), k = 3L, eig = TRUE)
  k   <- ncol(mds$points)
  Lsharp <- t(mds$points) / mds$eig[seq_len(k)]
  d2_mean <- colMeans(D2)
  # Project in chunks so the node x landmark matrix stays small.
  emb <- do.call(rbind, lapply(split(seq_len(n_nodes),
                                     ceiling(seq_len(n_nodes) / 5000)),
    function(rows) {
      d2 <- hamming(st_mat[rows, , drop = FALSE], lm_mat)^2
      t(-0.5 * Lsharp %*% (t(d2) - d2_mean))
    }))

  cross <- prcomp(residuals(lm(emb ~ h)))$x[, 1:2, drop = FALSE]
  cross <- sweep(cross, 2L, cross[solved_id, ])
  cross <- cross / max(sqrt(rowSums(cross^2))) * R
  pos <- cbind(cross, H * (1 - 2 * h / max(h)))
  start_size <- 8
}
cat(sprintf("View: %s.  Graph: %d nodes, %d edges\n",
            view, n_nodes, nrow(edges)))

node_rgba[cross_ids, ] <- matrix(rgba("#00FFFF"), length(cross_ids), 4,
                                 byrow = TRUE)
node_size[cross_ids] <- 7
node_rgba[start_ids, ] <- matrix(rgba("#FFFFFF"), length(start_ids), 4,
                                 byrow = TRUE)
node_size[start_ids] <- start_size
node_rgba[solved_id, ] <- rgba("#FFFF00")
node_size[solved_id] <- 20

# ── Visualization ─────────────────────────────────────
v <- cgv_viewer(1280, 720,
                sprintf("Cube 3x3x3: 50 solutions (10 states x 5 methods), %s",
                        view))
cgv_background(v, "black")

cgv_set_graph(v, seq_len(n_nodes), edges,
              positions   = pos,
              node_colors = node_rgba,
              node_sizes  = as.double(node_size))
cgv_set_edge_colors(v, edge_rgba)

cat("\nColors:\n")
for (m in methods) cat(sprintf("  %-12s %s\n", m, method_color[[m]]))
cat("  start states  white,  solved cube  yellow\n")
cat("  intersections cyan,   BFS-1 neighbours  grey\n")

# ── Camera ────────────────────────────────────────────
cm <- colMeans(pos)
dd <- max(sqrt(rowSums(sweep(pos, 2, cm)^2))) * 2
cgv_camera(v, position = cm + c(dd * 0.7, dd * 0.6, dd * 0.8), target = cm)

cat("Right mouse drag = rotate, scroll = zoom. Close window to exit.\n")
cgv_run(v)
