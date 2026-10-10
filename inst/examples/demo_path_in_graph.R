#!/usr/bin/env Rscript
# cgvR demo — show a found path embedded in a larger cycle graph,
# with every node placed by its celestial coordinates (theta, phi, omega).
# Builds a graph from random cycles (like demo_cycles_bh), reads a path from
# path_coords.csv (see cayleyR::test_bh_path_coords.R), merges the path's
# states/edges into the graph by state key, positions each node on the
# celestial sphere (radius = omega_conformal), and highlights the path.
library(cayleyR)
library(cgvR)

# ── Path data (states + moves) ────────────────────────
csv <- Sys.getenv("PATH_COORDS_CSV",
  file.path(system.file("examples", package = "cayleyR"),
            "output", "path_coords.csv"))
if (!file.exists(csv))
  stop("CSV not found: ", csv,
       "\nRun cayleyR::inst/examples/test_bh_path_coords.R first")

pd <- read.csv(csv, stringsAsFactors = FALSE)
n  <- pd$n[1]
k  <- pd$k[1]
path_keys <- pd$state                    # state key per step (space-separated)
cat(sprintf("Path: %d steps, n=%d, k=%d  (CSV: %s)\n",
            nrow(pd) - 1L, n, k, csv))

# ── Generate background cycles ────────────────────────
key_fn <- function(row) paste(as.integer(row), collapse = " ")

set.seed(42)
all_cycles <- list()
for (trial in seq_len(500)) {
  nops <- sample(4:12, 1)
  ops  <- sample(1:3, nops, replace = TRUE)
  res  <- get_reachable_states(seq_len(n), as.character(ops), k = k,
                               verbose = FALSE)
  if (res$unique_states_count >= 20)
    all_cycles[[length(all_cycles) + 1]] <- res$reachable_states_df
}
cat(sprintf("Background cycles: %d\n", length(all_cycles)))

# ── Unique nodes + cycle edges + per-node coordinates ─
# coord_map: state key -> c(theta, phi, omega) from first occurrence.
coord_map <- new.env(parent = emptyenv())
put_coord <- function(key, theta, phi, omega) {
  if (is.na(theta) || is.na(phi) || is.na(omega)) return(invisible())
  if (is.null(coord_map[[key]])) coord_map[[key]] <- c(theta, phi, omega)
}

all_keys <- character(0)
cycle_key_lists <- list()
for (ci in seq_along(all_cycles)) {
  df   <- all_cycles[[ci]]
  keys <- vapply(seq_len(nrow(df)),
                 function(j) key_fn(df[j, seq_len(n)]), character(1))
  cycle_key_lists[[ci]] <- keys
  all_keys <- c(all_keys, keys)
  for (j in seq_len(nrow(df)))
    put_coord(keys[j], df$theta[j], df$phi[j], df$omega_conformal[j])
}

# include path states so every path node exists in the graph
all_keys  <- c(all_keys, path_keys)
for (j in seq_len(nrow(pd)))
  put_coord(path_keys[j], pd$theta[j], pd$phi[j], pd$omega_conformal[j])

uniq_keys <- unique(all_keys)
n_nodes   <- length(uniq_keys)

ef <- integer(0); et <- integer(0)
add_chain <- function(keys, closed) {
  ids <- match(keys, uniq_keys)
  from <- ids[-length(ids)]; to <- ids[-1]
  if (closed) { from <- c(from, ids[length(ids)]); to <- c(to, ids[1]) }
  list(from = from, to = to)
}
for (keys in cycle_key_lists) {           # cycles are closed loops
  e <- add_chain(keys, closed = TRUE); ef <- c(ef, e$from); et <- c(et, e$to)
}
pe <- add_chain(path_keys, closed = FALSE) # the path is an open chain
ef <- c(ef, pe$from); et <- c(et, pe$to)

# dedup undirected edges
ekeys <- ifelse(ef < et, paste(ef, et), paste(et, ef))
keep  <- !duplicated(ekeys)
edges <- cbind(ef[keep], et[keep])
cat(sprintf("Graph: %d nodes, %d edges\n", n_nodes, nrow(edges)))

# ── Initial positions from celestial coordinates ─────
# Each node placed on the celestial sphere: radius = omega_conformal.
# Nodes without coordinates (e.g. cycle start rows with NA) fall back to origin.
tpo <- t(vapply(uniq_keys, function(key) {
  v <- coord_map[[key]]
  if (is.null(v)) c(0, 0, 0) else v
}, numeric(3)))
theta <- tpo[, 1]; phi <- tpo[, 2]; omega <- tpo[, 3]
init_pos <- cbind(omega * sin(theta) * cos(phi),
                  omega * sin(theta) * sin(phi),
                  omega * cos(theta))
# Scale to a moderate spread so FR starts from a sane configuration.
rmax <- max(sqrt(rowSums(init_pos^2)))
if (rmax > 0) init_pos <- init_pos / rmax * 10
# Jitter: many distinct states share (theta,phi,omega) and collapse to the
# same point; the Barnes-Hut octree can't split coincident points, so nudge
# each node slightly to break degeneracy before the layout runs.
set.seed(1L)
init_pos <- init_pos + matrix(rnorm(n_nodes * 3, sd = 0.05), ncol = 3)

# ── Barnes-Hut FR layout seeded by celestial coords ──
# FR pulls connected nodes together and pushes the rest apart, opening up
# the celestial "bundle" into a graph-like structure while keeping the
# overall shape anchored to the coordinates.
pos <- cgv_layout_fr_bh(n_nodes, edges,
                        n_iter = 200L, theta = 1.0,
                        cool = 0.98, min_dist = 0.01,
                        init = init_pos)

# ── Visualization ─────────────────────────────────────
v <- cgv_viewer(1280, 720,
                sprintf("TopSpin(%d,%d): path in cycle graph", n, k))
cgv_background(v, "black")

cgv_set_graph(v, seq_len(n_nodes), edges,
              positions   = pos,
              node_values = as.double(seq_len(n_nodes)),
              node_sizes  = as.double(rep(5, n_nodes)))

# ── Highlight the path ────────────────────────────────
path_ids  <- match(path_keys, uniq_keys)
start_id  <- path_ids[1]
final_id  <- path_ids[length(path_ids)]
cgv_highlight_path(v, path_ids, color = "#FF2200",
                   node_scale = 1.6, edge_width = 3.0)
cat(sprintf("Highlighting path: %d nodes\n", length(path_ids)))

# Mark start (green) and final (blue). Node-color/size overrides accumulate,
# so these repaint just the two endpoints; path edges stay from the call above.
cgv_highlight_path(v, start_id, color = "#00FF66", node_scale = 3.0)
cgv_highlight_path(v, final_id, color = "#3388FF", node_scale = 3.0)

# ── Graph distance between start and final (BFS on edges) ──
adj <- vector("list", n_nodes)
for (e in seq_len(nrow(edges))) {
  a <- edges[e, 1]; b <- edges[e, 2]
  adj[[a]] <- c(adj[[a]], b)
  adj[[b]] <- c(adj[[b]], a)
}
dist <- rep(NA_integer_, n_nodes)
dist[start_id] <- 0L
queue <- start_id
while (length(queue) > 0 && is.na(dist[final_id])) {
  cur <- queue[1]; queue <- queue[-1]
  for (nb in adj[[cur]]) {
    if (is.na(dist[nb])) {
      dist[nb] <- dist[cur] + 1L
      queue <- c(queue, nb)
    }
  }
}
graph_dist <- dist[final_id]
if (is.na(graph_dist)) {
  cat("Start and final are NOT connected in the graph.\n")
} else {
  cat(sprintf("Graph distance start->final: %d edges (path uses %d moves)\n",
              graph_dist, length(path_ids) - 1L))
}

# ── Camera ────────────────────────────────────────────
cm <- colMeans(pos)
max_dist <- max(sqrt(rowSums(sweep(pos, 2, cm)^2)))
dd <- max_dist * 2
cgv_camera(v, position = cm + c(dd * 0.7, dd * 0.6, dd * 0.8), target = cm)

cat("Right mouse drag = rotate, scroll = zoom. Close window to exit.\n")
cgv_run(v)
