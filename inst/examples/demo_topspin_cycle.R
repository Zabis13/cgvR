#!/usr/bin/env Rscript
# cgvR demo — цикл Кэли TopSpin по последовательности операций из cayleyR
# Использует get_reachable_states (без BFS): проигрывает циклическую
# последовательность операций до возврата в исходное состояние.
#
# Этапы профилируются по времени.

# ── Параметры ─────────────────────────────────────────
start_state <- 1:20
k           <- 4L

# Если TRUE — ищем лучшую последовательность через
# find_best_random_combinations(); если FALSE — используем заданную `ops`.
auto_search <- TRUE

# Параметры авто-поиска (передаются в find_best_random_combinations)
search_moves        <- c("1", "2", "3")
search_combo_length <- 10L
search_n_samples    <- 10000L
search_n_top        <- 10L
search_sort_by      <- c("longest", "most_unique")

# Используется, только если auto_search == FALSE.
# 1=L, 2=R, 3=X. convert_digits("1212133112") → c(1,2,1,2,1,3,3,1,1,2).
ops <- as.character(cayleyR::convert_digits("1113133112"))

# Режим раскладки: "raw" | "sphere" | "fr" | "polygon"
# polygon = каждый цикл — правильный многоугольник (все рёбра одной длины),
#           центры разнесены детерминированно в 3D, ориентация повёрнута.
layout_mode <- "polygon"

# Параметры polygon-раскладки
polygon_seed       <- 1L
polygon_spread     <- 60   # радиус сферы, в которой разносим центры циклов
polygon_radius_k   <- 1.2  # радиус кольца = polygon_radius_k * sqrt(m)

# ── Профилирование ────────────────────────────────────
timings <- list()
stage <- function(name, expr) {
  t0 <- Sys.time()
  val <- force(expr)
  dt <- as.numeric(Sys.time() - t0, units = "secs")
  timings[[name]] <<- dt
  cat(sprintf("[%-22s] %7.3f s\n", name, dt))
  val
}

stage("load libraries", {
  library(cayleyR)
  library(cgvR)
})

# ── 1а. (Опционально) Найти лучшую последовательность ──
if (auto_search) {
  best <- stage("find_best_random_combinations",
                find_best_random_combinations(
                  moves        = search_moves,
                  combo_length = search_combo_length,
                  n_samples    = search_n_samples,
                  n_top        = search_n_top,
                  start_state  = start_state,
                  k            = k,
                  sort_by      = search_sort_by))
  cat("Top combinations:\n"); print(best)
  combo_strs <- as.character(best$combination)
} else {
  # Используется заданная `ops` как единственный цикл.
  combo_strs <- paste(ops, collapse = "")
}

# ── Хелперы ───────────────────────────────────────────
cycle_positions <- function(df, n_states, idx = 1L, n_cycles = 1L) {
  theta <- df$theta;  theta[is.na(theta)] <- 0
  phi   <- df$phi;    phi[is.na(phi)]     <- 0
  omega <- df$omega_conformal; omega[is.na(omega)] <- 0
  if (layout_mode == "raw") {
    cbind(x = theta, y = phi, z = omega)
  } else if (layout_mode == "sphere") {
    # log(1+ω): ω может расти экспоненциально (до тысяч), линейный
    # радиус схлопывает точки при нормализации.
    r <- log1p(omega)
    cbind(x = r * sin(theta) * cos(phi),
          y = r * sin(theta) * sin(phi),
          z = r * cos(theta))
  } else if (layout_mode == "fr") {
    e <- cbind(seq_len(n_states), c(seq.int(2L, n_states), 1L))
    cgv_layout_fr(n_states, e, n_iter = 300L, seed = 1L, verbose = FALSE)
  } else if (layout_mode == "polygon") {
    polygon_layout(n_states, idx, n_cycles)
  } else stop("Unknown layout_mode: ", layout_mode)
}

# Правильный многоугольник в плоскости xy, повёрнутый случайной ориентацией
# и сдвинутый в детерминированную точку фибоначчиевой сферы.
polygon_layout <- function(m, idx, n_cycles) {
  R <- polygon_radius_k * sqrt(m)
  ang <- 2 * pi * (seq_len(m) - 1) / m
  ring <- cbind(R * cos(ang), R * sin(ang), 0)

  # Детерминированные RNG-стримы по индексу цикла
  set.seed(polygon_seed * 1000L + idx)
  # Случайное вращение через ось+угол
  axis <- rnorm(3); axis <- axis / sqrt(sum(axis^2))
  alpha <- runif(1, 0, 2 * pi)
  Rm <- rotation_matrix(axis, alpha)
  ring <- ring %*% t(Rm)

  # Центр на сфере Фибоначчи (равномерно), радиус сферы = polygon_spread
  # масштабируется размером кольца, чтобы кольца не пересекались
  ga <- pi * (3 - sqrt(5))                          # golden angle
  z  <- 1 - 2 * (idx - 0.5) / max(n_cycles, 1)
  rr <- sqrt(max(0, 1 - z * z))
  th <- ga * idx
  spread <- polygon_spread + 0.5 * R
  center <- spread * c(rr * cos(th), rr * sin(th), z)

  ring[, 1] <- ring[, 1] + center[1]
  ring[, 2] <- ring[, 2] + center[2]
  ring[, 3] <- ring[, 3] + center[3]
  colnames(ring) <- c("x", "y", "z")
  ring
}

# Rodrigues' rotation matrix
rotation_matrix <- function(axis, angle) {
  c_ <- cos(angle); s_ <- sin(angle); t_ <- 1 - c_
  x <- axis[1]; y <- axis[2]; z <- axis[3]
  matrix(c(
    t_*x*x + c_,    t_*x*y - s_*z,  t_*x*z + s_*y,
    t_*x*y + s_*z,  t_*y*y + c_,    t_*y*z - s_*x,
    t_*x*z - s_*y,  t_*y*z + s_*x,  t_*z*z + c_
  ), nrow = 3, byrow = TRUE)
}

# ── 1б. Получить все циклы из cayleyR ─────────────────
cycles <- stage("get_reachable_states (all)", {
  out <- vector("list", length(combo_strs))
  for (i in seq_along(combo_strs)) {
    ops_i <- as.character(cayleyR::convert_digits(combo_strs[i]))
    r <- get_reachable_states(start_state, allowed_positions = ops_i,
                              k = k, verbose = FALSE)
    n_i <- r$unique_states_count
    out[[i]] <- list(combo = combo_strs[i],
                     ops = ops_i,
                     n = n_i,
                     df = r$reachable_states_df[seq_len(n_i), ])
  }
  out
})

cat(sprintf("Cycles: %d, sizes = [%s]\n",
            length(cycles),
            paste(vapply(cycles, function(c) c$n, numeric(1)), collapse = ", ")))

# ── 2-3. Координаты + рёбра для каждого цикла, потом склейка ──
graph <- stage("build positions+edges", {
  pos_list   <- vector("list", length(cycles))
  edges_list <- vector("list", length(cycles))
  values_list<- vector("list", length(cycles))
  highlight_path <- NULL
  offset <- 0L
  for (i in seq_along(cycles)) {
    cy <- cycles[[i]]
    pos_list[[i]] <- cycle_positions(cy$df, cy$n,
                                     idx = i, n_cycles = length(cycles))
    from <- seq_len(cy$n) + offset
    to   <- c(seq.int(2L, cy$n), 1L) + offset
    edges_list[[i]] <- cbind(from, to)
    # node_values: для подсветки — индекс цикла, для тусклых — 0..1 по шагу
    values_list[[i]] <- as.double(seq_len(cy$n)) / cy$n + (i - 1)
    if (i == 1L) highlight_path <- seq_len(cy$n) + offset
    offset <- offset + cy$n
  }
  pos_all <- do.call(rbind, pos_list)
  # Нормализация в [-15, 15]: Datoviz камера/clip рассчитаны на сцену
  # порядка десятков единиц; без нормализации крупные сцены
  # схлопываются в точку.
  pos_all <- sweep(pos_all, 2, colMeans(pos_all))
  m <- max(abs(pos_all))
  if (m > 0) pos_all <- pos_all / m * 15
  list(positions = pos_all,
       edges     = do.call(rbind, edges_list),
       values    = unlist(values_list),
       highlight = highlight_path,
       total_n   = offset)
})

cat(sprintf("Total nodes: %d, total edges: %d\n",
            graph$total_n, nrow(graph$edges)))

# ── 6. Открыть окно и загрузить граф ──────────────────
title_combo <- cycles[[1]]$combo
v <- stage("cgv_viewer",
           cgv_viewer(1280, 720,
                      sprintf("TopSpin top-%d cycles (highlight=%s, %s)",
                              length(cycles), title_combo, layout_mode)))

stage("cgv_background", cgv_background(v, "black"))

# Размеры в стиле spring-демо: убывают по индексу узла
node_sizes <- pmax(4, 18 - seq_len(graph$total_n) * 0.01)

stage("cgv_set_graph",
      cgv_set_graph(v, seq_len(graph$total_n), graph$edges,
                    positions = graph$positions,
                    node_sizes = as.double(node_sizes)))

# Подсветить самый длинный цикл (с замыканием)
hp <- c(graph$highlight, graph$highlight[1])
stage("cgv_highlight_path",
      cgv_highlight_path(v, hp, color = "#FF2200",
                         node_scale = 1.5, edge_width = 2.0))

# ── 7. Камера ─────────────────────────────────────────
ctr <- colMeans(graph$positions)
ext <- max(apply(graph$positions, 2, function(c) diff(range(c))))
cam_d <- max(ext * 1.8, 5)
stage("cgv_camera",
      cgv_camera(v,
                 position = ctr + c(cam_d, cam_d * 0.7, cam_d),
                 target   = ctr))

# ── Итоги по времени ──────────────────────────────────
cat("\n── Timing summary ──\n")
total <- sum(unlist(timings))
for (nm in names(timings)) {
  cat(sprintf("  %-22s %7.3f s  (%5.1f%%)\n",
              nm, timings[[nm]], 100 * timings[[nm]] / total))
}
cat(sprintf("  %-22s %7.3f s\n", "TOTAL (pre-run)", total))

# WASD + мышь, закрыть окно для выхода
cgv_run(v)
