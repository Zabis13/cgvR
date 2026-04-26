#!/usr/bin/env Rscript
# cgvR demo — циклы TopSpin(8,4), 3D раскладка из celestial координат (theta, phi, omega)
# Все состояния как точки + рёбра, самый длинный цикл подсвечен
library(cayleyR)
library(cgvR)

n <- 7L; k <- 4L

# ── Генерируем циклы, отбираем самые длинные ─────────────
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

# ── Собираем все уникальные состояния из всех циклов ─────
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

# ── Рёбра из всех циклов ────────────────────────────────
edges_from <- integer(0); edges_to <- integer(0)
for (ci in seq_along(all_dfs)) {
  ids <- match(all_dfs[[ci]]$keys, uniq_keys)
  for (j in seq_len(length(ids) - 1)) {
    edges_from <- c(edges_from, ids[j])
    edges_to   <- c(edges_to,   ids[j + 1])
  }
  # замкнуть
  edges_from <- c(edges_from, ids[length(ids)])
  edges_to   <- c(edges_to,   ids[1])
}

# Убрать дубликаты
ekeys <- ifelse(edges_from < edges_to,
                paste(edges_from, edges_to),
                paste(edges_to, edges_from))
keep <- !duplicated(ekeys)
edges_from <- edges_from[keep]
edges_to   <- edges_to[keep]

cat(sprintf("Graph: %d nodes, %d edges\n", n_nodes, length(edges_from)))

# ── 3D позиции из celestial координат ────────────────────
node_theta <- rep(NA_real_, n_nodes)
node_phi   <- rep(NA_real_, n_nodes)
node_omega <- rep(NA_real_, n_nodes)

for (ci in seq_along(all_dfs)) {
  df   <- all_dfs[[ci]]$df
  keys <- all_dfs[[ci]]$keys
  ids  <- match(keys, uniq_keys)
  for (j in seq_len(nrow(df))) {
    nid <- ids[j]
    if (is.na(node_theta[nid]) && !is.na(df$theta[j])) {
      node_theta[nid] <- df$theta[j]
      node_phi[nid]   <- df$phi[j]
      node_omega[nid] <- df$omega_conformal[j]
    }
  }
}

node_theta[is.na(node_theta)] <- 0
node_phi[is.na(node_phi)]     <- 0
node_omega[is.na(node_omega)] <- 1

# Нормализовать omega чтобы точки не были слишком разбросаны
node_omega <- log1p(node_omega) * 3

pos <- matrix(0, nrow = n_nodes, ncol = 3)
pos[, 1] <- node_omega * sin(node_theta) * cos(node_phi)
pos[, 2] <- node_omega * sin(node_theta) * sin(node_phi)
pos[, 3] <- node_omega * cos(node_theta)

# ── Размеры: помельче для фона, покрупнее для лучшего цикла ──
sizes <- rep(6, n_nodes)

# ── Colormap по omega (глубина) ──────────────────────────
node_vals <- node_omega

# ── Визуализация ─────────────────────────────────────────
edges <- cbind(edges_from, edges_to)

v <- cgv_viewer(1280, 720, "TopSpin(8,4) cycles — celestial coords")
cgv_background(v, "black")  # светло-зелёный фон
cgv_set_graph(v, seq_len(n_nodes), edges,
              positions  = pos,
              node_values = as.double(node_vals),
              node_sizes  = as.double(sizes))

# Подсветить самый длинный цикл
best_ids <- match(all_dfs[[1]]$keys, uniq_keys)
best_path <- c(best_ids, best_ids[1])

cat(sprintf("Highlighting longest cycle: %d steps\n", length(best_path) - 1))

cgv_highlight_path(v, best_path, color = "#FF2200",
                   node_scale = 1.5, edge_width = 2.0)

# Камера как в demo_topspin
cm <- colMeans(pos)
max_dist <- max(sqrt(rowSums(sweep(pos, 2, cm)^2)))
d <- max_dist * 2
cgv_camera(v, position = cm + c(d * 0.7, d * 0.6, d * 0.8),
              target = cm + c(0, max_dist * 0.3, 0))

cat("WASD + mouse, close window to exit.\n")
cgv_run(v)
