#!/usr/bin/env Rscript
# Prototype: split the move map of the cube solutions into sheets (model A,
# path continuity). One start, 5 methods, as in demo_cube3_solutions.R.
#
# Position of a path point = per-axis signed move counts from that point to
# the solved cube (solved at the origin). Points are processed per walk, from
# the solved end toward the start, walks in fixed order.
#
# Sheets ("shelves"): a fixed number K of them. Each walk is laid out by
# Viterbi: a point on a sheet costs the number of other states at its position
# there (collision), a sheet switch costs SWITCH_COST. The point before a
# switch is copied onto the new sheet and becomes a teleport. Collisions left
# inside a sheet are drawn red.
#
# Env: AXES=3|9  DOUBLE=1|2  MOD4=0|1
#      SHEETS_K=<number of sheets, default max states per position>
#      SWITCH_COST=<cost of a sheet switch in collisions, default 10>
#      SHEETS_OUT=<dir for the CSV, default tempdir()>
#      SHEET_GAP=<z step between sheets, default 1>
#      FAN_DEG=<with SHEETS_K=1 and AXES=9: fan angle of R/L around x etc., default 20>
#
# Run with:  Rscript inst/examples/demo_cube3_sheets.R
#            AXES=9 SHEET_GAP=2 Rscript inst/examples/demo_cube3_sheets.R
#            SHEETS_K=1 Rscript inst/examples/demo_cube3_sheets.R   # bare lattice
suppressMessages({ library(cayleyR) })

n_axes  <- as.integer(Sys.getenv("AXES", "3"))
w_dbl   <- as.integer(Sys.getenv("DOUBLE", "2"))
use_mod <- Sys.getenv("MOD4", "0") == "1"
stopifnot(n_axes %in% c(3L, 9L))

N <- 3L; n_moves <- 985L
set.seed(2026)
g <- cube_group(N)
methods <- c("KociembaMod", "CFOP", "LBL", "M2", "OldPochmann")
solver <- list(
  KociembaMod = function(s) list(path = cube_kociemba(s)$path),
  CFOP = cube_solve_cfop, LBL = cube_solve_lbl,
  M2 = cube_solve_m2, OldPochmann = cube_solve_old_pochmann)
key_fn <- function(s) paste(as.integer(s), collapse = " ")
walk_keys <- function(state, path) {
  keys <- character(length(path) + 1L)
  keys[1] <- key_fn(state)
  for (i in seq_along(path)) {
    state <- group_apply(g, state, path[i])
    keys[i + 1L] <- key_fn(state)
  }
  keys
}

st <- generate_state(group = g, n_moves = n_moves)
walks <- list()
for (m in methods) {
  r <- try(solver[[m]](st), silent = TRUE)
  if (inherits(r, "try-error") || length(r$path) == 0L) next
  walks[[m]] <- list(moves = r$path, keys = walk_keys(st, r$path))
}

# ── Counts per axis ───────────────────────────────────
axis_names <- if (n_axes == 3L) c("x", "y", "z") else
  c("R", "L", "M", "U", "D", "E", "F", "B", "S")
axis_of <- if (n_axes == 3L)
  c(R = "x", L = "x", M = "x", U = "y", D = "y", E = "y",
    F = "z", B = "z", S = "z") else setNames(axis_names, axis_names)
move_weight <- function(mv) ifelse(endsWith(mv, "'"), -1L,
                            ifelse(endsWith(mv, "2"), w_dbl, 1L))

# Counts of points 0..k, point 0 = solved (walk reversed), as a matrix.
walk_counts <- function(moves) {
  ax <- axis_of[substr(moves, 1L, 1L)]
  if (anyNA(ax)) stop("unknown move axis")
  wt <- move_weight(moves)
  cn <- vapply(axis_names, function(a) rev(cumsum(rev(wt * (ax == a)))),
               numeric(length(moves)))
  cn <- rbind(matrix(cn, ncol = n_axes), 0)   # solved at the end
  cn <- cn[nrow(cn):1, , drop = FALSE]          # solved first
  if (use_mod) cn <- cn %% 4
  cn
}

# ── Sheets ────────────────────────────────────────────
# Viterbi on each walk over K sheets: cost = collisions + switch_cost per sheet
# switch. Walks are re-optimized in turn against the current placement of all
# points (other walks and the walk's own previous placement) until nothing
# changes, at most max_rounds rounds.
viterbi <- function(C, W) {
  n <- nrow(C); K <- ncol(C)
  dp <- C[1, ]; bp <- matrix(0L, n, K)
  for (j in seq_len(n)[-1]) {
    best <- which.min(dp)
    stay <- dp <= dp[best] + W
    bp[j, ] <- ifelse(stay, seq_len(K), best)
    dp <- pmin(dp, dp[best] + W) + C[j, ]
  }
  s <- integer(n); s[n] <- which.min(dp)
  for (j in rev(seq_len(n)[-1])) s[j - 1L] <- bp[j, s[j]]
  s
}

assign_sheets <- function(walks, K, W, max_rounds = 10L) {
  pts <- do.call(rbind, lapply(names(walks), function(m) {
    keys <- rev(walks[[m]]$keys)          # solved first
    cn <- walk_counts(walks[[m]]$moves)
    data.frame(method = m, step = seq_along(keys) - 1L, state = keys,
               pos = apply(cn, 1, paste, collapse = ","))
  }))
  pts$sheet <- 1L
  # Collisions of a point on each sheet: distinct other states at its position
  # among the points before it (earlier walk, or earlier step of its walk).
  # Only the later point pays, so a colliding pair does not move together.
  by_pos <- split(seq_len(nrow(pts)), pts$pos)
  rivals <- lapply(seq_len(nrow(pts)), function(i) {
    e <- by_pos[[pts$pos[i]]]
    e[e < i & pts$state[e] != pts$state[i]]
  })
  coll <- function(rows) {
    t(vapply(rows, function(i) {
      e <- rivals[[i]]
      if (!length(e)) return(numeric(K))
      n <- tapply(pts$state[e], factor(pts$sheet[e], seq_len(K)),
                  function(x) length(unique(x)))
      n[is.na(n)] <- 0
      as.numeric(n)
    }, numeric(K)))
  }
  for (r in seq_len(max_rounds)) {
    changed <- FALSE
    for (m in names(walks)) {
      rows <- which(pts$method == m)
      s <- viterbi(matrix(coll(rows), ncol = K), W)
      if (!identical(s, pts$sheet[rows])) changed <- TRUE
      pts$sheet[rows] <- s
    }
    if (!changed) break
  }
  attr(pts, "rounds") <- r
  pts$collision <- vapply(seq_len(nrow(pts)), function(i)
    coll(i)[1, pts$sheet[i]] > 0, logical(1))
  sw <- which(pts$step > 0L & pts$sheet != c(NA, pts$sheet[-nrow(pts)]))
  pts$teleport <- FALSE
  pts$teleport[sw - 1L] <- TRUE
  pts
}

pos_all <- unlist(lapply(walks, function(w)
  apply(walk_counts(w$moves), 1, paste, collapse = ",")))
key_all <- unlist(lapply(walks, function(w) rev(w$keys)))
lower <- max(tapply(key_all, pos_all, function(s) length(unique(s))))
K <- as.integer(Sys.getenv("SHEETS_K", lower))
W <- as.numeric(Sys.getenv("SWITCH_COST", "10"))

res <- assign_sheets(walks, K, W)
res2 <- assign_sheets(walks, K, W)
rownames(res) <- NULL

# ── Report ────────────────────────────────────────────
cat(sprintf("AXES=%d DOUBLE=%d MOD4=%d  points=%d  distinct states=%d\n",
            n_axes, w_dbl, use_mod, nrow(res), length(unique(res$state))))
mult <- tapply(res$state, res$pos, function(s) length(unique(s)))
cat(sprintf("max states per position (lower bound on sheets): %d\n",
            max(mult)))
cat(sprintf("K=%d  switch cost=%g  rounds=%d  sheets used: %d\n",
            K, W, attr(res, "rounds"), length(unique(res$sheet))))
cat(sprintf("points with a collision on their sheet: %d\n", sum(res$collision)))
print(table(sheet = res$sheet))
cat(sprintf("cut teleports: %d\n", sum(res$teleport)))
pl <- unique(res[c("state", "sheet", "pos")])
np <- table(pl$state)
cat(sprintf("states with >1 placement (all teleports): %d, max placements: %d\n",
            sum(np > 1), max(np)))
cat("sheet switches per method:\n")
print(tapply(res$sheet, res$method, function(s) sum(diff(s) != 0)))
cat(sprintf("deterministic: %s\n", identical(res, {rownames(res2) <- NULL; res2})))

out_csv <- file.path(Sys.getenv("SHEETS_OUT", tempdir()),
  sprintf("sheets_a%d_d%d_m%d.csv", n_axes, w_dbl, use_mod))
write.csv(res, out_csv, row.names = FALSE)
cat("saved:", out_csv, "\n")

# ── Drawing ───────────────────────────────────────────
# x, y: counts projected with axis i at angle (i-1)*180/n_axes;
# z: sheet number * SHEET_GAP. Node color = sheet, path edge color = method,
# teleports white; white edges join copies of a state stacked across sheets.
suppressMessages(library(cgvR))
gap <- as.numeric(Sys.getenv("SHEET_GAP", "1"))
method_color <- c(KociembaMod = "#FF3333", CFOP = "#FFAA00", LBL = "#33DD33",
                  M2 = "#33AAFF", OldPochmann = "#DD55FF")
rgba <- function(hex, alpha = 255L) c(as.integer(col2rgb(hex)), alpha)
gcd <- function(a, b) if (b == 0L) a else gcd(b, a %% b)

# Placements: every (state, sheet, pos). A sheet switch at step j also puts
# the previous point on the new sheet, so the step edge stays inside a sheet.
sw <- which(res$step > 0L & res$sheet != c(NA, res$sheet[-nrow(res)]))
pl <- unique(rbind(res[c("state", "sheet", "pos")],
                   data.frame(state = res$state[sw - 1L], sheet = res$sheet[sw],
                              pos = res$pos[sw - 1L])))
pl_key <- paste(pl$state, pl$sheet, pl$pos, sep = "|")
node_of <- function(st, sh, p) match(paste(st, sh, p, sep = "|"), pl_key)

# Step edges, colored by method.
nxt <- which(res$step > 0L)
ef <- node_of(res$state[nxt - 1L], res$sheet[nxt], res$pos[nxt - 1L])
et <- node_of(res$state[nxt], res$sheet[nxt], res$pos[nxt])
ecol <- t(vapply(res$method[nxt], function(m) rgba(method_color[[m]]),
                 integer(4)))

# Teleports: states with more than one placement (white nodes). Edges only
# join copies at the same position on different sheets (vertical); copies at
# different positions get no edge, it would span the whole map.
by_state <- split(seq_len(nrow(pl)), pl$state)
by_state <- by_state[lengths(by_state) > 1L]
by_spot <- split(seq_len(nrow(pl)), paste(pl$state, pl$pos))
by_spot <- by_spot[lengths(by_spot) > 1L]
# The start state is the exception: its copies (one per method, each at the
# total count of that method's solution) are chained, showing how far the
# solutions' counts diverge.
start_spot <- which(pl$state == walks[[1]]$keys[1])
by_spot <- c(by_spot, list(start = start_spot))
tf <- unlist(lapply(by_spot, function(i) i[-length(i)]))
tt <- unlist(lapply(by_spot, function(i) i[-1L]))
edges <- rbind(cbind(ef, et), cbind(tf, tt))
edge_rgba <- rbind(ecol, matrix(c(255L, 255L, 255L, 160L), length(tf), 4,
                                byrow = TRUE))

# Positions.
cn <- do.call(rbind, lapply(strsplit(pl$pos, ",", fixed = TRUE), as.numeric))
ang <- (seq_len(n_axes) - 1L) * pi / n_axes
pos <- cbind(cn %*% cos(ang), cn %*% sin(ang), (pl$sheet - 1) * gap)
# One sheet, 3 axes: the bare lattice, counts are the coordinates.
if (K == 1L && n_axes == 3L) pos <- cn
# One sheet, 9 axes: three fans. R, L, M point near x (R tilted by FAN_DEG
# toward y, L away from it, M along x); likewise U, D, E near y (tilt toward
# z) and F, B, S near z (tilt toward x).
if (K == 1L && n_axes == 9L) {
  a <- as.numeric(Sys.getenv("FAN_DEG", "20")) * pi / 180
  e <- diag(3)
  fan <- function(i, j) rbind(cos(a) * e[i, ] + sin(a) * e[j, ],
                              cos(a) * e[i, ] - sin(a) * e[j, ],
                              e[i, ])
  pos <- cn %*% rbind(fan(1, 2), fan(2, 3), fan(3, 1))
}

# Colors and sizes: sheet palette, teleports white, solved yellow.
n_sh <- max(pl$sheet)
# Hue order shuffled by a fixed stride, so neighbouring sheets differ.
hues <- hcl.colors(n_sh, "Dynamic")
stride <- max(1L, round(n_sh * 0.382))
while (n_sh > 1L && gcd(stride, n_sh) != 1L) stride <- stride + 1L
sheet_pal <- t(vapply(hues[(seq_len(n_sh) - 1L) * stride %% n_sh + 1L], rgba,
                      integer(4)))
node_rgba <- sheet_pal[pl$sheet, , drop = FALSE]
node_size <- rep(3, nrow(pl))
tele_ids <- unlist(by_state)
node_rgba[tele_ids, ] <- matrix(rgba("#FFFFFF"), length(tele_ids), 4,
                                byrow = TRUE)
node_size[tele_ids] <- 6
coll_ids <- node_of(res$state, res$sheet, res$pos)[res$collision]
node_rgba[coll_ids, ] <- matrix(rgba("#FF0000"), length(coll_ids), 4,
                                byrow = TRUE)
node_size[coll_ids] <- 5
solved_ids <- which(pl$state == key_fn(seq_len(6L * N * N)))
node_rgba[solved_ids, ] <- matrix(rgba("#FFFF00"), length(solved_ids), 4,
                                  byrow = TRUE)
node_size[solved_ids] <- 14

cat(sprintf("Graph: %d nodes, %d step edges, %d teleport edges\n",
            nrow(pl), length(ef), length(tf)))
v <- cgv_viewer(1280, 720, sprintf("Cube 3x3x3 sheets: %d axes, %d sheets",
                                   n_axes, n_sh))
cgv_background(v, "black")
cgv_set_graph(v, seq_len(nrow(pl)), edges, positions = pos,
              node_colors = node_rgba, node_sizes = as.double(node_size))
cgv_set_edge_colors(v, edge_rgba)

cat("\nColors:\n")
for (m in names(method_color)) cat(sprintf("  %-12s %s\n", m, method_color[[m]]))
cat("  nodes = sheet,  teleports white,  collisions red,  solved cube yellow\n")

cm <- colMeans(pos)
# Fit the bulk of the map (90th percentile), not its farthest points.
dd <- quantile(sqrt(rowSums(sweep(pos, 2, cm)^2)), 0.9, names = FALSE) * 1.2
cgv_camera(v, position = cm + c(dd * 0.7, dd * 0.6, dd * 0.8), target = cm)
cat("Right mouse drag = rotate, scroll = zoom. Close window to exit.\n")
cgv_run(v)
