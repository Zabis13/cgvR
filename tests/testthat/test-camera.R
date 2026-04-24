test_that("cgv_camera sets position", {
  v <- cgv_viewer(320, 240, "test-cam")
  expect_no_error(
    cgv_camera(v,
               position = c(0, 5, 10),
               target = c(0, 0, 0),
               up = c(0, 1, 0))
  )
  cgv_close(v)
})

test_that("cgv_camera uses defaults", {
  v <- cgv_viewer(320, 240, "test-cam-def")
  expect_no_error(cgv_camera(v))
  cgv_close(v)
})

test_that("cgv_fly_to warns without graph", {
  v <- cgv_viewer(320, 240, "test-fly")
  expect_warning(cgv_fly_to(v, node_id = 1L, duration = 0.5),
                 "no positions")
  cgv_close(v)
})

test_that("cgv_camera_mode switches modes", {
  v <- cgv_viewer(320, 240, "test-mode")
  expect_no_error(cgv_camera_mode(v, "fly"))
  expect_no_error(cgv_camera_mode(v, "orbit"))
  cgv_close(v)
})

test_that("cgv_fly_path accepts waypoints", {
  v <- cgv_viewer(320, 240, "test-path")
  pts <- matrix(c(0,0,0, 1,1,1, 2,0,0), ncol = 3, byrow = TRUE)
  expect_no_error(cgv_fly_path(v, pts, duration = 2.0, loop = FALSE))
  cgv_close(v)
})

test_that("cgv_fly_path rejects bad input", {
  v <- cgv_viewer(320, 240, "test-path-bad")
  expect_error(cgv_fly_path(v, matrix(1:4, ncol = 2)))
  expect_warning(cgv_fly_path(v, matrix(c(1,2,3), ncol = 3)))
  cgv_close(v)
})
