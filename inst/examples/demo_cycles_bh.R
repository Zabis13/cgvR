#!/usr/bin/env Rscript
# cgvR demo — циклы TopSpin(8,4), Barnes-Hut FR раскладка.
# Все рёбра стремятся к одной длине, узлы расталкиваются.
# Раскладка считается на C через octree → быстро на больших графах.
library(cayleyR)
library(cgvR)

n <- 6L; k <- 4L

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

# ── Генерация циклов ──────────────────────────────────
all_cycles <- stage("generate cycles", {
  set.seed(42)
  out <- list()
  for (trial in seq_len(500)) {
    nops <- sample(4:12, 1)
    ops <- sample(1:3, nops, replace = TRUE)
    res <- get_reachable_states(seq_len(n), as.character(ops), k = k,
                                verbose = FALSE)
    if (res$unique_states_count >= 20) {
      out[[length(out) + 1]] <- list(ops = ops,
                                     len = res$unique_states_count,
                                     df = res$reachable_states_df)
    }
  }
  out[order(-sapply(out, "[[", "len"))]
})

best <- all_cycles[[1]]
cat(sprintf("Found %d cycles >= 50, longest: ops=[%s], len=%d\n",
            length(all_cycles), paste(best$ops, collapse = ","), best$len))

# ── Уникальные состояния ──────────────────────────────
graph <- stage("build graph", {
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

  ef <- integer(0); et <- integer(0)
  for (ci in seq_along(all_dfs)) {
    ids <- match(all_dfs[[ci]]$keys, uniq_keys)
    ef <- c(ef, ids[-length(ids)], ids[length(ids)])
    et <- c(et, ids[-1],            ids[1])
  }
  ekeys <- ifelse(ef < et, paste(ef, et), paste(et, ef))
  keep <- !duplicated(ekeys)
  list(n_nodes = n_nodes,
       edges   = cbind(ef[keep], et[keep]),
       all_dfs = all_dfs,
       uniq_keys = uniq_keys)
})

cat(sprintf("Graph: %d nodes, %d edges\n",
            graph$n_nodes, nrow(graph$edges)))

# ── Barnes-Hut FR раскладка ───────────────────────────
pos <- stage("cgv_layout_fr_bh",
             cgv_layout_fr_bh(graph$n_nodes, graph$edges,
                              n_iter = 200L,
                              theta = 1.0,
                              cool = 0.98,
                              min_dist = 0.01,
                              seed = 1L))

# ── Проверка: насколько равны рёбра ───────────────────
edge_lens <- sqrt(rowSums(
  (pos[graph$edges[, 1], ] - pos[graph$edges[, 2], ])^2))
cat(sprintf("Edge length: mean=%.3f, sd=%.3f, cv=%.1f%%\n",
            mean(edge_lens), sd(edge_lens),
            100 * sd(edge_lens) / mean(edge_lens)))

# ── Визуализация ──────────────────────────────────────
v <- stage("cgv_viewer",
           cgv_viewer(1280, 720,
                      sprintf("TopSpin(%d,%d) cycles — Barnes-Hut FR", n, k)))
stage("cgv_background", cgv_background(v, "black"))

sizes <- rep(6, graph$n_nodes)
node_vals <- as.double(seq_len(graph$n_nodes))

stage("cgv_set_graph",
      cgv_set_graph(v, seq_len(graph$n_nodes), graph$edges,
                    positions   = pos,
                    node_values = node_vals,
                    node_sizes  = as.double(sizes)))

# Подсветить самый длинный цикл
best_ids <- match(graph$all_dfs[[1]]$keys, graph$uniq_keys)
best_path <- c(best_ids, best_ids[1])
cat(sprintf("Highlighting longest cycle: %d steps\n", length(best_path) - 1))
stage("cgv_highlight_path",
      cgv_highlight_path(v, best_path, color = "#FF2200",
                         node_scale = 1.5, edge_width = 2.0))

cm <- colMeans(pos)
max_dist <- max(sqrt(rowSums(sweep(pos, 2, cm)^2)))
d <- max_dist * 2
stage("cgv_camera",
      cgv_camera(v, position = cm + c(d * 0.7, d * 0.6, d * 0.8),
                 target = cm))

# ── Итоги ─────────────────────────────────────────────
cat("\n── Timing summary ──\n")
total <- sum(unlist(timings))
for (nm in names(timings)) {
  cat(sprintf("  %-22s %7.3f s  (%5.1f%%)\n",
              nm, timings[[nm]], 100 * timings[[nm]] / total))
}
cat(sprintf("  %-22s %7.3f s\n", "TOTAL (pre-run)", total))

cat("Right mouse drag = rotate, scroll = zoom. Close window to exit.\n")
cgv_run(v)
