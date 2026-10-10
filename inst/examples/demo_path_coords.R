#!/usr/bin/env Rscript
# cgvR demo — visualize a path's celestial coordinates (from cayleyR).
# Reads path_coords.csv (see cayleyR::inst/examples/test_bh_path_coords.R),
# placing each transition point on the celestial sphere
#   x = ω·sinθ·cosφ,  y = ω·sinθ·sinφ,  z = ω·cosθ
# (radius = omega_conformal); edges connect consecutive path steps.
# Node color = step index (gradient along the path).
library(cgvR)

# ── Data ──────────────────────────────────────────────
csv <- Sys.getenv("PATH_COORDS_CSV",
  file.path(system.file("examples", package = "cayleyR"),
            "output", "path_coords.csv"))
if (!file.exists(csv))
  stop("CSV not found: ", csv,
       "\nRun cayleyR::inst/examples/test_bh_path_coords.R first")

d <- read.csv(csv)
cat(sprintf("Path points: %d  (CSV: %s)\n", nrow(d), csv))

# ── Celestial coordinates → 3D positions ──────────────
r <- d$omega_conformal
pos <- cbind(
  r * sin(d$theta) * cos(d$phi),
  r * sin(d$theta) * sin(d$phi),
  r * cos(d$theta)
)
# Normalize to a compact scale (radius grows up to ~thousands, otherwise
# the camera sits too far away and the whole path collapses to a dot).
pos <- pos / max(sqrt(rowSums(pos^2)))   # fit within unit radius
pos <- pos * 10                          # spread to a comfortable size
n_nodes <- nrow(pos)

# ── Edges: chain step_i -> step_{i+1} ─────────────────
edges <- cbind(seq_len(n_nodes - 1L), 2:n_nodes)

# ── Visualization ─────────────────────────────────────
v <- cgv_viewer(1280, 720, "cayleyR path — celestial coordinates (sphere θ,φ,ω)")
cgv_background(v, "black")

node_vals <- as.double(d$step)          # color = step index
sizes     <- rep(4, n_nodes)

cgv_set_graph(v, seq_len(n_nodes), edges,
              positions   = pos,
              node_values = node_vals,
              node_sizes  = as.double(sizes))

# Highlight the whole path
cgv_highlight_path(v, seq_len(n_nodes), color = "#FF2200",
                   node_scale = 1.2, edge_width = 1.5)

# ── Camera ────────────────────────────────────────────
cm <- colMeans(pos)
max_dist <- max(sqrt(rowSums(sweep(pos, 2, cm)^2)))
dd <- max_dist * 1.3
cgv_camera(v, position = cm + c(dd * 0.7, dd * 0.6, dd * 0.8), target = cm)

cat("Right mouse drag = rotate, scroll = zoom. Close window to exit.\n")
cgv_run(v)
