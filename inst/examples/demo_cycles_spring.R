#!/usr/bin/env Rscript
# cgvR demo — циклы TopSpin(8,4), 3D spring layout (Fruchterman-Reingold)
# Все состояния как точки + рёбра, самый длинный цикл подсвечен
library(cayleyR)
library(cgvR)

n <- 6L; k <- 4L

# ── Генерируем циклы, отбираем >= 50 ─────────────────────
set.seed(42)
all_cycles <- list()

for (trial in seq_len(500)) {
  nops <- sample(4:12, 1)
  ops <- sample(1:3, nops, replace = TRUE)
  res <- get_reachable_states(seq_len(n), as.character(ops), k = k, verbose = FALSE)
  clen <- res$unique_states_count
  if (clen >= 50) {
    all_cycles[[length(all_cycles) + 1]] <- list(
      ops = ops, len = clen, df = res$reachable_states_df
    )
  }
}

all_cycles <- all_cycles[order(-sapply(all_cycles, "[[", "len"))]
best <- all_cycles[[1]]

cat(sprintf("Found %d cycles >= 50, longest: ops=[%s], len=%d\n",
            length(all_cycles), paste(best$ops, collapse = ","), best$len))

# ── Уникальные состояния из всех циклов ──────────────────
key_fn <- function(row) paste(row, collapse = ",")

all_keys <- character(0)
all_dfs  <- list()

for (ci in seq_along(all_cycles)) {
  df <- all_cycles[[ci]]$df
  keys <- character(nrow(df))
  for (j in seq_len(nrow(df)))
    keys[j] <- key_fn(as.integer(df[j, seq_len(n)]))
  all_keys <- c(all_keys, keys)
  all_dfs[[ci]] <- list(keys = keys, df = df)
}

uniq_keys <- unique(all_keys)
n_nodes <- length(uniq_keys)

# ── Рёбра ────────────────────────────────────────────────
edges_from <- integer(0); edges_to <- integer(0)
for (ci in seq_along(all_dfs)) {
  ids <- match(all_dfs[[ci]]$keys, uniq_keys)
  for (j in seq_len(length(ids) - 1)) {
    edges_from <- c(edges_from, ids[j])
    edges_to   <- c(edges_to,   ids[j + 1])
  }
  edges_from <- c(edges_from, ids[length(ids)])
  edges_to   <- c(edges_to,   ids[1])
}

ekeys <- ifelse(edges_from < edges_to,
                paste(edges_from, edges_to),
                paste(edges_to, edges_from))
keep <- !duplicated(ekeys)
edges_from <- edges_from[keep]
edges_to   <- edges_to[keep]
n_edges <- length(edges_from)

cat(sprintf("Graph: %d nodes, %d edges\n", n_nodes, n_edges))

# ── 3D Spring Layout (Fruchterman-Reingold) ──────────────
set.seed(1)
pos <- matrix(rnorm(n_nodes * 3), ncol = 3)

ideal_len <- (n_nodes ^ (1/3)) * 0.8
n_iter <- 300
temp <- ideal_len * 2

for (iter in seq_len(n_iter)) {
  disp <- matrix(0, nrow = n_nodes, ncol = 3)
  for (i in seq_len(n_nodes)) {
    delta <- sweep(pos, 2, pos[i, ])
    dist <- sqrt(rowSums(delta^2))
    dist[i] <- 1
    force <- -ideal_len^2 / dist^2
    disp[i, ] <- colSums(delta * force / dist)
  }
  for (e in seq_len(n_edges)) {
    a <- edges_from[e]; b <- edges_to[e]
    delta <- pos[b, ] - pos[a, ]
    d <- max(sqrt(sum(delta^2)), 0.01)
    f <- d / ideal_len
    disp[a, ] <- disp[a, ] + delta / d * f
    disp[b, ] <- disp[b, ] - delta / d * f
  }
  dl <- sqrt(rowSums(disp^2))
  dl[dl < 0.001] <- 0.001
  pos <- pos + disp * pmin(temp, dl) / dl
  temp <- temp * 0.98
}

pos <- sweep(pos, 2, colMeans(pos))

# Нормализовать в [-15, 15] как в demo_topspin
max_abs <- max(abs(pos))
if (max_abs > 0) pos <- pos / max_abs * 15

cat("Spring layout done.\n")

# ── Визуализация ─────────────────────────────────────────
edges <- cbind(edges_from, edges_to)
sizes <- pmax(4, 18 - seq_len(n_nodes) * 0.01)

v <- cgv_viewer(1280, 720, sprintf("TopSpin(%d,%d) cycles — spring layout", n, k))
cgv_background(v, "white")
cgv_set_graph(v, seq_len(n_nodes), edges,
              positions  = pos,
              node_sizes = as.double(sizes))

# Подсветить самый длинный цикл
best_ids <- match(all_dfs[[1]]$keys, uniq_keys)
best_path <- c(best_ids, best_ids[1])

cat(sprintf("Highlighting longest cycle: %d steps\n", length(best_path) - 1))

cgv_highlight_path(v, best_path, color = "#FF2200",
                   node_scale = 1.5, edge_width = 2.0)

cgv_camera(v, position = c(30, 25, 35), target = c(0, 0, 0))

cat("WASD + mouse, close window to exit.\n")
cgv_run(v)
