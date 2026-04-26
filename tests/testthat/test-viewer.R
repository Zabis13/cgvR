test_that("cgv_viewer creates and closes viewer", {
  v <- cgv_viewer(640, 480, "test", offscreen = TRUE)
  expect_true(inherits(v, "externalptr"))

  # close
  expect_no_error(cgv_close(v))
})

test_that("cgv_close on NULL pointer does not crash", {
  v <- cgv_viewer(320, 240, "test2", offscreen = TRUE)
  cgv_close(v)
  # second close should be safe (pointer already cleared)
  expect_no_error(cgv_close(v))
})

test_that("cgv_set_visibility works", {
  v <- cgv_viewer(320, 240, "test-vis", offscreen = TRUE)
  expect_no_error(cgv_set_visibility(v, 5L))
  expect_no_error(cgv_set_visibility(v, 20L))
  cgv_close(v)
})

test_that("cgv_run renders a fixed number of frames and returns", {
  # Smoke test: with n_frames > 0, dvz_scene_run must return after rendering
  # exactly that many frames instead of blocking on the event loop.
  v <- cgv_viewer(320, 240, "test-run-frames", offscreen = TRUE)
  cgv_set_graph(v, nodes = 1:3,
                edges = matrix(c(1L, 2L, 2L, 3L), ncol = 2))
  expect_no_error(cgv_run(v, n_frames = 3L))
  cgv_close(v)
})
