#!/usr/bin/env Rscript
# cgvR demo — 100 узлов, случайный граф с colormap и подсветкой пути
library(cgvR)

set.seed(42)
n <- 100L

# Случайные рёбра: каждый узел связан с 2-3 соседями
from <- integer(0); to <- integer(0)
for (i in 2:n) {
  # Связь с случайным предшественником (дерево)
  j <- sample.int(i - 1L, 1L)
  from <- c(from, j); to <- c(to, i)
}
# Дополнительные случайные рёбра
extra <- sample.int(n, 60L)
for (k in seq(1, length(extra) - 1, by = 2)) {
  a <- extra[k]; b <- extra[k + 1]
  if (a != b) { from <- c(from, a); to <- c(to, b) }
}
edges <- cbind(from, to)

# 3D позиции — сфера с шумом
phi <- runif(n, 0, 2 * pi)
theta <- acos(runif(n, -1, 1))
r <- 5 * runif(n)^(1/3)  # равномерно по объёму
pos <- cbind(
  r * sin(theta) * cos(phi),
  r * sin(theta) * sin(phi),
  r * cos(theta)
)

# BFS-глубина от узла 1 (простой BFS по рёбрам)
depth <- rep(NA_integer_, n)
depth[1] <- 0L
queue <- 1L
while (length(queue) > 0) {
  cur <- queue[1]; queue <- queue[-1]
  # Соседи
  nbrs <- c(to[from == cur], from[to == cur])
  nbrs <- unique(nbrs)
  for (nb in nbrs) {
    if (is.na(depth[nb])) {
      depth[nb] <- depth[cur] + 1L
      queue <- c(queue, nb)
    }
  }
}
depth[is.na(depth)] <- max(depth, na.rm = TRUE) + 1L

# Размеры: крупнее для ближних к корню
sizes <- pmax(5, 20 - depth * 2)

v <- cgv_viewer(1280, 720, "cgvR 100-node demo")
cgv_set_graph(v, 1:n, edges,
              positions = pos,
              node_values = as.double(depth),
              node_sizes = as.double(sizes))

# Подсветить путь от корня до самого далёкого узла
farthest <- which.max(depth)
# Восстановить путь через BFS-дерево
path <- farthest
cur <- farthest
while (cur != 1L) {
  nbrs <- c(to[from == cur], from[to == cur])
  cur <- nbrs[which.min(depth[nbrs])]
  path <- c(cur, path)
}
cgv_highlight_path(v, path, color = "#FF3300",
                   node_scale = 2.5, edge_width = 6.0)

cgv_camera(v, position = c(10, 8, 12), target = c(0, 0, 0))

# WASD + мышь для навигации, закрыть окно для выхода
cgv_run(v)
