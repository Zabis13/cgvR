#!/usr/bin/env Rscript
# cgvR demo — запись графа в видеофайл (offscreen, без окна)
#
# Использование:
#   Rscript inst/examples/demo_record.R          # сохранит /tmp/cgvr_demo.mp4
#   Rscript inst/examples/demo_record.R out.mp4  # свой путь
#
# Требуется ffmpeg: sudo apt install ffmpeg
library(cgvR)

out <- commandArgs(trailingOnly = TRUE)
out <- if (length(out) > 0) out[1] else file.path(tempdir(), "cgvr_demo.mp4")

set.seed(7)
n <- 40L
from <- integer(0); to <- integer(0)
for (i in 2:n) {
  j <- sample.int(i - 1L, 1L)
  from <- c(from, j); to <- c(to, i)
}
edges <- cbind(from, to)
pos   <- cgv_layout_fr(n, edges, n_iter = 300L, seed = 7L)

fps      <- 30L
duration <- 4L   # секунды
n_frames <- fps * duration

v <- cgv_viewer(800L, 600L, "cgvR record demo", offscreen = TRUE)
cgv_set_graph(v, 1:n, edges, positions = pos)

# Анимация облёта по 4 точкам
waypoints <- rbind(
  c( 0,  0, 30),
  c(20,  0, 20),
  c( 0, 20, 20),
  c(-20,  0, 20)
)
cgv_fly_path(v, waypoints, duration = duration, loop = TRUE)

cgv_record_start(v, out, fps = fps)
cgv_run(v, n_frames = n_frames)
res <- cgv_record_stop(v)
cgv_close(v)

cat(sprintf("Записано %d кадров @ %d fps → %s\n", res[1], res[2], out))
