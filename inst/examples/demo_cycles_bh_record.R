#!/usr/bin/env Rscript
# cgvR demo — TopSpin(8,4) cycles, Barnes-Hut FR, запись в видео.
# Крутите граф мышью. При закрытии окна видеофайл сохранится.
#
# Использование:
#   Rscript inst/examples/demo_cycles_bh_record.R              # → /tmp/cgvr_cycles.mp4
#   Rscript inst/examples/demo_cycles_bh_record.R out.mp4
library(cayleyR)
library(cgvR)

out <- commandArgs(trailingOnly = TRUE)
out <- if (length(out) > 0) out[1] else "/tmp/cgvr_cycles.mp4"

n <- 10L; k <- 4L

timings <- list()
stage <- function(name, expr) {
  t0 <- Sys.time()
  val <- force(expr)
  dt <- as.numeric(Sys.time() - t0, units = "secs")
  timings[[name]] <<- dt
  cat(sprintf("[%-22s] %7.3f s\n", name, dt))
  val
}

all_cycles <- stage("generate cycles", {
  set.seed(42)
  out_list <- list()
  for (trial in seq_len(500)) {
    nops <- sample(4:12, 1)
    ops <- sample(1:3, nops, replace = TRUE)
    res <- get_reachable_states(seq_len(n), as.character(ops), k = k,
                                verbose = FALSE)
    if (res$unique_states_count >= 50) {
      out_list[[length(out_list) + 1]] <- list(ops = ops,
                                               len = res$unique_states_count,
                                               df  = res$reachable_states_df)
    }
  }
  out_list[order(-sapply(out_list, "[[", "len"))]
})

best <- all_cycles[[1]]
cat(sprintf("Found %d cycles >= 50, longest: ops=[%s], len=%d\n",
            length(all_cycles), paste(best$ops, collapse = ","), best$len))

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
  n_nodes   <- length(uniq_keys)

  ef <- integer(0); et <- integer(0)
  for (ci in seq_along(all_dfs)) {
    ids <- match(all_dfs[[ci]]$keys, uniq_keys)
    ef <- c(ef, ids[-length(ids)], ids[length(ids)])
    et <- c(et, ids[-1],           ids[1])
  }
  ekeys <- ifelse(ef < et, paste(ef, et), paste(et, ef))
  keep <- !duplicated(ekeys)
  list(n_nodes = n_nodes,
       edges   = cbind(ef[keep], et[keep]),
       all_dfs = all_dfs,
       uniq_keys = uniq_keys)
})

cat(sprintf("Graph: %d nodes, %d edges\n", graph$n_nodes, nrow(graph$edges)))

pos <- stage("cgv_layout_fr_bh",
             cgv_layout_fr_bh(graph$n_nodes, graph$edges,
                              n_iter = 200L, theta = 1.0,
                              cool = 0.98, min_dist = 0.01, seed = 1L))

v <- stage("cgv_viewer",
           cgv_viewer(1280, 720,
                      sprintf("TopSpin(%d,%d) cycles — Barnes-Hut FR", n, k)))
stage("cgv_background", cgv_background(v, "black"))

stage("cgv_set_graph",
      cgv_set_graph(v, seq_len(graph$n_nodes), graph$edges,
                    positions   = pos,
                    node_values = as.double(seq_len(graph$n_nodes)),
                    node_sizes  = rep(6.0, graph$n_nodes)))

best_ids  <- match(graph$all_dfs[[1]]$keys, graph$uniq_keys)
best_path <- c(best_ids, best_ids[1])
stage("cgv_highlight_path",
      cgv_highlight_path(v, best_path, color = "#FF2200",
                         node_scale = 1.5, edge_width = 2.0))

cm       <- colMeans(pos)
max_dist <- max(sqrt(rowSums(sweep(pos, 2, cm)^2)))
d        <- max_dist * 2
stage("cgv_camera",
      cgv_camera(v, position = cm + c(d * 0.7, d * 0.6, d * 0.8),
                 target = cm))

# Запись включается до cgv_run — в windowed режиме frame callback активен
cgv_record_start(v, out, fps = 30L)
cat(sprintf("Запись в: %s\n", out))
cat("Right mouse drag = rotate, scroll = zoom. Close window to exit.\n")

cgv_run(v)

res <- cgv_record_stop(v)
cgv_close(v)
cat(sprintf("Записано %d кадров @ %d fps → %s\n", res[1], res[2], out))
