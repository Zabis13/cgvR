#!/usr/bin/env Rscript
# cgvR demo — полный граф Кэли TopSpin(6, 4)
# 720 узлов, 2160 рёбер, 3 генератора: L, R, X(k=4)
library(cayleyR)
library(cgvR)

# ── Полный BFS от identity ────────────────────────────
start <- 1:6
k <- 4L

key_fn <- function(s) paste(s, collapse = ",")

states <- list()
state_keys <- character(0)
queue <- list(start)
states[[key_fn(start)]] <- list(state = start, depth = 0L, parent = NA_character_)
state_keys <- key_fn(start)

edges_from <- integer(0)
edges_to   <- integer(0)

head <- 1L
while (head <= length(queue)) {
  cur <- queue[[head]]; head <- head + 1L
  cur_key <- key_fn(cur)
  cur_depth <- states[[cur_key]]$depth
  cur_id <- match(cur_key, state_keys)

  children <- list(
    shift_left_simple(cur),
    shift_right_simple(cur),
    reverse_prefix_simple(cur, k)
  )

  for (ch in children) {
    ch_key <- key_fn(ch)
    if (is.null(states[[ch_key]])) {
      states[[ch_key]] <- list(state = ch, depth = cur_depth + 1L, parent = cur_key)
      state_keys <- c(state_keys, ch_key)
      queue <- c(queue, list(ch))
    }
    ch_id <- match(ch_key, state_keys)
    edges_from <- c(edges_from, cur_id)
    edges_to   <- c(edges_to, ch_id)
  }
}

n <- length(state_keys)
depths <- sapply(states, "[[", "depth")
max_d <- max(depths)

cat(sprintf("TopSpin(%d,%d): %d states, %d edges, diameter %d\n",
            6, k, n, length(edges_from), max_d))

# ── Удалить дубликаты рёбер (a→b и b→a) ──────────────
edge_keys <- ifelse(edges_from < edges_to,
                    paste(edges_from, edges_to),
                    paste(edges_to, edges_from))
dup <- duplicated(edge_keys)
edges_from <- edges_from[!dup]
edges_to   <- edges_to[!dup]
cat(sprintf("Unique edges: %d\n", length(edges_from)))

# ── 3D раскладка: радиальная по слоям BFS ────────────
set.seed(1)
pos <- matrix(0, nrow = n, ncol = 3)

for (d in 0:max_d) {
  idx <- which(depths == d)
  nd <- length(idx)
  if (d == 0) {
    pos[idx, ] <- 0
    next
  }
  # Радиус растёт с глубиной
  r <- d * 2.0
  # Равномерно по сфере на этом уровне + шум
  phi   <- seq(0, 2 * pi, length.out = nd + 1)[-(nd + 1)] + runif(nd, -0.3, 0.3)
  theta <- acos(seq(-0.8, 0.8, length.out = nd)) + runif(nd, -0.1, 0.1)

  pos[idx, 1] <- r * sin(theta) * cos(phi)
  pos[idx, 2] <- d * 1.5 + runif(nd, -0.5, 0.5)   # вертикаль ~ глубина
  pos[idx, 3] <- r * sin(theta) * sin(phi)
}

# ── Размеры: крупнее у корня ──────────────────────────
sizes <- pmax(4, 18 - depths * 1.2)

# ── Визуализация ──────────────────────────────────────
edges <- cbind(edges_from, edges_to)

v <- cgv_viewer(1280, 720, sprintf("TopSpin(%d,%d) Cayley Graph", 6, k))
cgv_set_graph(v, seq_len(n), edges,
              positions = pos,
              node_values = as.double(depths),
              node_sizes  = as.double(sizes))

# ── Подсветить путь до самого далёкого узла ───────────
farthest <- which.max(depths)
path <- farthest
cur_key <- state_keys[farthest]
while (!is.na(states[[cur_key]]$parent)) {
  cur_key <- states[[cur_key]]$parent
  path <- c(match(cur_key, state_keys), path)
}
cat(sprintf("Highlighted path: %d steps (identity → farthest)\n", length(path) - 1))

cgv_highlight_path(v, path, color = "#FF2200",
                   node_scale = 2.0, edge_width = 5.0)

cgv_camera(v, position = c(30, 25, 35), target = c(0, 10, 0))

# WASD + мышь, закрыть окно для выхода
cgv_run(v)
