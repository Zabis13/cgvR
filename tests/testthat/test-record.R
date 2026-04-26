# Tests for cgv_record_start / cgv_record_stop.
# Smoke tests use offscreen rendering + ffmpeg pipe.

skip_if_no_ffmpeg <- function() {
  if (Sys.which("ffmpeg") == "") skip("ffmpeg not available")
}

test_that("cgv_record_start fails when ffmpeg is missing", {
  v <- cgv_viewer(160, 120, "test-rec-noffmpeg", offscreen = TRUE)
  cgv_set_graph(v, nodes = 1:3,
                edges = matrix(c(1L, 2L, 2L, 3L), ncol = 2))
  on.exit(cgv_close(v), add = TRUE)

  old <- Sys.getenv("PATH")
  on.exit(Sys.setenv(PATH = old), add = TRUE)
  Sys.setenv(PATH = "")
  expect_error(
    cgv_record_start(v, file.path(tempdir(), "x.mp4")),
    "ffmpeg not found"
  )
})

test_that("cgv_record_start validates fps and duration types", {
  v <- cgv_viewer(160, 120, "test-rec-validate", offscreen = TRUE)
  cgv_set_graph(v, nodes = 1:3,
                edges = matrix(c(1L, 2L, 2L, 3L), ncol = 2))
  on.exit(cgv_close(v), add = TRUE)
  skip_if_no_ffmpeg()

  out <- file.path(tempdir(), "x.mp4")
  expect_error(cgv_record_start(v, out, fps = 0L), "fps must be a positive")
  expect_error(cgv_record_start(v, out, fps = -5L), "fps must be a positive")
  expect_error(cgv_record_start(v, out, fps = c(1L, 2L)), "positive integer")
  expect_error(cgv_record_start(v, out, duration = c(1, 2)), "length 1")
})

test_that("cgv_record_start fails with invalid viewer", {
  expect_error(cgv_record_start(NULL, file.path(tempdir(), "x.mp4")),
               class = "error")
  expect_error(cgv_record_start(42L,  file.path(tempdir(), "x.mp4")),
               class = "error")
})

test_that("cgv_record_start refuses double start", {
  skip_if_no_ffmpeg()
  v <- cgv_viewer(160, 120, "test-rec-double", offscreen = TRUE)
  cgv_set_graph(v, nodes = 1:3,
                edges = matrix(c(1L, 2L, 2L, 3L), ncol = 2))
  on.exit({ try(cgv_record_stop(v), silent = TRUE); cgv_close(v) }, add = TRUE)

  out <- file.path(tempdir(), paste0("rec-double-", Sys.getpid(), ".mp4"))
  cgv_record_start(v, out, fps = 30L)
  expect_error(cgv_record_start(v, out, fps = 30L),
               "recording already in progress")
})

test_that("cgv_record_stop on inactive viewer returns 0 frames", {
  v <- cgv_viewer(160, 120, "test-rec-stop-inactive", offscreen = TRUE)
  on.exit(cgv_close(v), add = TRUE)
  res <- cgv_record_stop(v)
  expect_equal(res, c(0L, 0L))
})

test_that("offscreen recording produces a valid video file", {
  skip_if_no_ffmpeg()
  if (Sys.which("ffprobe") == "") skip("ffprobe not available")

  W <- 160L; H <- 120L; fps <- 30L; n_frames <- 60L
  v <- cgv_viewer(W, H, "test-rec-smoke", offscreen = TRUE)
  cgv_set_graph(v, nodes = 1:5,
                edges = matrix(c(1L, 2L, 3L, 4L,
                                 2L, 3L, 4L, 5L), ncol = 2))

  out <- file.path(tempdir(), paste0("rec-smoke-", Sys.getpid(), ".mp4"))
  if (file.exists(out)) file.remove(out)

  cgv_record_start(v, out, fps = fps)
  cgv_run(v, n_frames = n_frames)
  res <- cgv_record_stop(v)
  cgv_close(v)

  expect_gt(res[1], 0L)        # some frames captured
  expect_equal(res[2], fps)
  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0)

  # Validate via ffprobe — must report a video stream of right size.
  probe <- suppressWarnings(system2(
    "ffprobe",
    c("-v", "error", "-select_streams", "v:0",
      "-show_entries", "stream=width,height,codec_type",
      "-of", "default=nw=1", out),
    stdout = TRUE, stderr = TRUE
  ))
  expect_true(any(grepl("codec_type=video", probe)))
  expect_true(any(grepl(paste0("width=", W), probe)))
  expect_true(any(grepl(paste0("height=", H), probe)))
})

test_that("recording with duration cap stops on its own", {
  skip_if_no_ffmpeg()
  W <- 160L; H <- 120L; fps <- 30L
  v <- cgv_viewer(W, H, "test-rec-duration", offscreen = TRUE)
  cgv_set_graph(v, nodes = 1:3,
                edges = matrix(c(1L, 2L, 2L, 3L), ncol = 2))

  out <- file.path(tempdir(), paste0("rec-dur-", Sys.getpid(), ".mp4"))
  if (file.exists(out)) file.remove(out)

  cgv_record_start(v, out, fps = fps, duration = 0.2)
  cgv_run(v, n_frames = 200L)
  res <- cgv_record_stop(v)   # idempotent: already-closed → 0 frames
  cgv_close(v)

  expect_true(file.exists(out))
  expect_gt(file.info(out)$size, 0)
})
