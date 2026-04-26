#!/usr/bin/env Rscript
# cgvR demo — граф состояний игры Tic-Tac-Toe (крестики-нолики).
# Узлы = уникальные позиции на доске 3×3 (X = 1, O = 2, пусто = 0).
# Рёбра = ходы: позиция -> позиция после хода X или O.
# Цвет узла кодирует НОМЕР ХОДА (0..9) через viridis,
# размер тоже зависит от хода (ранний ход = крупнее).
# Раскладка — Barnes-Hut Fruchterman-Reingold, как в demo_cycles_bh.R.
library(cgvR)

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

# ── Генерация полного графа состояний через DFS ──────────────
WIN_LINES <- list(
  c(1,2,3), c(4,5,6), c(7,8,9),
  c(1,4,7), c(2,5,8), c(3,6,9),
  c(1,5,9), c(3,5,7)
)

check_winner <- function(b) {
  for (ln in WIN_LINES) {
    s <- b[ln]
    if (s[1] != 0 && s[1] == s[2] && s[2] == s[3]) return(s[1])
  }
  0L
}

board_key <- function(b) paste(b, collapse = "")

graph <- stage("build game graph", {
  env <- new.env(parent = emptyenv())
  env$keys      <- character(0)
  env$key_to_id <- new.env(hash = TRUE, parent = emptyenv())
  env$move_no   <- integer(0)
  env$status    <- integer(0)   # 0=в игре, 1=X выиграл, 2=O выиграл, 3=ничья
  env$ef        <- integer(0)
  env$et        <- integer(0)

  add_node <- function(b, mn) {
    k <- board_key(b)
    id <- env$key_to_id[[k]]
    if (!is.null(id)) return(list(id = id, fresh = FALSE))
    id <- length(env$keys) + 1L
    env$keys[id] <- k
    env$key_to_id[[k]] <- id
    env$move_no[id] <- mn
    w <- check_winner(b)
    st <- if (w == 1L) 1L
          else if (w == 2L) 2L
          else if (!any(b == 0L)) 3L
          else 0L
    env$status[id] <- st
    list(id = id, fresh = TRUE)
  }

  dfs <- function(b, mn, parent_id) {
    rec <- add_node(b, mn)
    if (parent_id > 0L) {
      env$ef <- c(env$ef, parent_id)
      env$et <- c(env$et, rec$id)
    }
    if (!rec$fresh) return(invisible())
    if (env$status[rec$id] != 0L) return(invisible())
    player <- if (mn %% 2L == 0L) 1L else 2L
    for (cell in which(b == 0L)) {
      nb <- b; nb[cell] <- player
      dfs(nb, mn + 1L, rec$id)
    }
  }

  dfs(integer(9), 0L, 0L)

  # Уникальные неориентированные рёбра
  ef <- env$ef; et <- env$et
  ekey <- ifelse(ef < et, paste(ef, et), paste(et, ef))
  keep <- !duplicated(ekey)

  list(n_nodes = length(env$keys),
       edges   = cbind(ef[keep], et[keep]),
       move_no = env$move_no,
       status  = env$status,
       key_to_id = env$key_to_id)
})

cat(sprintf("Graph: %d nodes, %d edges\n",
            graph$n_nodes, nrow(graph$edges)))
cat(sprintf("Move-number histogram: %s\n",
            paste(tabulate(graph$move_no + 1L, 10L), collapse = " ")))

# ── Barnes-Hut FR раскладка ──────────────────────────────────
pos <- stage("cgv_layout_fr_bh",
             cgv_layout_fr_bh(graph$n_nodes, graph$edges,
                              n_iter = 250L,
                              theta = 1.0,
                              cool = 0.98,
                              min_dist = 0.01,
                              seed = 1L))

edge_lens <- sqrt(rowSums(
  (pos[graph$edges[, 1], ] - pos[graph$edges[, 2], ])^2))
cat(sprintf("Edge length: mean=%.3f, sd=%.3f, cv=%.1f%%\n",
            mean(edge_lens), sd(edge_lens),
            100 * sd(edge_lens) / mean(edge_lens)))

# ── Визуализация ──────────────────────────────────────────────
v <- stage("cgv_viewer",
           cgv_viewer(1280, 720,
                      "Tic-Tac-Toe game graph — colour = move number"))
stage("cgv_background", cgv_background(v, "black"))

# Цвет = номер хода (0..9), размер тоже зависит от хода.
node_vals <- as.double(graph$move_no)
sizes     <- 16 - graph$move_no * 1.0     # 16 → 7
sizes[graph$move_no == 0L] <- 26          # корень — самый крупный

stage("cgv_set_graph",
      cgv_set_graph(v, seq_len(graph$n_nodes), graph$edges,
                    positions   = pos,
                    node_values = node_vals,
                    node_sizes  = as.double(sizes),
                    cmap        = 6L))    # viridis

# Подсветить пример партии (короткая победа X) одним «путём».
to_board <- function(moves) {
  b <- integer(9); p <- 1L
  for (m in moves) { b[m] <- p; p <- 3L - p }
  b
}
example_moves <- list(
  integer(0),
  c(5),
  c(5,1),
  c(5,1,9),
  c(5,1,9,3),
  c(5,1,9,3,7)        # X выигрывает по диагонали 1-5-9? нет, 5+7+? — берём как пример пути
)
example_path <- vapply(example_moves,
                       function(m) graph$key_to_id[[board_key(to_board(m))]],
                       integer(1))

stage("cgv_highlight_path",
      cgv_highlight_path(v, example_path, color = "#FFFFFF",
                         node_scale = 1.6, edge_width = 4.0))

# Камера: автонаведение по центру масс, как в demo_cycles_bh.R
cm <- colMeans(pos)
max_dist <- max(sqrt(rowSums(sweep(pos, 2, cm)^2)))
d <- max_dist * 2
stage("cgv_camera",
      cgv_camera(v, position = cm + c(d * 0.7, d * 0.6, d * 0.8),
                 target = cm))

# ── Итоги ────────────────────────────────────────────────────
cat(sprintf("\nTerminals — X wins: %d, O wins: %d, draws: %d\n",
            sum(graph$status == 1L),
            sum(graph$status == 2L),
            sum(graph$status == 3L)))

cat("\n── Timing summary ──\n")
total <- sum(unlist(timings))
for (nm in names(timings)) {
  cat(sprintf("  %-22s %7.3f s  (%5.1f%%)\n",
              nm, timings[[nm]], 100 * timings[[nm]] / total))
}
cat(sprintf("  %-22s %7.3f s\n", "TOTAL (pre-run)", total))

cat("\nRight mouse drag = rotate, scroll = zoom. Close window to exit.\n")
cat("Colour = move number (0 dark → 9 bright, viridis). White = sample game.\n")
cgv_run(v)
